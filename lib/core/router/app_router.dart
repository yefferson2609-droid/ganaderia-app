import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/vacas/vacas_screen.dart';
import '../../features/vacas/vaca_form_screen.dart';
import '../../features/vacas/vaca_detalle_screen.dart';
import '../../features/toros/toros_screen.dart';
import '../../features/toros/toro_form_screen.dart';
import '../../features/caballos/caballos_screen.dart';
import '../../features/caballos/caballo_form_screen.dart';
import '../../features/lotes/lotes_screen.dart';
import '../../features/lotes/lote_form_screen.dart';
import '../../features/lotes/lote_detalle_screen.dart';
import '../../features/tipos_evento/tipos_evento_screen.dart';
import '../../features/tipos_evento/tipo_evento_form_screen.dart';
import '../../features/eventos/evento_masivo_screen.dart';
import '../../features/ubicaciones/ubicaciones_screen.dart';
import '../../features/finanzas/finanzas_screen.dart';
import '../../features/finanzas/movimiento_form_screen.dart';
import '../../features/finanzas/conceptos_financieros_screen.dart';
import '../../features/finanzas/concepto_financiero_form_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isLoginRoute = state.matchedLocation == '/login';
      if (user == null && !isLoginRoute) return '/login';
      if (user != null && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),

      // Vacas
      GoRoute(
        path: '/vacas',
        builder: (_, __) => const VacasScreen(),
        routes: [
          GoRoute(path: 'nueva', builder: (_, __) => const VacaFormScreen()),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                VacaDetalleScreen(id: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (_, state) =>
                    VacaFormScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),

      // Toros
      GoRoute(
        path: '/toros',
        builder: (_, __) => const TorosScreen(),
        routes: [
          GoRoute(path: 'nuevo', builder: (_, __) => const ToroFormScreen()),
          GoRoute(
            path: ':id/editar',
            builder: (_, state) =>
                ToroFormScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),

      // Caballos
      GoRoute(
        path: '/caballos',
        builder: (_, __) => const CaballosScreen(),
        routes: [
          GoRoute(path: 'nuevo', builder: (_, __) => const CaballoFormScreen()),
          GoRoute(
            path: ':id/editar',
            builder: (_, state) =>
                CaballoFormScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),

      // Lotes
      GoRoute(
        path: '/lotes',
        builder: (_, __) => const LotesScreen(),
        routes: [
          GoRoute(path: 'nuevo', builder: (_, __) => const LoteFormScreen()),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                LoteDetalleScreen(id: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (_, state) =>
                    LoteFormScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),

      // Tipos de evento
      GoRoute(
        path: '/tipos-evento',
        builder: (_, __) => const TiposEventoScreen(),
        routes: [
          GoRoute(
              path: 'nuevo',
              builder: (_, __) => const TipoEventoFormScreen()),
          GoRoute(
            path: ':id/editar',
            builder: (_, state) =>
                TipoEventoFormScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),

      // Evento masivo
      GoRoute(
        path: '/evento-masivo',
        builder: (_, __) => const EventoMasivoScreen(),
      ),

      // Ubicaciones
      GoRoute(
        path: '/ubicaciones',
        builder: (_, __) => const UbicacionesScreen(),
      ),

      // Finanzas
      GoRoute(
        path: '/finanzas',
        builder: (_, __) => const FinanzasScreen(),
        routes: [
          GoRoute(
            path: 'nuevo',
            builder: (_, state) => MovimientoFormScreen(
              tipoInicial: state.uri.queryParameters['tipo'] ?? 'ingreso',
            ),
          ),
          GoRoute(
            path: ':id/editar',
            builder: (_, state) =>
                MovimientoFormScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'conceptos',
            builder: (_, __) => const ConceptosFinancierosScreen(),
            routes: [
              GoRoute(
                path: 'nuevo',
                builder: (_, state) => ConceptoFinancieroFormScreen(
                  tipoInicial:
                      state.uri.queryParameters['tipo'] ?? 'ingreso',
                ),
              ),
              GoRoute(
                path: ':id/editar',
                builder: (_, state) => ConceptoFinancieroFormScreen(
                    id: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
