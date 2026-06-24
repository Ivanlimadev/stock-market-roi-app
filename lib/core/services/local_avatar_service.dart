import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores the user's profile photo **locally on the device only** (app
/// documents dir), keyed by user id. Avoids Supabase Storage entirely.
///
/// Trade-off (intentional): the photo does not sync across devices and is
/// re-added after logout / reinstall. Fine for an avatar.
class LocalAvatarService {
  LocalAvatarService._();

  static Future<File> _fileFor(String uid) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/avatar_$uid.jpg');
  }

  /// Returns the saved avatar file for the signed-in user, or null if none.
  static Future<File?> currentFile() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return null;
    final f = await _fileFor(uid);
    return await f.exists() ? f : null;
  }

  /// Picks an image from the gallery and saves it locally. Returns false if
  /// the user cancelled.
  static Future<bool> pickAndSave() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return false;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return false;

    final bytes = await picked.readAsBytes();
    final f = await _fileFor(uid);
    await f.writeAsBytes(bytes, flush: true);
    // Drop any cached render of the old photo at this path.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    return true;
  }

  /// Deletes the locally stored avatar for the signed-in user.
  static Future<void> remove() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final f = await _fileFor(uid);
    if (await f.exists()) await f.delete();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
