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

  /// Brokerage-style leading: the company logo when the notification carries a
  /// stock symbol, otherwise a type icon.
  Widget _leadingFor(String? type, Map<String, dynamic> data) {
    final c = context.colors;
    final symbol = (data['symbol'] as String?)?.toUpperCase();
    if (symbol != null && symbol.isNotEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: c.surfaceAlt, borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          'https://assets.parqet.com/logos/symbol/$symbol?format=png',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Center(
            child: Text(symbol.length >= 2 ? symbol.substring(0, 2) : symbol,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: c.textMuted)),
          ),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
      child: Icon(_iconFor(type), color: AppColors.emerald, size: 20),
    );
  }

  /// Dividend amount chip (per share), shown for dividend notifications that
  /// carry an `amount` in their data payload.
  Widget? _amountChip(Map<String, dynamic> data) {
    if (data['type'] != 'dividend_alert') return null;
    final amount = double.tryParse('${data['amount'] ?? ''}');
    if (amount == null || amount <= 0) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.emerald.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.emerald)),
    );
  }

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
                leading: _leadingFor(type, n.data),
                trailing: _amountChip(n.data),
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
