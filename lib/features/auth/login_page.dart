import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email    = TextEditingController();
  final _password = TextEditingController();
  bool _loading   = false;
  bool _showPw    = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 48),

              // Logo
              Icon(Icons.bar_chart_rounded, size: 48, color: AppColors.emerald),
              SizedBox(height: 16),
              Text(
                'Stock Market ROI',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
              ),
              SizedBox(height: 8),
              Text(
                'Sign in to your account',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textMuted),
              ),
              SizedBox(height: 40),

              // Email
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: context.colors.textMuted),
                ),
              ),
              SizedBox(height: 16),

              // Password
              TextField(
                controller: _password,
                obscureText: !_showPw,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outlined, color: context.colors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPw ? Icons.visibility_off : Icons.visibility,
                      color: context.colors.textMuted,
                    ),
                    onPressed: () => setState(() => _showPw = !_showPw),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Forgot password?',
                    style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
                ),
              ),

              if (_error != null) ...[
                SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: AppColors.red, fontSize: 13)),
              ],
              SizedBox(height: 20),

              // Sign in button
              FilledButton(
                onPressed: _loading ? null : _login,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Sign In', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              SizedBox(height: 16),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account?", style: TextStyle(color: context.colors.textMuted)),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text('Create one', style: TextStyle(color: AppColors.emerald)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
