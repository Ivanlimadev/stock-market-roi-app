import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../router/app_router.dart';

// Must be top-level — runs in a separate isolate when app is terminated
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // FCM shows the notification automatically from the data payload.
  // No UI work here.
}

class NotificationService {
  NotificationService._();

  static final _fln = FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'smr_high_importance';
  static const _androidChannelName = 'Stock Market ROI';
  static const _androidChannelDesc =
      'Price alerts, dividend news, blog posts and monthly reports';

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    await _requestPermission();
    await _initLocalNotifications();
    await _createAndroidChannel();

    // Show local notification when app is in foreground
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // User tapped notification while app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTap);

    // User tapped notification that launched the app from terminated state
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _navigateFromData(initial.data);

    // Register FCM token whenever it changes (first run + token rotation)
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _saveToken());
    await _saveToken();
  }

  // Called after login — re-registers token for the now-authenticated user
  static Future<void> onLogin() => _saveToken();

  // Called on logout — removes this device's token from Supabase
  static Future<void> onLogout() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await Supabase.instance.client
        .from('user_fcm_tokens')
        .delete()
        .eq('token', token);
  }

  // ── Private ──────────────────────────────────────────────────────────────

  static Future<void> _requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    // iOS foreground notifications must be explicitly enabled
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _initLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _fln.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  static Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDesc,
      importance: Importance.high,
    );
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _fln.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    final data = jsonDecode(response.payload!) as Map<String, dynamic>;
    _navigateFromData(data);
  }

  static void _onMessageTap(RemoteMessage message) =>
      _navigateFromData(message.data);

  // Notification payload types sent by Supabase Edge Functions:
  //   price_alert   → data: { type, symbol }
  //   dividend_alert→ data: { type, symbol }
  //   blog_post     → data: { type, slug }
  //   monthly_report→ data: { type }
  static void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final symbol = (data['symbol'] as String?)?.toLowerCase();
    final slug = data['slug'] as String?;

    switch (type) {
      case 'price_alert':
      case 'dividend_alert':
        if (symbol != null) appRouter.push('/stocks/$symbol');
      case 'blog_post':
        if (slug != null) appRouter.push('/blog/$slug');
      case 'monthly_report':
        appRouter.push('/portfolio');
    }
  }

  static Future<void> _saveToken() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await Supabase.instance.client.from('user_fcm_tokens').upsert(
      {
        'user_id': user.id,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,token',
    );
  }
}
