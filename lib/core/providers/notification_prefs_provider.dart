import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationPrefs {
  final bool priceAlerts;
  final bool dividendAlerts;
  final bool blogPosts;
  final bool monthlyReport;

  const NotificationPrefs({
    this.priceAlerts = true,
    this.dividendAlerts = true,
    this.blogPosts = true,
    this.monthlyReport = true,
  });

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
        priceAlerts: j['price_alerts'] as bool? ?? true,
        dividendAlerts: j['dividend_alerts'] as bool? ?? true,
        blogPosts: j['blog_posts'] as bool? ?? true,
        monthlyReport: j['monthly_report'] as bool? ?? true,
      );
}

/// Loads the signed-in user's notification preferences (defaults all on).
final notificationPrefsProvider =
    FutureProvider.autoDispose<NotificationPrefs>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const NotificationPrefs();

  final row = await client
      .from('notification_preferences')
      .select()
      .eq('user_id', user.id)
      .maybeSingle();

  if (row == null) {
    await client
        .from('notification_preferences')
        .upsert({'user_id': user.id});
    return const NotificationPrefs();
  }
  return NotificationPrefs.fromJson(row);
});

/// Persists a single preference flag.
Future<void> updateNotificationPref(String column, bool value) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return;
  await client.from('notification_preferences').upsert({
    'user_id': uid,
    column: value,
    'updated_at': DateTime.now().toIso8601String(),
  });
}
