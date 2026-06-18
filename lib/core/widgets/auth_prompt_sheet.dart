import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Shows a bottom sheet prompting guest users to sign up when they try
/// a protected action (add to portfolio, favorite an asset).
void showAuthPromptSheet(BuildContext context, {String? action}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AuthPromptSheet(action: action),
  );
}

class _AuthPromptSheet extends StatelessWidget {
  final String? action;
  const _AuthPromptSheet({this.action});

  @override
  Widget build(BuildContext context) {
    final label = action ?? 'salvar este ativo';

    return Container(
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(Icons.lock_open_rounded,
                size: 30, color: AppColors.emerald),
          ),
          SizedBox(height: 20),

          Text(
            'Crie sua conta gratuita',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'To $label you need an account.\nIt\'s quick and free!',
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textSecond,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/register');
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Create free account',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/login');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.textPrimary,
                side: BorderSide(color: context.colors.surfaceAlt),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'I already have an account — Log in',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Not now',
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
