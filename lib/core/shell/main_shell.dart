import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/theme_provider.dart';
import '../providers/profile_provider.dart';
import '../services/notification_inbox.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';

/// Bumped to ask the Home (Markets) screen to enter asset-search mode. Lets the
/// shared search button work from any tab (it routes to Home, then activates).
final searchTriggerProvider = StateProvider<int>((ref) => 0);

/// AppBar action buttons shared across pages so the top bar is identical on
/// every screen: search · theme · settings · avatar.
class MainShellMenu {
  /// The standard fixed top-bar actions used on every screen:
  /// search · theme · settings · avatar. Add `...MainShellMenu.actions()`
  /// (or `actions: MainShellMenu.actions()`) to any AppBar.
  static List<Widget> actions() => [
        searchButton(),
        themeButton(),
        settingsButton(),
        avatarButton(),
      ];

  /// Asset search (magnifying glass). Routes to Markets and activates search.
  static Widget searchButton() => Consumer(
        builder: (context, ref, _) => IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search assets',
          onPressed: () {
            ref.read(searchTriggerProvider.notifier).state++;
            context.go('/home');
          },
        ),
      );

  /// Theme toggle (dark ⇄ light) for the AppBar.
  static Widget themeButton() => Consumer(
        builder: (context, ref, _) {
          final isDark = ref.watch(themeProvider) == ThemeMode.dark;
          return IconButton(
            icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: isDark ? 'Tema claro' : 'Tema escuro',
            onPressed: () => ref.read(themeProvider.notifier).state =
                isDark ? ThemeMode.light : ThemeMode.dark,
          );
        },
      );

  /// Received-notifications inbox. Shows a green dot badge and turns green when
  /// there are unread notifications.
  static Widget inboxButton() =>
      ValueListenableBuilder<List<InboxNotification>>(
        valueListenable: NotificationInbox.items,
        builder: (context, items, _) {
          final unread = items.where((n) => !n.read).length;
          final hasUnread = unread > 0;
          return IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: hasUnread,
              backgroundColor: AppColors.emerald,
              label: unread > 9
                  ? const Text('9+')
                  : (unread > 1 ? Text('$unread') : null),
              smallSize: 8,
              child: Icon(
                hasUnread
                    ? Icons.mark_email_unread_rounded
                    : Icons.mail_outline_rounded,
                color: hasUnread ? AppColors.emerald : null,
              ),
            ),
          );
        },
      );

  /// Settings (account, notifications, support, etc.).
  static Widget settingsButton() => Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.settings_rounded),
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
        ),
      );

  /// User avatar (top-right, investidor10-style). Shows the profile photo when
  /// available, a person icon otherwise. Taps through to the profile (or login).
  static Widget avatarButton() => Consumer(
        builder: (context, ref, _) {
          final c = context.colors;
          final file = ref.watch(localAvatarProvider).valueOrNull;
          final loggedIn = Supabase.instance.client.auth.currentUser != null;
          final hasPhoto = file != null;
          return Padding(
            padding: const EdgeInsets.only(right: 12, left: 2),
            child: GestureDetector(
              onTap: () => context.push(loggedIn ? '/perfil' : '/login'),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: c.surfaceAlt,
                backgroundImage: hasPhoto ? FileImage(file) : null,
                child: hasPhoto
                    ? null
                    : Icon(Icons.person_rounded, size: 18, color: c.textMuted),
              ),
            ),
          );
        },
      );
}

/// Wraps the shell tabs with the shared bottom navigation.
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
