import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/database/local_db.dart';
import '../../core/models/ubicacion.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/permisos_provider.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/repositories/movimiento_financiero_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';

final _moneyFormat = NumberFormat.currency(locale: 'en_US', symbol: r'$');

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, int> _totales = {};
  List<Ubicacion> _ubicaciones = [];
  Map<String, Map<String, int>> _conteosPorUbicacion = {};
  double _utilidadMes = 0;
  bool _loading = true;
  final _ubicacionRepo = UbicacionRepository();
  final _movimientoRepo = MovimientoFinancieroRepository();

  @override
  void initState() {
    super.initState();
    _loadConteos();
  }

  Future<void> _loadConteos() async {
    setState(() => _loading = true);
    final db = LocalDb.instance.db;

    final vacas = await db.rawQuery(
        "SELECT COUNT(*) as c FROM vacas WHERE deleted=0 AND estado='activa'");
    final toros = await db.rawQuery(
        "SELECT COUNT(*) as c FROM toros WHERE deleted=0 AND estado='activo'");
    final caballos = await db.rawQuery(
        "SELECT COUNT(*) as c FROM caballos WHERE deleted=0 AND estado='activo'");
    final cerdos = await db.rawQuery(
        "SELECT COALESCE(SUM(hembras+machos),0) as c FROM lotes WHERE deleted=0 AND tipo='cerdo'");
    final ovejos = await db.rawQuery(
        "SELECT COALESCE(SUM(hembras+machos),0) as c FROM lotes WHERE deleted=0 AND tipo='ovejo'");

    _totales = {
      'vacas': (vacas.first['c'] as int?) ?? 0,
      'toros': (toros.first['c'] as int?) ?? 0,
      'caballos': (caballos.first['c'] as int?) ?? 0,
      'cerdos': (cerdos.first['c'] as int?) ?? 0,
      'ovejos': (ovejos.first['c'] as int?) ?? 0,
    };

    _ubicaciones = await _ubicacionRepo.getAll(soloActivas: true);
    _conteosPorUbicacion = {};
    for (final ub in _ubicaciones) {
      _conteosPorUbicacion[ub.id] =
          await _ubicacionRepo.getConteosPorUbicacion(ub.id);
    }

    final now = DateTime.now();
    final totalesFinanzas = await _movimientoRepo.getTotales(
      desde: DateTime(now.year, now.month, 1),
      hasta: now,
    );
    _utilidadMes = totalesFinanzas['utilidad'] ?? 0;

    if (mounted) await context.read<PermisosProvider>().cargar();

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final permisos = context.watch<PermisosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganadería'),
        actions: [
          if (sync.isSyncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: Icon(sync.isOnline ? Icons.cloud_done : Icons.cloud_off),
              tooltip: sync.isOnline ? 'En línea' : 'Sin conexión',
              onPressed: sync.isOnline
                  ? () async {
                      await sync.syncAll();
                      _loadConteos();
                    }
                  : null,
            ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') {
                await context.read<AuthProvider>().signOut();
                if (mounted) context.go('/login');
              } else if (v == 'tipos') {
                context.push('/tipos-evento');
              } else if (v == 'ubicaciones') {
                context.push('/ubicaciones').then((_) => _loadConteos());
              } else if (v == 'evento_masivo') {
                context.push('/evento-masivo').then((_) => _loadConteos());
              } else if (v == 'finanzas') {
                context.push('/finanzas').then((_) => _loadConteos());
              } else if (v == 'usuarios') {
                context.push('/usuarios').then((_) => _loadConteos());
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'evento_masivo', child: Text('Evento masivo')),
              const PopupMenuItem(value: 'tipos', child: Text('Tipos de evento')),
              const PopupMenuItem(value: 'ubicaciones', child: Text('Ubicaciones')),
              const PopupMenuItem(value: 'finanzas', child: Text('Finanzas')),
              if (permisos.puedeVer('usuarios'))
                const PopupMenuItem(value: 'usuarios', child: Text('Usuarios')),
              const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadConteos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Totales generales
                    Text('Total general',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.1,
                      children: [
                        _AnimalCard(label: 'Vacas', count: _totales['vacas'] ?? 0,
                            icon: Icons.local_activity, color: const Color(0xFF2E7D32),
                            onTap: () => context.push('/vacas').then((_) => _loadConteos())),
                        _AnimalCard(label: 'Toros', count: _totales['toros'] ?? 0,
                            icon: Icons.male, color: const Color(0xFF1565C0),
                            onTap: () => context.push('/toros').then((_) => _loadConteos())),
                        _AnimalCard(label: 'Caballos', count: _totales['caballos'] ?? 0,
                            icon: Icons.directions_run, color: const Color(0xFF795548),
                            onTap: () => context.push('/caballos').then((_) => _loadConteos())),
                        _AnimalCard(label: 'Cerdos', count: _totales['cerdos'] ?? 0,
                            icon: Icons.set_meal, color: const Color(0xFFE65100),
                            onTap: () => context.push('/lotes').then((_) => _loadConteos())),
                        _AnimalCard(label: 'Ovejos', count: _totales['ovejos'] ?? 0,
                            icon: Icons.filter_vintage, color: const Color(0xFF6A1B9A),
                            onTap: () => context.push('/lotes').then((_) => _loadConteos())),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Text('Finanzas',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context
                            .push('/finanzas')
                            .then((_) => _loadConteos()),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet,
                                  color: _utilidadMes >= 0
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Utilidad del mes',
                                        style: TextStyle(fontSize: 12)),
                                    Text(
                                      _moneyFormat.format(_utilidadMes),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: _utilidadMes >= 0
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFC62828),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Por ubicación
                    if (_ubicaciones.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Por ubicación',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._ubicaciones.map((ub) {
                        final c = _conteosPorUbicacion[ub.id] ?? {};
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.location_on,
                                      color: Color(0xFF2E7D32), size: 18),
                                  const SizedBox(width: 6),
                                  Text(ub.nombre,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ]),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _MiniCount(label: 'Vacas', count: c['vacas'] ?? 0, color: const Color(0xFF2E7D32)),
                                    _MiniCount(label: 'Toros', count: c['toros'] ?? 0, color: const Color(0xFF1565C0)),
                                    _MiniCount(label: 'Caballos', count: c['caballos'] ?? 0, color: const Color(0xFF795548)),
                                    _MiniCount(label: 'Cerdos', count: c['cerdos'] ?? 0, color: const Color(0xFFE65100)),
                                    _MiniCount(label: 'Ovejos', count: c['ovejos'] ?? 0, color: const Color(0xFF6A1B9A)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnimalCard({
    required this.label, required this.count,
    required this.icon, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 6),
              Text(count.toString(),
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCount extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniCount({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(count.toString(),
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
