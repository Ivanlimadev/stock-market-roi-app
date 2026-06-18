import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class WatchlistPage extends StatelessWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Watchlist')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_border_rounded, size: 64, color: context.colors.textMuted),
              SizedBox(height: 16),
              Text('Sign in to manage your watchlist',
                style: TextStyle(color: context.colors.textMuted)),
              SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/login'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Watchlist')),
      body: Center(
        child: Text('Watchlist — coming soon',
          style: TextStyle(color: context.colors.textMuted)),
      ),
    );
  }
}
