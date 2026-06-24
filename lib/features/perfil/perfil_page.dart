import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/local_avatar_service.dart';
import '../../core/widgets/app_bottom_nav.dart';

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return user == null ? const _GuestPerfil() : _LoggedPerfil(user: user);
  }
}

// ─── Guest ────────────────────────────────────────────────────────────────────

class _GuestPerfil extends StatelessWidget {
  const _GuestPerfil();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: const Text('My Account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(Icons.person_outline_rounded,
                    size: 40, color: context.colors.textMuted),
              ),
              const SizedBox(height: 24),
              Text('Create your account',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary)),
              const SizedBox(height: 10),
              Text(
                'Save assets, build your portfolio and track your favorites.',
                style: TextStyle(
                    fontSize: 14, color: context.colors.textSecond, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push('/register'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create free account',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/login'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.textPrimary,
                    side: BorderSide(color: context.colors.surfaceAlt),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Sign In',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Logged-in ────────────────────────────────────────────────────────────────

class _LoggedPerfil extends ConsumerStatefulWidget {
  final User user;
  const _LoggedPerfil({required this.user});

  @override
  ConsumerState<_LoggedPerfil> createState() => _LoggedPerfilState();
}

class _LoggedPerfilState extends ConsumerState<_LoggedPerfil> {
  bool _loading = false; // sign out / delete account
  bool _busy = false;    // avatar upload / remove

  static final _dateFmt = DateFormat('MMM d, yyyy');

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      return _dateFmt.format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '—';
    }
  }

  Future<void> _signOut() async {
    setState(() => _loading = true);
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      setState(() => _loading = false);
      context.go('/home');
    }
  }

  // ── Photo ────────────────────────────────────────────────────────────────

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

  void _showPhotoActions({required bool hasPhoto}) {
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
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
              title: const Text('Remove photo',
                  style: TextStyle(color: AppColors.red)),
              onTap: () { Navigator.pop(ctx); _removePhoto(); },
            ),
        ]),
      ),
    );
  }

  // ── Display name ─────────────────────────────────────────────────────────

  Future<void> _editName(String? current) async {
    final ctrl = TextEditingController(text: current ?? '');
    final c = context.colors;
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Username', style: TextStyle(fontSize: 16)),
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
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null) return;
    await ProfileService.updateDisplayName(name);
    ref.invalidate(profileProvider);
  }

  // ── Password ─────────────────────────────────────────────────────────────

  Future<void> _changePassword() async {
    final c = context.colors;
    final pwd = TextEditingController();
    final confirm = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final valid = pwd.text.length >= 6 && pwd.text == confirm.text;
          InputDecoration dec(String hint) => InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: c.textMuted),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.emerald)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              );
          return AlertDialog(
            backgroundColor: c.background,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Change password', style: TextStyle(fontSize: 16)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: pwd,
                obscureText: true,
                onChanged: (_) => setS(() {}),
                style: TextStyle(color: c.textPrimary),
                decoration: dec('New password (min. 6)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirm,
                obscureText: true,
                onChanged: (_) => setS(() {}),
                style: TextStyle(color: c.textPrimary),
                decoration: dec('Confirm new password'),
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: c.textMuted))),
              FilledButton(
                onPressed: valid ? () => Navigator.pop(ctx, true) : null,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.emerald.withValues(alpha: 0.3)),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !mounted) return;
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: pwd.text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update password.')));
      }
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  Future<void> _showDeleteConfirm() async {
    final ctrl = TextEditingController();
    final c    = context.colors;

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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
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
              onPressed: ctrl.text == 'APAGAR'
                  ? () => Navigator.of(ctx).pop(true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.red.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
          const SnackBar(content: Text('Failed to delete account. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final user    = widget.user;
    final email   = user.email ?? '';
    final verified = user.emailConfirmedAt != null;
    final memberSince = _formatDate(user.createdAt);

    final profile    = ref.watch(profileProvider).valueOrNull;
    final avatarFile = ref.watch(localAvatarProvider).valueOrNull;
    final displayName = (profile?.displayName?.isNotEmpty ?? false)
        ? profile!.displayName!
        : null;
    final initials = (displayName?.isNotEmpty ?? false)
        ? displayName![0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : 'U');

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: const Text('My Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Avatar — tap to change/remove photo
              Center(
                child: GestureDetector(
                  onTap: () => _showPhotoActions(hasPhoto: avatarFile != null),
                  child: Stack(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(40),
                          image: avatarFile != null
                              ? DecorationImage(
                                  image: FileImage(avatarFile),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: avatarFile == null
                            ? Center(
                                child: Text(initials,
                                    style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.emerald)),
                              )
                            : null,
                      ),
                      if (_busy)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(40)),
                            child: const Center(
                                child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))),
                          ),
                        ),
                      // Camera badge → photo actions
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.emerald,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: c.background, width: 2),
                          ),
                          child: const Icon(Icons.photo_camera_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(displayName ?? email,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary)),
              ),
              if (displayName != null) ...[
                const SizedBox(height: 2),
                Center(
                  child: Text(email,
                      style: TextStyle(fontSize: 13, color: c.textMuted)),
                ),
              ],
              const SizedBox(height: 32),

              // Info cards
              _InfoCard(children: [
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Username',
                  value: displayName ?? 'Add a username',
                  onTap: () => _editName(profile?.displayName),
                  trailing: Icon(Icons.edit_rounded,
                      size: 16, color: c.textMuted),
                ),
                Divider(height: 1, color: c.surfaceAlt),
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (verified ? AppColors.emerald : AppColors.orange)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      verified ? 'Verified' : 'Unverified',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: verified ? AppColors.emerald : AppColors.orange,
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: c.surfaceAlt),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member since',
                  value: memberSince,
                ),
              ]),

              const SizedBox(height: 16),

              // Security
              _InfoCard(children: [
                _InfoRow(
                  icon: Icons.lock_outline_rounded,
                  label: 'Password',
                  value: 'Change your password',
                  onTap: _changePassword,
                  trailing: Icon(Icons.chevron_right_rounded,
                      size: 18, color: c.textMuted),
                ),
              ]),

              const SizedBox(height: 24),

              // Sign out
              OutlinedButton.icon(
                onPressed: _loading ? null : _signOut,
                icon: _loading
                    ? SizedBox(
                        width: 16, height: 16,
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

              const SizedBox(height: 12),

              // Delete account
              TextButton(
                onPressed: _loading ? null : _showDeleteConfirm,
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                      fontSize: 13,
                      color: c.textMuted,
                      decoration: TextDecoration.underline),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info card container ───────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.surfaceAlt),
        ),
        child: Column(children: children),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: c.textMuted)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
