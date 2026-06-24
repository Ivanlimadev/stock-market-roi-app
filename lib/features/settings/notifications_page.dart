import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/notification_prefs_provider.dart';
import '../../core/widgets/app_bottom_nav.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final async = ref.watch(notificationPrefsProvider);

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: user == null
            ? _SignedOut()
            : async.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.emerald)),
                error: (e, _) => _LoadError(
                    onRetry: () => ref.invalidate(notificationPrefsProvider)),
                data: (prefs) => _Prefs(prefs: prefs),
              ),
      ),
    );
  }
}

class _Prefs extends ConsumerWidget {
  final NotificationPrefs prefs;
  const _Prefs({required this.prefs});

  Future<void> _set(WidgetRef ref, String column, bool value) async {
    await updateNotificationPref(column, value);
    ref.invalidate(notificationPrefsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            'Choose which push notifications you want to receive.',
            style: TextStyle(fontSize: 13, color: context.colors.textSecond),
          ),
        ),
        _Toggle(
          icon: Icons.notifications_active_rounded,
          title: 'Price Alerts',
          subtitle: 'When a stock or crypto hits your target price',
          value: prefs.priceAlerts,
          onChanged: (v) => _set(ref, 'price_alerts', v),
        ),
        _Toggle(
          icon: Icons.savings_rounded,
          title: 'Dividend Alerts',
          subtitle: 'Upcoming ex-dividend dates for your holdings',
          value: prefs.dividendAlerts,
          onChanged: (v) => _set(ref, 'dividend_alerts', v),
        ),
        _Toggle(
          icon: Icons.article_rounded,
          title: 'Blog Posts',
          subtitle: 'New market analysis published on the blog',
          value: prefs.blogPosts,
          onChanged: (v) => _set(ref, 'blog_posts', v),
        ),
        _Toggle(
          icon: Icons.calendar_month_rounded,
          title: 'Monthly Report',
          subtitle: 'Your portfolio dividend summary each month',
          value: prefs.monthlyReport,
          onChanged: (v) => _set(ref, 'monthly_report', v),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'Notifications are delivered on Android now; iOS delivery activates once the Apple Developer account is live.',
            style: TextStyle(fontSize: 11, color: context.colors.textMuted, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: c.textSecond),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: c.textMuted, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.emerald,
          ),
        ],
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Text('Sign in to manage notifications',
            style: TextStyle(color: context.colors.textMuted)),
      );
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text('Could not load preferences',
                style: TextStyle(color: context.colors.textMuted)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emerald,
                side: const BorderSide(color: AppColors.emerald),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
}
