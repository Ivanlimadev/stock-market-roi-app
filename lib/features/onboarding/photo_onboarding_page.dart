import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/profile_provider.dart';

/// Shown once, right after the user's first sign-in, inviting them to add a
/// profile photo (uploaded to Supabase Storage). Both "Choose photo" and
/// "Skip" mark the prompt as seen (`photo_onboarded`) so it never shows again.
class PhotoOnboardingPage extends ConsumerStatefulWidget {
  const PhotoOnboardingPage({super.key});

  @override
  ConsumerState<PhotoOnboardingPage> createState() =>
      _PhotoOnboardingPageState();
}

class _PhotoOnboardingPageState extends ConsumerState<PhotoOnboardingPage> {
  bool _busy = false;

  Future<void> _markSeen() async {
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(data: {'photo_onboarded': true}));
    } catch (_) {
      // Non-blocking — worst case the prompt shows once more next login.
    }
  }

  Future<void> _choosePhoto() async {
    setState(() => _busy = true);
    try {
      final ok = await ProfileService.pickAndUploadAvatar();
      if (ok) ref.invalidate(profileProvider);
      // If the user cancelled the picker we keep them here to try again/skip.
      if (!ok) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await _markSeen();
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not set photo.')));
      }
    }
  }

  Future<void> _skip() async {
    setState(() => _busy = true);
    await _markSeen();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar placeholder with camera badge
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(52),
                      ),
                      child: Icon(Icons.person_rounded,
                          size: 52, color: AppColors.emerald),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.emerald,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.background, width: 3),
                        ),
                        child: const Icon(Icons.photo_camera_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Add a profile photo',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'Personalize your account. You can always change or remove it '
                'later in My Account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.textSecond, height: 1.5),
              ),
              const SizedBox(height: 36),

              FilledButton.icon(
                onPressed: _busy ? null : _choosePhoto,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_a_photo_rounded, size: 18),
                label: const Text('Choose photo'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _skip,
                child: Text('Skip for now',
                    style: TextStyle(
                        fontSize: 14,
                        color: c.textMuted,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
