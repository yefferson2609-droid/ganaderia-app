import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/perfil_usuario.dart';
import '../../core/models/solicitud.dart';
import '../../core/models/ubicacion.dart';
import '../../core/providers/permisos_provider.dart';
import '../../core/repositories/perfil_usuario_repository.dart';
import '../../core/repositories/solicitud_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auditoria.dart';

final _fmt = DateFormat('dd/MM/yyyy');
final _money = NumberFormat.currency(locale: 'en_US', symbol: r'$');

Color estadoSolicitudColor(String e) {
  switch (e) {
    case 'pendiente':
      return AppColors.warning;
    case 'aprobada':
      return AppColors.info;
    case 'completada':
      return AppColors.success;
    case 'rechazada':
      return AppColors.danger;
  }
  return Colors.grey;
}

class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({super.key});

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  final _repo = SolicitudRepository();
  List<Solicitud> _solicitudes = [];
  Map<String, PerfilUsuario> _usuarios = {};
  Map<String, Ubicacion> _ubicaciones = {};
  String? _filtro; // null = todas
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final perfiles = await PerfilUsuarioRepository().getAll();
    _usuarios = {for (final p in perfiles) p.id: p};
    final ubs = await UbicacionRepository().getAll();
    _ubicaciones = {for (final u in ubs) u.id: u};
    _solicitudes = await _repo.getAll(estado: _filtro);
    if (mounted) setState(() => _loading = false);
  }

  String _nombre(String? id) {
    if (id == null) return '—';
    final p = _usuarios[id];
    if (p == null) return 'Usuario';
    return p.nombre.isNotEmpty ? p.nombre : p.correo;
  }

  Future<bool> _confirmar(String titulo, String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _nueva() async {
    final itemCtrl = TextEditingController();
    final cantCtrl = TextEditingController();
    final notaCtrl = TextEditingController();
    String? ubicacionId;
    final activas = _ubicaciones.values.where((u) => u.activa).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Nueva solicitud'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: itemCtrl,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Insumo solicitado *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cantCtrl,
                decoration:
                    const InputDecoration(labelText: 'Cantidad (opcional)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: ubicacionId,
                decoration:
                    const InputDecoration(labelText: 'Ubicación (opcional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Ninguna')),
                  ...activas.map((u) =>
                      DropdownMenuItem(value: u.id, child: Text(u.nombre))),
                ],
                onChanged: (v) => setSt(() => ubicacionId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notaCtrl,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
                maxLines: 2,
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () {
                  if (itemCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Solicitar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.create(
      item: itemCtrl.text.trim(),
      cantidad: textoONull(cantCtrl.text),
      ubicacionId: ubicacionId,
      nota: textoONull(notaCtrl.text),
    );
    _load();
  }

  Future<void> _completar(Solicitud s) async {
    final costoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Completar solicitud'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Solicitud: ${s.item}${s.cantidad != null ? ' (${s.cantidad})' : ''}'),
          const SizedBox(height: 12),
          TextField(
            controller: costoCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Costo total (USD) *',
              prefixText: r'$ ',
              helperText: 'Se registrará como gasto en Finanzas',
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () {
                if (double.tryParse(costoCtrl.text.replaceAll(',', '.')) == null) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Completar')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.completar(s,
        costo: double.parse(costoCtrl.text.replaceAll(',', '.')));
    _load();
  }

  Future<void> _accion(Solicitud s, String v) async {
    switch (v) {
      case 'aprobar':
        await _repo.aprobar(s.id);
        _load();
      case 'rechazar':
        if (await _confirmar(
            'Rechazar solicitud', '¿Rechazar la solicitud de "${s.item}"?')) {
          await _repo.rechazar(s.id);
          _load();
        }
      case 'completar':
        await _completar(s);
      case 'eliminar':
        if (await _confirmar(
            'Eliminar solicitud', '¿Eliminar la solicitud de "${s.item}"?')) {
          await _repo.delete(s.id);
          _load();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permisos = context.watch<PermisosProvider>();
    final puedeResolver = permisos.puedeEditar('solicitudes');
    final puedeEliminar = permisos.puedeEliminar('solicitudes');
    final uid = usuarioActualId();

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nueva,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Nueva solicitud'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [null, ...kEstadoSolicitudLabels.keys].map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e == null ? 'Todas' : kEstadoSolicitudLabels[e]!),
                    selected: _filtro == e,
                    onSelected: (_) {
                      _filtro = e;
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _solicitudes.isEmpty
                    ? const Center(child: Text('No hay solicitudes'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                          itemCount: _solicitudes.length,
                          itemBuilder: (_, i) {
                            final s = _solicitudes[i];
                            final color = estadoSolicitudColor(s.estado);
                            final esMia = s.solicitadoPor == uid;
                            final acciones = <PopupMenuEntry<String>>[
                              if (puedeResolver && s.estado == 'pendiente') ...[
                                const PopupMenuItem(
                                    value: 'aprobar', child: Text('Aprobar')),
                                const PopupMenuItem(
                                    value: 'rechazar', child: Text('Rechazar')),
                              ],
                              if (puedeResolver &&
                                  (s.estado == 'pendiente' ||
                                      s.estado == 'aprobada'))
                                const PopupMenuItem(
                                    value: 'completar',
                                    child: Text('Completar (comprado)')),
                              if (puedeEliminar || (esMia && s.pendiente))
                                const PopupMenuItem(
                                    value: 'eliminar',
                                    child: Text('Eliminar solicitud',
                                        style:
                                            TextStyle(color: AppColors.danger))),
                            ];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withOpacity(0.15),
                                  child: Icon(Icons.inventory_2_outlined,
                                      color: color),
                                ),
                                title: Text(
                                    '${s.item}${s.cantidad != null ? ' · ${s.cantidad}' : ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        kEstadoSolicitudLabels[s.estado] ??
                                            s.estado,
                                        style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        'Solicitado por: ${_nombre(s.solicitadoPor)} · ${_fmt.format(s.createdAt)}'),
                                    if (s.ubicacionId != null)
                                      Text(_ubicaciones[s.ubicacionId]?.nombre ??
                                          ''),
                                    if (s.nota != null) Text(s.nota!),
                                    if (s.costo != null)
                                      Text('Costo: ${_money.format(s.costo)}'),
                                    if (s.resueltoPor != null &&
                                        s.fechaResolucion != null)
                                      Text(
                                          'Resuelta por ${_nombre(s.resueltoPor)} · ${_fmt.format(s.fechaResolucion!)}'),
                                  ],
                                ),
                                trailing: acciones.isEmpty
                                    ? null
                                    : PopupMenuButton<String>(
                                        onSelected: (v) => _accion(s, v),
                                        itemBuilder: (_) => acciones,
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
