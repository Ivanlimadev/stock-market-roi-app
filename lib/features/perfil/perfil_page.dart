import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return user == null ? const _GuestPerfil() : _LoggedPerfil(user: user);
  }
}

// ─── Guest (não logado) ───────────────────────────────────────────────────────

class _GuestPerfil extends StatelessWidget {
  const _GuestPerfil();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Perfil')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(Icons.person_outline_rounded,
                    size: 40, color: context.colors.textMuted),
              ),
              SizedBox(height: 24),
              Text(
                'Crie sua conta',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Save assets, build your portfolio and track your favorites.',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textSecond,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 36),
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
                  child: Text(
                    'Create free account',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(height: 12),
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
                  child: Text(
                    'Entrar',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
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

  Future<void> _signOut() async {
    setState(() => _loading = true);
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      setState(() => _loading = false);
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final email    = widget.user.email ?? '';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : 'U';

    return Scaffold(
      appBar: AppBar(title: Text('Perfil')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SizedBox(height: 32),
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                email,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textSecond,
                ),
              ),
              SizedBox(height: 40),

              // Divider section
              _InfoTile(
                icon: Icons.email_outlined,
                label: 'E-mail',
                value: email,
              ),

              SizedBox(height: 12),
              Divider(color: context.colors.surfaceAlt),
              SizedBox(height: 12),

              // Logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _signOut,
                  icon: _loading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.logout_rounded, size: 18),
                  label: Text('Sair da conta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: BorderSide(color: AppColors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.surfaceAlt),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.textMuted),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: context.colors.textMuted)),
              SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 14, color: context.colors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}
