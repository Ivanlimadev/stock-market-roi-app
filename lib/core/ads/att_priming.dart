import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pre-prompt shown right before the iOS App Tracking Transparency dialog.
///
/// Apple allows a custom explainer as long as it leads into the system prompt
/// and does not mimic it. A short value message here typically lifts the ATT
/// opt-in rate well above the ~25% of showing the bare system dialog — and
/// personalized ads earn materially more, so this single screen lifts revenue
/// across every ad format.
///
/// Resolves once the user dismisses it; the caller then triggers the real
/// system ATT request.
Future<void> showAttPriming(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _AttPrimingDialog(),
  );
}

class _AttPrimingDialog extends StatelessWidget {
  const _AttPrimingDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.favorite_rounded,
                    color: AppColors.emerald, size: 28),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Keep Stock Market ROI free',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We keep the app 100% free with ads. Allowing tracking lets us '
              'show more relevant ads, which helps us earn more and keep '
              'building new features for you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: c.textMuted),
            ),
            const SizedBox(height: 16),
            _Bullet(text: 'Your data is never sold to anyone'),
            const SizedBox(height: 8),
            _Bullet(text: 'You can change this anytime in Settings'),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Text(
              "On the next screen, tap “Allow”.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: AppColors.emerald),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12.5, color: c.textSecond)),
        ),
      ],
    );
  }
}
