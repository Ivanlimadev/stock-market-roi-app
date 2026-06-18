import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent    = false;
  String? _error;

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://stockmarketroi.com/auth/reset-password',
      );
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Reset Password'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _sent ? _SentState(email: _email.text.trim()) : _FormState(
            email: _email,
            loading: _loading,
            error: _error,
            onSend: _send,
          ),
        ),
      ),
    );
  }
}

class _FormState extends StatelessWidget {
  final TextEditingController email;
  final bool loading;
  final String? error;
  final VoidCallback onSend;
  const _FormState({required this.email, required this.loading, required this.error, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 16),
        Text(
          'Enter the email address associated with your account and we\'ll send a reset link.',
          style: TextStyle(color: context.colors.textMuted, height: 1.5),
        ),
        SizedBox(height: 32),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofocus: true,
          style: TextStyle(color: context.colors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined, color: context.colors.textMuted),
          ),
          onSubmitted: (_) => onSend(),
        ),
        if (error != null) ...[
          SizedBox(height: 12),
          Text(error!, style: TextStyle(color: AppColors.red, fontSize: 13)),
        ],
        SizedBox(height: 24),
        FilledButton(
          onPressed: loading ? null : onSend,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: loading
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _SentState extends StatelessWidget {
  final String email;
  const _SentState({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.emerald.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.emerald),
        ),
        SizedBox(height: 24),
        Text('Check your email',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
        SizedBox(height: 12),
        Text(
          'We sent a reset link to\n$email\n\nClick the link in the email to set a new password, then sign in here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textMuted, height: 1.6),
        ),
        SizedBox(height: 32),
        FilledButton(
          onPressed: () => context.go('/login'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.white,
            minimumSize: const Size(200, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Back to Sign In', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
