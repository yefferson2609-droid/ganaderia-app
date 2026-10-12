import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/providers/auth_provider.dart';
import 'core/providers/finca_provider.dart';
import 'core/providers/permisos_provider.dart';
import 'core/providers/sync_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Proyecto multi-finca "ganaderia-comercial" (NO el de la finca original).
  await Supabase.initialize(
    url: 'https://oaukzxwcohocqafttfki.supabase.co',
    publishableKey: 'sb_publishable_T5it3WU9nc1f95IXtbCQ9w_3W5aG7HV',
  );
  // Abre la última finca usada para poder trabajar sin internet.
  await FincaProvider.abrirUltima();

  runApp(const GanaderiaApp());
}

class GanaderiaApp extends StatelessWidget {
  const GanaderiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FincaProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => PermisosProvider()),
      ],
      child: MaterialApp.router(
        title: 'Ganadería',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
