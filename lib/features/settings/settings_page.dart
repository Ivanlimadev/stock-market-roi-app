import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/ads/ad_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/local_avatar_service.dart';
import '../../core/widgets/app_bottom_nav.dart';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

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
                'This permanently deletes your account and all data — watchlist, portfolio, alerts and profile — across the app and the website. This action cannot be undone.',
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
      // Local-only avatar — drop it from the device before wiping the account.
      await LocalAvatarService.remove();
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

  Future<void> _support() async {
    final user = Supabase.instance.client.auth.currentUser;
    // Encode manually so spaces become %20 (some mail clients choke on '+').
    String enc(Map<String, String> p) => p.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final uri = Uri.parse(
      'mailto:contato@stockmarketroi.com?${enc({
            'subject': 'Stock Market ROI — Support',
            'body': 'Describe your issue here.\n\n'
                '——\nAccount: ${user?.email ?? 'guest'}\n'
                'User ID: ${user?.id ?? '—'}\n'
                'App: Stock Market ROI',
          })}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _pickTheme() {
    final current = ref.read(themeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final m in ThemeMode.values)
            ListTile(
              title: Text(_themeLabel(m)),
              trailing: m == current
                  ? const Icon(Icons.check_rounded, color: AppColors.emerald)
                  : null,
              onTap: () {
                ref.read(themeProvider.notifier).state = m;
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
    );
  }

  static String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
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
            const _UserStrip(),
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
                onTap: () => context.push('/settings/notifications'),
              ),
            ],

            const SizedBox(height: 8),
            const _Section('Appearance'),
            Consumer(builder: (context, ref, _) {
              final mode = ref.watch(themeProvider);
              return _Item(
                icon: Icons.palette_rounded,
                label: 'Theme',
                trailing: _themeLabel(mode),
                onTap: _pickTheme,
              );
            }),

            const SizedBox(height: 8),
            const _Section('Help'),
            _Item(
              icon: Icons.support_agent_rounded,
              label: 'Support',
              onTap: _support,
            ),

            const SizedBox(height: 8),
            const _Section('Legal'),
            _Item(
              icon: Icons.privacy_tip_rounded,
              label: 'Privacy Policy',
              onTap: () => context.push('/privacy'),
            ),
            _Item(
              icon: Icons.description_rounded,
              label: 'Terms of Service',
              onTap: () => context.push('/terms'),
            ),
            // Ad privacy (GDPR) — only shown where consent is required.
            FutureBuilder<bool>(
              future: AdManager.instance.privacyOptionsRequired,
              builder: (context, snap) => snap.data == true
                  ? _Item(
                      icon: Icons.ad_units_rounded,
                      label: 'Ad Privacy Settings',
                      onTap: AdManager.instance.showPrivacyOptions,
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 8),
            const _Section('About'),
            _Item(
              icon: Icons.info_rounded,
              label: 'About Stock Market ROI',
              onTap: () => context.push('/about'),
            ),
            Consumer(builder: (context, ref, _) {
              final v = ref.watch(_appVersionProvider).valueOrNull;
              return _Item(
                icon: Icons.tag_rounded,
                label: 'Version',
                trailing: v ?? '—',
                chevron: false,
              );
            }),

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

class _UserStrip extends ConsumerStatefulWidget {
  const _UserStrip();

  @override
  ConsumerState<_UserStrip> createState() => _UserStripState();
}

class _UserStripState extends ConsumerState<_UserStrip> {
  bool _busy = false;

  Future<void> _changePhoto() async {
    setState(() => _busy = true);
    try {
      final ok = await LocalAvatarService.pickAndSave();
      if (ok) ref.invalidate(localAvatarProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not set photo.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _busy = true);
    try {
      await LocalAvatarService.remove();
      ref.invalidate(localAvatarProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editName(String? current) async {
    final ctrl = TextEditingController(text: current ?? '');
    final c = context.colors;
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Display name', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: c.textMuted),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.emerald)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: c.textMuted))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null) return;
    await ProfileService.updateDisplayName(name);
    ref.invalidate(profileProvider);
  }

  void _showActions(UserProfile? profile, {required bool hasPhoto}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Change photo'),
            onTap: () { Navigator.pop(ctx); _changePhoto(); },
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Remove photo'),
              onTap: () { Navigator.pop(ctx); _removePhoto(); },
            ),
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Edit display name'),
            onTap: () { Navigator.pop(ctx); _editName(profile?.displayName); },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = Supabase.instance.client.auth.currentUser;

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
            child: Icon(Icons.person_outline_rounded, size: 22, color: c.textMuted),
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

    final profile = ref.watch(profileProvider).valueOrNull;
    final avatarFile = ref.watch(localAvatarProvider).valueOrNull;
    final email = user.email ?? '';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    final name = (profile?.displayName?.isNotEmpty ?? false)
        ? profile!.displayName!
        : 'My Account';

    return InkWell(
      onTap: () => _showActions(profile, hasPhoto: avatarFile != null),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Stack(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(26),
                image: avatarFile != null
                    ? DecorationImage(
                        image: FileImage(avatarFile), fit: BoxFit.cover)
                    : null,
              ),
              child: avatarFile == null
                  ? Center(
                      child: Text(initials,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.emerald)))
                  : null,
            ),
            if (_busy)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(26)),
                  child: const Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.emerald,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.background, width: 2),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    size: 11, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
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
          Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
        ]),
      ),
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
  final VoidCallback? onTap;
  final String? trailing;
  final bool chevron;

  const _Item({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.chevron = true,
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
          if (trailing != null) ...[
            Text(trailing!,
                style: TextStyle(fontSize: 13, color: c.textMuted)),
            const SizedBox(width: 6),
          ],
          if (chevron)
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
        ]),
      ),
    );
  }
}
