import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/actividad.dart';
import '../../core/models/perfil_usuario.dart';
import '../../core/models/ubicacion.dart';
import '../../core/providers/permisos_provider.dart';
import '../../core/repositories/actividad_repository.dart';
import '../../core/repositories/perfil_usuario_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auditoria.dart';

final _fmt = DateFormat('dd/MM/yyyy');

Color prioridadColor(String p) {
  switch (p) {
    case 'alta':
      return AppColors.danger;
    case 'media':
      return AppColors.warning;
    default:
      return AppColors.info;
  }
}

class ActividadesScreen extends StatefulWidget {
  const ActividadesScreen({super.key});

  @override
  State<ActividadesScreen> createState() => _ActividadesScreenState();
}

class _ActividadesScreenState extends State<ActividadesScreen> {
  final _repo = ActividadRepository();
  List<Actividad> _actividades = [];
  Map<String, PerfilUsuario> _usuarios = {};
  Map<String, Ubicacion> _ubicaciones = {};
  bool _soloMias = false;
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
    _actividades = await _repo.getAll(
        asignadoA: _soloMias ? usuarioActualId() : null);
    if (mounted) setState(() => _loading = false);
  }

  String _nombre(String? id) {
    if (id == null) return '—';
    final p = _usuarios[id];
    if (p == null) return 'Usuario';
    return p.nombre.isNotEmpty ? p.nombre : p.correo;
  }

  Future<void> _abrirForm([Actividad? a]) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ActividadForm(
        actividad: a,
        usuarios: _usuarios.values.where((u) => u.activo).toList(),
        ubicaciones: _ubicaciones.values.where((u) => u.activa).toList(),
      ),
    );
    if (guardado == true) _load();
  }

  Future<void> _eliminar(Actividad a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text('¿Eliminar "${a.descripcion}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.delete(a.id);
      _load();
    }
  }

  Widget _lista(List<Actividad> lista, {required bool completadas}) {
    final permisos = context.watch<PermisosProvider>();
    final puedeEditar = permisos.puedeEditar('actividades');
    final puedeEliminar = permisos.puedeEliminar('actividades');

    if (lista.isEmpty) {
      return const Center(child: Text('No hay actividades'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: lista.length,
        itemBuilder: (_, i) {
          final a = lista[i];
          final esMia = a.asignadoA == usuarioActualId();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Checkbox(
                value: a.completada,
                onChanged: (esMia || puedeEditar)
                    ? (v) async {
                        if (v == true) {
                          await _repo.marcarCompletada(a.id);
                        } else {
                          await _repo.reabrir(a.id);
                        }
                        _load();
                      }
                    : null,
              ),
              title: Text(a.descripcion,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration:
                        a.completada ? TextDecoration.lineThrough : null,
                  )),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: prioridadColor(a.prioridad).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(kPrioridadLabels[a.prioridad] ?? a.prioridad,
                          style: TextStyle(
                              fontSize: 11,
                              color: prioridadColor(a.prioridad),
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text('Asignado a: ${_nombre(a.asignadoA)}',
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  if (a.fechaLimite != null)
                    Text('Fecha límite: ${_fmt.format(a.fechaLimite!)}',
                        style: TextStyle(
                            color: a.vencida ? AppColors.danger : null)),
                  if (a.ubicacionId != null)
                    Text(_ubicaciones[a.ubicacionId]?.nombre ?? ''),
                  if (completadas && a.fechaCompletada != null)
                    Text(
                        'Completada por ${_nombre(a.completadoPor)} · ${_fmt.format(a.fechaCompletada!)}'),
                ],
              ),
              trailing: (puedeEditar || puedeEliminar)
                  ? PopupMenuButton<String>(
                      onSelected: (v) =>
                          v == 'editar' ? _abrirForm(a) : _eliminar(a),
                      itemBuilder: (_) => [
                        if (puedeEditar)
                          const PopupMenuItem(
                              value: 'editar', child: Text('Editar actividad')),
                        if (puedeEliminar)
                          const PopupMenuItem(
                              value: 'eliminar',
                              child: Text('Eliminar actividad',
                                  style: TextStyle(color: AppColors.danger))),
                      ],
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permisos = context.watch<PermisosProvider>();
    final pendientes = _actividades.where((a) => !a.completada).toList();
    final completadas = _actividades.where((a) => a.completada).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Actividades'),
          actions: [
            TextButton.icon(
              onPressed: () {
                _soloMias = !_soloMias;
                _load();
              },
              icon: Icon(_soloMias ? Icons.person : Icons.groups,
                  color: Colors.white),
              label: Text(_soloMias ? 'Mías' : 'Todas',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Pendientes (${pendientes.length})'),
              Tab(text: 'Completadas (${completadas.length})'),
            ],
          ),
        ),
        floatingActionButton: permisos.puedeCrear('actividades')
            ? FloatingActionButton.extended(
                onPressed: () => _abrirForm(),
                icon: const Icon(Icons.add_task),
                label: const Text('Nueva actividad'),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                _lista(pendientes, completadas: false),
                _lista(completadas, completadas: true),
              ]),
      ),
    );
  }
}

class _ActividadForm extends StatefulWidget {
  final Actividad? actividad;
  final List<PerfilUsuario> usuarios;
  final List<Ubicacion> ubicaciones;

  const _ActividadForm({
    this.actividad,
    required this.usuarios,
    required this.ubicaciones,
  });

  @override
  State<_ActividadForm> createState() => _ActividadFormState();
}

class _ActividadFormState extends State<_ActividadForm> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  String? _asignadoA;
  String _prioridad = 'media';
  DateTime? _fechaLimite;
  String? _ubicacionId;

  @override
  void initState() {
    super.initState();
    final a = widget.actividad;
    if (a != null) {
      _descCtrl.text = a.descripcion;
      _asignadoA = a.asignadoA;
      _prioridad = a.prioridad;
      _fechaLimite = a.fechaLimite;
      _ubicacionId = a.ubicacionId;
    } else {
      _asignadoA = usuarioActualId();
    }
    if (!widget.usuarios.any((u) => u.id == _asignadoA)) {
      _asignadoA = widget.usuarios.isNotEmpty ? widget.usuarios.first.id : null;
    }
    if (!widget.ubicaciones.any((u) => u.id == _ubicacionId)) {
      _ubicacionId = null;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ActividadRepository();
    final a = widget.actividad;
    if (a == null) {
      await repo.create(
        descripcion: _descCtrl.text.trim(),
        asignadoA: _asignadoA!,
        prioridad: _prioridad,
        fechaLimite: _fechaLimite,
        ubicacionId: _ubicacionId,
      );
    } else {
      await repo.update(Actividad(
        id: a.id,
        descripcion: _descCtrl.text.trim(),
        fechaLimite: _fechaLimite,
        ubicacionId: _ubicacionId,
        prioridad: _prioridad,
        estado: a.estado,
        asignadoA: _asignadoA!,
        creadoPor: a.creadoPor,
        completadoPor: a.completadoPor,
        fechaCompletada: a.fechaCompletada,
        createdAt: a.createdAt,
        updatedAt: DateTime.now(),
      ));
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.actividad == null ? 'Nueva actividad' : 'Editar actividad',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                autofocus: widget.actividad == null,
                decoration: const InputDecoration(labelText: 'Actividad *'),
                maxLines: 2,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _asignadoA,
                decoration: const InputDecoration(labelText: 'Asignar a *'),
                items: widget.usuarios
                    .map((u) => DropdownMenuItem(
                        value: u.id,
                        child: Text(u.nombre.isNotEmpty ? u.nombre : u.correo)))
                    .toList(),
                onChanged: (v) => setState(() => _asignadoA = v),
                validator: (v) => v == null ? 'Elige una persona' : null,
              ),
              const SizedBox(height: 12),
              const Text('Prioridad'),
              const SizedBox(height: 4),
              SegmentedButton<String>(
                segments: kPrioridadLabels.entries
                    .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                    .toList(),
                selected: {_prioridad},
                onSelectionChanged: (s) => setState(() => _prioridad = s.first),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _fechaLimite ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (p != null) setState(() => _fechaLimite = p);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha límite (opcional)',
                    suffixIcon: _fechaLimite != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setState(() => _fechaLimite = null))
                        : null,
                  ),
                  child: Text(_fechaLimite != null
                      ? _fmt.format(_fechaLimite!)
                      : 'Sin fecha'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _ubicacionId,
                decoration:
                    const InputDecoration(labelText: 'Ubicación (opcional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Ninguna')),
                  ...widget.ubicaciones.map(
                      (u) => DropdownMenuItem(value: u.id, child: Text(u.nombre))),
                ],
                onChanged: (v) => setState(() => _ubicacionId = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
            ],
          ),
        ),
      ),
    );
  }
}
