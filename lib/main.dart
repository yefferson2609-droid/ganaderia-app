import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/database/local_db.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/sync_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://punqawvuwxlrdipapnja.supabase.co',
    // ignore: deprecated_member_use
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1bnFhd3Z1d3hscmRpcGFwbmphIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE5MDIwMjcsImV4cCI6MjA5NzQ3ODAyN30.T2KQyuuDU-06a_XrDejME-einpaCICIkJfBkPpOHZuk',
  );  await LocalDb.instance.init();

  runApp(const GanaderiaApp());
}

class GanaderiaApp extends StatelessWidget {
  const GanaderiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: MaterialApp.router(
        title: 'Ganadería',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
