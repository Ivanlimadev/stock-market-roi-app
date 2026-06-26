import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A push notification received by this device, persisted locally so the user
/// can review past notifications in an in-app inbox.
class InboxNotification {
  final String id; // FCM messageId (dedupe key) or a timestamp fallback
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  bool read;

  InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.receivedAt,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'data': data,
        'receivedAt': receivedAt.toIso8601String(),
        'read': read,
      };

  factory InboxNotification.fromJson(Map<String, dynamic> j) => InboxNotification(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        receivedAt:
            DateTime.tryParse(j['receivedAt'] as String? ?? '') ?? DateTime.now(),
        read: j['read'] as bool? ?? false,
      );
}

/// Local-only store for received notifications (no backend). Backed by a JSON
/// file in the app documents directory. Exposes a [ValueNotifier] so the app
/// bar badge and inbox page update live for foreground notifications.
class NotificationInbox {
  NotificationInbox._();

  static const _maxItems = 100;
  static const _fileName = 'notification_inbox.json';

  /// In-memory mirror of the stored list (newest first). Listened to by the UI.
  static final ValueNotifier<List<InboxNotification>> items =
      ValueNotifier<List<InboxNotification>>([]);

  static int get unreadCount => items.value.where((n) => !n.read).length;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<InboxNotification>> _read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final list = jsonDecode(await f.readAsString()) as List;
      return list
          .map((e) => InboxNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(List<InboxNotification> list) async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {/* best-effort local cache */}
  }

  /// Loads from disk into [items]. Call at startup and on resume.
  static Future<void> load() async {
    items.value = await _read();
  }

  /// Adds a received notification (deduped by [id]). [read] is true when the
  /// notification was opened by tapping it.
  static Future<void> add({
    required String? id,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
    bool read = false,
  }) async {
    final list = await _read();
    final key = (id != null && id.isNotEmpty)
        ? id
        : DateTime.now().microsecondsSinceEpoch.toString();
    if (list.any((n) => n.id == key)) return; // dedupe

    list.insert(
      0,
      InboxNotification(
        id: key,
        title: title,
        body: body,
        data: data,
        receivedAt: DateTime.now(),
        read: read,
      ),
    );
    if (list.length > _maxItems) list.removeRange(_maxItems, list.length);
    await _write(list);
    items.value = List.of(list);
  }

  /// Marks every notification as read.
  static Future<void> markAllRead() async {
    final list = await _read();
    var changed = false;
    for (final n in list) {
      if (!n.read) {
        n.read = true;
        changed = true;
      }
    }
    if (changed) await _write(list);
    items.value = List.of(list);
  }

  /// Clears the inbox.
  static Future<void> clear() async {
    await _write([]);
    items.value = [];
  }
}
