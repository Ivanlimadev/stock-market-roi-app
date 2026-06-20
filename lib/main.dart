import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ogbramvzqmbkizspeccg.supabase.co',
  );
  const supabaseKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_O9J-hDKHWgUQfOIFxaN1wA_eRbimHqy',
  );

  await Supabase.initialize(
    url:            supabaseUrl,
    publishableKey: supabaseKey,
  );

  await Firebase.initializeApp();

  runApp(const ProviderScope(child: App()));

  // Initialise after UI is running — avoids white screen when iOS shows
  // the notification permission dialog before runApp completes.
  NotificationService.initialize().ignore();
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'Stock Market ROI',
      theme: appLightTheme,
      darkTheme: appTheme,
      themeMode: mode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
