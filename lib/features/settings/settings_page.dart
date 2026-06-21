import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/theme_provider.dart';

/// Account hub: everything related to the user account, notifications,
/// support and the destructive sign-out / delete-account actions.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _loading = false;

  Future<void> _signOut() async {
    setState(() => _loading = true);
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      setState(() => _loading = false);
      context.go('/home');
    }
  }

  Future<void> _showDeleteConfirm() async {
    final ctrl = TextEditingController();
    final c = context.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: c.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete Account',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete your account, watchlist, portfolio and all data. This action cannot be undone.',
                style: TextStyle(fontSize: 13, color: c.textSecond, height: 1.4),
              ),
              const SizedBox(height: 16),
              Text('Type APAGAR to confirm',
                  style: TextStyle(fontSize: 12, color: c.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                onChanged: (_) => setS(() {}),
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'APAGAR',
                  hintStyle: TextStyle(color: c.textMuted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.red),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: c.textMuted)),
            ),
            FilledButton(
              onPressed:
                  ctrl.text == 'APAGAR' ? () => Navigator.of(ctx).pop(true) : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.red.withValues(alpha: 0.3),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.rpc('delete_user');
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to delete account. Please try again.')),
        );
      }
    }
  }

  Future<void> _support() => launchUrl(
        Uri.parse('mailto:contato@stockmarketroi.com'),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          // Theme toggle stays reachable from Settings too.
          Consumer(builder: (context, ref, _) {
            final isDark = ref.watch(themeProvider) == ThemeMode.dark;
            return IconButton(
              icon: Icon(isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded),
              tooltip: isDark ? 'Light theme' : 'Dark theme',
              onPressed: () => ref.read(themeProvider.notifier).state =
                  isDark ? ThemeMode.light : ThemeMode.dark,
            );
          }),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _UserStrip(user: user),
            Divider(color: context.colors.surfaceAlt, height: 1),

            if (user != null) ...[
              const _Section('Account'),
              _Item(
                icon: Icons.person_rounded,
                label: 'My Account',
                onTap: () => context.push('/perfil'),
              ),
              _Item(
                icon: Icons.notifications_rounded,
                label: 'Notifications',
                badge: 'Coming soon',
                onTap: () {},
              ),
            ],

            const SizedBox(height: 8),
            const _Section('Help'),
            _Item(
              icon: Icons.support_agent_rounded,
              label: 'Support',
              onTap: _support,
            ),

            if (user != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _signOut,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.red))
                      : const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _showDeleteConfirm,
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textMuted,
                      decoration: TextDecoration.underline),
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: FilledButton(
                  onPressed: () => context.push('/register'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create free account',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── User strip ──────────────────────────────────────────────────────────────

class _UserStrip extends StatelessWidget {
  final User? user;
  const _UserStrip({required this.user});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.person_outline_rounded,
                size: 22, color: c.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guest',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => context.push('/login'),
                  child: Text('Sign in or create account',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.emerald,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ]),
      );
    }

    final email = user!.email ?? '';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.emerald.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Text(initials,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.emerald)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Account',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textMuted)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.colors.textMuted,
                letterSpacing: 0.8)),
      );
}

// ── Nav item ──────────────────────────────────────────────────────────────────

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
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
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary)),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badge!,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted)),
            )
          else
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
        ]),
      ),
    );
  }
}
