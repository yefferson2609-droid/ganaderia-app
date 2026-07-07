import 'package:flutter/material.dart';
import '../../core/models/perfil_usuario.dart';
import '../../core/models/permiso_usuario.dart';
import '../../core/repositories/perfil_usuario_repository.dart';
import '../../core/repositories/permiso_usuario_repository.dart';

class UsuarioPermisosScreen extends StatefulWidget {
  final String id;
  const UsuarioPermisosScreen({super.key, required this.id});

  @override
  State<UsuarioPermisosScreen> createState() => _UsuarioPermisosScreenState();
}

class _UsuarioPermisosScreenState extends State<UsuarioPermisosScreen> {
  final _perfilRepo = PerfilUsuarioRepository();
  final _permisoRepo = PermisoUsuarioRepository();

  PerfilUsuario? _perfil;
  Map<String, PermisoUsuario> _permisos = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _perfil = await _perfilRepo.getById(widget.id);
    final lista = await _permisoRepo.getByUsuario(widget.id);
    _permisos = {for (final p in lista) p.modulo: p};
    setState(() => _loading = false);
  }

  Future<void> _toggleActivo(bool value) async {
    if (_perfil == null) return;
    await _perfilRepo.update(_perfil!.copyWith(activo: value));
    setState(() => _perfil = _perfil!.copyWith(activo: value));
  }

  Future<void> _togglePermiso(String modulo, String campo, bool value) async {
    final actual = _permisos[modulo];
    if (actual == null) return;
    final actualizado = actual.copyWith(
      puedeVer: campo == 'ver' ? value : null,
      puedeCrear: campo == 'crear' ? value : null,
      puedeEditar: campo == 'editar' ? value : null,
      puedeEliminar: campo == 'eliminar' ? value : null,
    );
    await _permisoRepo.update(actualizado);
    setState(() => _permisos[modulo] = actualizado);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_perfil == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Usuario')),
        body: const Center(child: Text('Usuario no encontrado')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_perfil!.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Usuario activo'),
              subtitle: Text(_perfil!.correo),
              value: _perfil!.activo,
              onChanged: _toggleActivo,
            ),
          ),
          const SizedBox(height: 16),
          Text('Permisos por módulo',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...kModulos.map((modulo) {
            final permiso = _permisos[modulo];
            if (permiso == null) return const SizedBox.shrink();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(kModuloLabels[modulo] ?? modulo,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        _PermisoCheckbox(
                          label: 'Ver',
                          value: permiso.puedeVer,
                          onChanged: (v) =>
                              _togglePermiso(modulo, 'ver', v),
                        ),
                        _PermisoCheckbox(
                          label: 'Crear',
                          value: permiso.puedeCrear,
                          onChanged: (v) =>
                              _togglePermiso(modulo, 'crear', v),
                        ),
                        _PermisoCheckbox(
                          label: 'Editar',
                          value: permiso.puedeEditar,
                          onChanged: (v) =>
                              _togglePermiso(modulo, 'editar', v),
                        ),
                        _PermisoCheckbox(
                          label: 'Eliminar',
                          value: permiso.puedeEliminar,
                          onChanged: (v) =>
                              _togglePermiso(modulo, 'eliminar', v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PermisoCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermisoCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: value,
      onSelected: onChanged,
      avatar: value ? const Icon(Icons.check, size: 16) : null,
    );
  }
}
