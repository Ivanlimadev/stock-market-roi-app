import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String? displayName;
  final String? avatarUrl;

  const UserProfile({required this.id, this.displayName, this.avatarUrl});

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        displayName: j['display_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
      );
}

/// Loads the signed-in user's profile row (display name + avatar URL).
final profileProvider = FutureProvider.autoDispose<UserProfile?>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;

  final row = await client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  // Defensive: the signup trigger/backfill normally creates this row.
  if (row == null) {
    await client.from('profiles').upsert({'id': user.id});
    return UserProfile(id: user.id);
  }
  return UserProfile.fromJson(row);
});

/// Profile mutations (display name + avatar upload/remove). Call
/// `ref.invalidate(profileProvider)` after to refresh the UI.
class ProfileService {
  ProfileService._();
  static const _bucket = 'avatars';

  static SupabaseClient get _c => Supabase.instance.client;

  static Future<void> updateDisplayName(String? name) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    final trimmed = name?.trim();
    await _c.from('profiles').update({
      'display_name': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', uid);
  }

  /// Picks an image, uploads it to `avatars/{uid}/avatar.jpg` and stores the
  /// (cache-busted) public URL on the profile. Returns false if cancelled.
  static Future<bool> pickAndUploadAvatar() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return false;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return false;

    final bytes = await picked.readAsBytes();
    final path = '$uid/avatar.jpg';

    await _c.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );

    // Fixed path → bust the CDN/image cache so the new photo shows immediately.
    final url = _c.storage.from(_bucket).getPublicUrl(path);
    final busted = '$url?v=${DateTime.now().millisecondsSinceEpoch}';

    await _c.from('profiles').update({
      'avatar_url': busted,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', uid);
    return true;
  }

  /// Removes the avatar file and clears the profile URL.
  static Future<void> removeAvatar() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _c.storage.from(_bucket).remove(['$uid/avatar.jpg']);
    } catch (_) {
      // File may not exist — ignore.
    }
    await _c.from('profiles').update({
      'avatar_url': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', uid);
  }
}
