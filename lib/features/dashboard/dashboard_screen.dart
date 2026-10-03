import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/ubicacion.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/permisos_provider.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/repositories/actividad_repository.dart';
import '../../core/repositories/movimiento_financiero_repository.dart';
import '../../core/repositories/registro_salud_repository.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/solicitud_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auditoria.dart';
import '../../core/widgets/animal_face.dart';
import '../../core/widgets/creador_info.dart';

final _moneyFormat = NumberFormat.currency(locale: 'en_US', symbol: r'$');

const _kAvisoSolicitudesVistas = 'aviso_solicitudes_vistas';

class _Aviso {
  final IconData icon;
  final Color color;
  final String texto;
  final String ruta;
  final bool marcarSolicitudesVistas;
  const _Aviso(this.icon, this.color, this.texto, this.ruta,
      {this.marcarSolicitudesVistas = false});
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, int> _totales = {};
  List<Ubicacion> _ubicaciones = [];
  Map<String, Map<String, int>> _conteosPorUbicacion = {};
  Map<String, int> _sinUbicacion = {};
  Map<EstadoProduccion, int> _produccion = {};
  List<_Aviso> _avisos = [];
  double _utilidadMes = 0;
  bool _loading = true;
  DateTime? _ultimaSyncVista;
  final _ubicacionRepo = UbicacionRepository();
  final _movimientoRepo = MovimientoFinancieroRepository();

  @override
  void initState() {
    super.initState();
    _loadConteos();
  }

  Future<void> _loadConteos() async {
    if (_totales.isEmpty) setState(() => _loading = true);

    _totales = await _ubicacionRepo.getConteosPorUbicacion(null, todas: true);
    _ubicaciones = await _ubicacionRepo.getAll(soloActivas: true);
    _conteosPorUbicacion = {};
    for (final ub in _ubicaciones) {
      _conteosPorUbicacion[ub.id] =
          await _ubicacionRepo.getConteosPorUbicacion(ub.id);
    }
    _sinUbicacion = await _ubicacionRepo.getConteosPorUbicacion(null);
    _produccion = await ReproduccionRepository().conteoProduccion();

    final now = DateTime.now();
    final totalesFinanzas = await _movimientoRepo.getTotales(
      desde: DateTime(now.year, now.month, 1),
      hasta: now,
    );
    _utilidadMes = totalesFinanzas['utilidad'] ?? 0;

    if (mounted) await context.read<PermisosProvider>().cargar();
    await _cargarAvisos();
    if (mounted) await context.read<SyncProvider>().contarPendientes();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cargarAvisos() async {
    final uid = usuarioActualId();
    if (uid == null || !mounted) return;
    final permisos = context.read<PermisosProvider>();
    final avisos = <_Aviso>[];
    String plural(int n, String uno, String varios) => n == 1 ? uno : varios;

    final actividadRepo = ActividadRepository();
    final misPendientes = await actividadRepo.contarPendientesDe(uid);
    if (misPendientes > 0) {
      avisos.add(_Aviso(
          Icons.assignment_late,
          AppColors.warning,
          plural(misPendientes, 'Tienes 1 actividad pendiente',
              'Tienes $misPendientes actividades pendientes'),
          '/actividades'));
    }

    final solicitudRepo = SolicitudRepository();
    if (permisos.puedeEditar('solicitudes')) {
      final porRevisar = await solicitudRepo.contarPendientes();
      if (porRevisar > 0) {
        avisos.add(_Aviso(
            Icons.inventory_2,
            AppColors.info,
            plural(porRevisar, 'Tienes 1 solicitud pendiente de revisar',
                'Tienes $porRevisar solicitudes pendientes de revisar'),
            '/solicitudes'));
      }
    }

    DateTime vistas = DateTime.now().subtract(const Duration(days: 7));
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString('$_kAvisoSolicitudesVistas:$uid');
      if (guardado != null) vistas = DateTime.tryParse(guardado) ?? vistas;
    } catch (_) {}
    final resueltas = await solicitudRepo.contarResueltasDe(uid, vistas);
    if (resueltas > 0) {
      avisos.add(_Aviso(
          Icons.mark_email_read,
          AppColors.success,
          plural(resueltas, '1 de tus solicitudes fue resuelta',
              '$resueltas de tus solicitudes fueron resueltas'),
          '/solicitudes',
          marcarSolicitudesVistas: true));
    }

    if (permisos.puedeVer('salud')) {
      final saludRepo = RegistroSaludRepository();
      final enTratamiento = await saludRepo.contarEnTratamiento();
      if (enTratamiento > 0) {
        avisos.add(_Aviso(
            Icons.healing,
            AppColors.danger,
            plural(enTratamiento, '1 animal en tratamiento',
                '$enTratamiento animales en tratamiento'),
            '/salud'));
      }
      final dosis = await saludRepo.contarDosisPendientes();
      if (dosis > 0) {
        avisos.add(_Aviso(
            Icons.vaccines,
            AppColors.danger,
            plural(dosis, '1 dosis pendiente de aplicar',
                '$dosis dosis pendientes de aplicar'),
            '/salud'));
      }
    }

    final completadas = await actividadRepo.contarCompletadasDesde(
        DateTime.now().subtract(const Duration(days: 2)));
    if (completadas > 0) {
      avisos.add(_Aviso(
          Icons.task_alt,
          AppColors.success,
          plural(completadas, '1 actividad completada recientemente',
              '$completadas actividades completadas recientemente'),
          '/actividades'));
    }

    _avisos = avisos;
  }

  Future<void> _abrirAviso(_Aviso a) async {
    if (a.marcarSolicitudesVistas) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_kAvisoSolicitudesVistas:${usuarioActualId()}',
            DateTime.now().toIso8601String());
      } catch (_) {}
    }
    if (mounted) context.push(a.ruta).then((_) => _loadConteos());
  }

  void _abrir(String ruta) => context.push(ruta).then((_) => _loadConteos());

  Widget _seccion(String titulo) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(titulo,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _filaConteos(Map<String, int> c) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MiniCount(label: 'Vacas', count: c['vacas'] ?? 0, color: AppColors.primary),
          _MiniCount(label: 'Toros', count: c['toros'] ?? 0, color: AppColors.info),
          _MiniCount(label: 'Terneros', count: c['terneros'] ?? 0, color: AppColors.primaryLight),
          _MiniCount(label: 'Caballos', count: c['caballos'] ?? 0, color: AppColors.secondary),
          _MiniCount(label: 'Cerdos', count: c['cerdos'] ?? 0, color: AppColors.warning),
          _MiniCount(label: 'Ovejos', count: c['ovejos'] ?? 0, color: AppColors.accentPurple),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final permisos = context.watch<PermisosProvider>();

    // Al terminar una sincronización, recargar los números.
    if (!sync.isSyncing &&
        sync.lastSync != null &&
        sync.lastSync != _ultimaSyncVista) {
      _ultimaSyncVista = sync.lastSync;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadConteos();
      });
    }

    final menu = <(String, String, String?)>[
      ('/inventario', 'Inventario', null),
      ('/evento-masivo', 'Evento masivo', 'eventos'),
      ('/salud', 'Salud', 'salud'),
      ('/actividades', 'Actividades', 'actividades'),
      ('/solicitudes', 'Solicitudes', 'solicitudes'),
      ('/reportes', 'Reportes', 'reportes'),
      ('/tipos-evento', 'Tipos de evento', 'eventos'),
      ('/ubicaciones', 'Ubicaciones', 'ubicaciones'),
      ('/finanzas', 'Finanzas', 'finanzas'),
      ('/usuarios', 'Usuarios', 'usuarios'),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: const Row(children: [
          HierroLogo(size: 34),
          SizedBox(width: 10),
          Text('Ganadería'),
        ]),
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
              icon: Icon(!sync.isOnline
                  ? Icons.cloud_off
                  : sync.lastError != null
                      ? Icons.sync_problem
                      : Icons.cloud_done),
              tooltip: !sync.isOnline
                  ? 'Sin conexión'
                  : sync.lastSync != null
                      ? 'Actualizado ${haceCuanto(sync.lastSync!)}'
                      : 'En línea',
              onPressed: sync.isOnline
                  ? () async {
                      await sync.syncAll();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(sync.lastError == null
                            ? 'Sincronizado correctamente'
                            : 'Algunos datos no se sincronizaron. Intenta de nuevo.'),
                        backgroundColor: sync.lastError == null
                            ? AppColors.success
                            : AppColors.danger,
                      ));
                    }
                  : null,
            ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') {
                await context.read<AuthProvider>().signOut();
                if (context.mounted) context.go('/login');
              } else {
                _abrir(v);
              }
            },
            itemBuilder: (_) => [
              for (final (ruta, label, modulo) in menu)
                if (modulo == null || permisos.puedeVer(modulo))
                  PopupMenuItem(value: ruta, child: Text(label)),
              const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (sync.isOnline) await sync.syncAll();
                await _loadConteos();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _EstadoSync(sync: sync),
                    if (_avisos.isNotEmpty) ...[
                      _seccion('Avisos'),
                      ..._avisos.map((a) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: Icon(a.icon, color: a.color),
                              title: Text(a.texto,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _abrirAviso(a),
                            ),
                          )),
                    ],

                    _seccion('Total general'),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.95,
                      children: [
                        if (permisos.puedeVer('vacas'))
                          _AnimalCard(label: 'Vacas', tipo: 'vaca',
                              count: _totales['vacas'] ?? 0, color: AppColors.primary,
                              onTap: () => _abrir('/vacas')),
                        if (permisos.puedeVer('toros'))
                          _AnimalCard(label: 'Toros', tipo: 'toro',
                              count: _totales['toros'] ?? 0, color: AppColors.info,
                              onTap: () => _abrir('/toros')),
                        if (permisos.puedeVer('terneros'))
                          _AnimalCard(label: 'Terneros', tipo: 'ternero',
                              count: _totales['terneros'] ?? 0, color: AppColors.primaryLight,
                              onTap: () => _abrir('/terneros')),
                        if (permisos.puedeVer('caballos'))
                          _AnimalCard(label: 'Caballos', tipo: 'caballo',
                              count: _totales['caballos'] ?? 0, color: AppColors.secondary,
                              onTap: () => _abrir('/caballos')),
                        if (permisos.puedeVer('lotes'))
                          _AnimalCard(label: 'Cerdos', tipo: 'cerdo',
                              count: _totales['cerdos'] ?? 0, color: AppColors.warning,
                              onTap: () => _abrir('/lotes')),
                        if (permisos.puedeVer('lotes'))
                          _AnimalCard(label: 'Ovejos', tipo: 'ovejo',
                              count: _totales['ovejos'] ?? 0, color: AppColors.accentPurple,
                              onTap: () => _abrir('/lotes')),
                      ],
                    ),

                    if (permisos.puedeVer('vacas') && (_totales['vacas'] ?? 0) > 0) ...[
                      _seccion('Producción'),
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _abrir('/inventario'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MiniCount(
                                    label: 'En ordeño',
                                    count: _produccion[EstadoProduccion.enOrdeno] ?? 0,
                                    color: AppColors.info),
                                _MiniCount(
                                    label: 'Secas',
                                    count: _produccion[EstadoProduccion.seca] ?? 0,
                                    color: AppColors.warning),
                                _MiniCount(
                                    label: 'Sin partos',
                                    count: _produccion[EstadoProduccion.sinPartos] ?? 0,
                                    color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (permisos.puedeVer('finanzas')) ...[
                      _seccion('Finanzas'),
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _abrir('/finanzas'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.account_balance_wallet,
                                    color: _utilidadMes >= 0
                                        ? AppColors.primary
                                        : AppColors.danger),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Utilidad del mes',
                                          style: TextStyle(fontSize: 12)),
                                      Text(
                                        _moneyFormat.format(_utilidadMes),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: _utilidadMes >= 0
                                              ? AppColors.primary
                                              : AppColors.danger,
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
                    ],

                    // Por ubicación
                    if (_ubicaciones.isNotEmpty) ...[
                      _seccion('Por ubicación'),
                      ..._ubicaciones.map((ub) => _UbicacionCard(
                            nombre: ub.nombre,
                            child: _filaConteos(_conteosPorUbicacion[ub.id] ?? {}),
                          )),
                      if (_sinUbicacion.values.any((v) => v > 0))
                        _UbicacionCard(
                          nombre: 'Sin ubicación',
                          icon: Icons.location_off,
                          child: _filaConteos(_sinUbicacion),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// "Última sincronización: hoy a las 3:45 p. m." + cambios sin subir.
class _EstadoSync extends StatelessWidget {
  final SyncProvider sync;
  const _EstadoSync({required this.sync});

  String _cuando(DateTime f) {
    final hoy = DateTime.now();
    final dia = DateTime(f.year, f.month, f.day);
    final hora = DateFormat('h:mm a', 'en_US')
        .format(f)
        .replaceAll('AM', 'a. m.')
        .replaceAll('PM', 'p. m.');
    final diff = DateTime(hoy.year, hoy.month, hoy.day).difference(dia).inDays;
    if (diff == 0) return 'hoy a las $hora';
    if (diff == 1) return 'ayer a las $hora';
    return 'el ${DateFormat('dd/MM/yyyy').format(f)} a las $hora';
  }

  @override
  Widget build(BuildContext context) {
    final IconData icono;
    final Color color;
    final String texto;
    if (sync.isSyncing) {
      icono = Icons.sync;
      color = AppColors.info;
      texto = 'Sincronizando...';
    } else if (sync.lastSync == null) {
      icono = Icons.cloud_off;
      color = Colors.grey;
      texto = 'Todavía no se ha sincronizado';
    } else {
      icono = sync.lastError != null ? Icons.sync_problem : Icons.cloud_done;
      color = sync.lastError != null ? AppColors.warning : AppColors.success;
      texto = 'Última sincronización: ${_cuando(sync.lastSync!)}';
    }

    final detalles = <String>[
      if (!sync.isOnline) 'Sin conexión',
      if (sync.lastError != null && !sync.isSyncing)
        'El último intento tuvo errores',
      if (sync.pendientes > 0)
        '${sync.pendientes} cambio${sync.pendientes == 1 ? '' : 's'} sin subir'
      else if (sync.lastSync != null)
        'Todo está subido',
    ];

    return Card(
      margin: EdgeInsets.zero,
      color: color.withOpacity(0.08),
      child: ListTile(
        dense: true,
        leading: Icon(icono, color: color),
        title: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: detalles.isEmpty ? null : Text(detalles.join(' · ')),
        trailing: sync.isOnline && !sync.isSyncing
            ? IconButton(
                tooltip: 'Sincronizar ahora',
                icon: const Icon(Icons.refresh),
                onPressed: sync.syncAll,
              )
            : null,
      ),
    );
  }
}

class _UbicacionCard extends StatelessWidget {
  final String nombre;
  final IconData icon;
  final Widget child;
  const _UbicacionCard(
      {required this.nombre, required this.child, this.icon = Icons.location_on});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text(nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  final String label;
  final String tipo;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _AnimalCard({
    required this.label, required this.tipo, required this.count,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimalFace(tipo: tipo, size: 44),
              const SizedBox(height: 4),
              Text(count.toString(),
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
