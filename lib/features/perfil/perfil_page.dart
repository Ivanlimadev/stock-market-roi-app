import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';

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

class _LoggedPerfil extends StatefulWidget {
  final User user;
  const _LoggedPerfil({required this.user});

  @override
  State<_LoggedPerfil> createState() => _LoggedPerfilState();
}

class _LoggedPerfilState extends State<_LoggedPerfil> {
  bool _loading = false;

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
    final initials = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    final verified = user.emailConfirmedAt != null;
    final memberSince = _formatDate(user.createdAt);

    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Avatar
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Center(
                        child: Text(initials,
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.emerald)),
                      ),
                    ),
                    if (verified)
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.emerald,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: c.background, width: 2),
                          ),
                          child: Icon(Icons.check_rounded,
                              size: 13, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(email,
                    style: TextStyle(fontSize: 14, color: c.textSecond)),
              ),
              const SizedBox(height: 32),

              // Info cards
              _InfoCard(children: [
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
                Divider(height: 1, color: c.surfaceAlt),
                _InfoRow(
                  icon: Icons.shield_outlined,
                  label: 'Account ID',
                  value: user.id.substring(0, 8).toUpperCase() + '…',
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
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
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
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
