import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/notification_inbox.dart';
import '../../core/services/notification_service.dart';

/// In-app inbox listing push notifications received on this device (local only).
class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({super.key});

  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage> {
  @override
  void initState() {
    super.initState();
    // Opening the inbox clears the "new" badge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationInbox.markAllRead();
    });
  }

  IconData _iconFor(String? type) => switch (type) {
        'price_alert' => Icons.trending_up_rounded,
        'dividend_alert' => Icons.payments_rounded,
        'blog_post' => Icons.article_rounded,
        'monthly_report' => Icons.assessment_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          ValueListenableBuilder<List<InboxNotification>>(
            valueListenable: NotificationInbox.items,
            builder: (_, items, __) => items.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Clear all',
                    onPressed: NotificationInbox.clear,
                  ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<InboxNotification>>(
        valueListenable: NotificationInbox.items,
        builder: (_, items, __) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 48, color: c.textMuted),
                  const SizedBox(height: 12),
                  Text('No notifications yet',
                      style: TextStyle(color: c.textMuted)),
                  const SizedBox(height: 4),
                  Text('Price alerts, dividends and new posts show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: c.textMuted)),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: c.surfaceAlt, indent: 16, endIndent: 16),
            itemBuilder: (_, i) {
              final n = items[i];
              final type = n.data['type'] as String?;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
                  child: Icon(_iconFor(type), color: AppColors.emerald, size: 20),
                ),
                title: Text(n.title.isEmpty ? 'Notification' : n.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: c.textPrimary)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (n.body.isNotEmpty)
                      Text(n.body, style: TextStyle(color: c.textSecond)),
                    const SizedBox(height: 2),
                    Text(DateFormat('MMM d, HH:mm').format(n.receivedAt),
                        style: TextStyle(fontSize: 11, color: c.textMuted)),
                  ],
                ),
                isThreeLine: n.body.isNotEmpty,
                onTap: () => NotificationService.navigateFromData(n.data),
              );
            },
          );
        },
      ),
    );
  }
}
