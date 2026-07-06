import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/ubicacion.dart';
import '../../core/repositories/ubicacion_repository.dart';

class UbicacionesScreen extends StatefulWidget {
  const UbicacionesScreen({super.key});

  @override
  State<UbicacionesScreen> createState() => _UbicacionesScreenState();
}

class _UbicacionesScreenState extends State<UbicacionesScreen> {
  final _repo = UbicacionRepository();
  List<Ubicacion> _ubicaciones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _ubicaciones = await _repo.getAll();
    setState(() => _loading = false);
  }

  Future<void> _delete(Ubicacion ub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ubicación'),
        content: Text('¿Eliminar "${ub.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.delete(ub.id);
      _load();
    }
  }

  Future<void> _mostrarForm({Ubicacion? ub}) async {
    final nombreCtrl = TextEditingController(text: ub?.nombre ?? '');
    final descCtrl = TextEditingController(text: ub?.descripcion ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ub == null ? 'Nueva ubicación' : 'Editar ubicación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre *'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration:
                  const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              if (ub == null) {
                await _repo.create(
                  nombre: nombreCtrl.text.trim(),
                  descripcion: descCtrl.text.isEmpty
                      ? null
                      : descCtrl.text.trim(),
                );
              } else {
                await _repo.update(ub.copyWith(
                  nombre: nombreCtrl.text.trim(),
                  descripcion: descCtrl.text.isEmpty
                      ? null
                      : descCtrl.text.trim(),
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: Text(ub == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicaciones')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ubicaciones.isEmpty
              ? const Center(child: Text('No hay ubicaciones'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ubicaciones.length,
                  itemBuilder: (_, i) {
                    final ub = _ubicaciones[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ub.activa
                              ? const Color(0xFFE8F5E9)
                              : Colors.grey[200],
                          child: Icon(Icons.location_on,
                              color: ub.activa
                                  ? const Color(0xFF2E7D32)
                                  : Colors.grey),
                        ),
                        title: Text(ub.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ub.activa ? null : Colors.grey,
                            )),
                        subtitle: ub.descripcion != null
                            ? Text(ub.descripcion!)
                            : null,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'editar') {
                              _mostrarForm(ub: ub);
                            } else if (v == 'toggle') {
                              _repo.update(ub.copyWith(activa: !ub.activa));
                              _load();
                            } else {
                              _delete(ub);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                    ub.activa ? 'Desactivar' : 'Activar')),
                            const PopupMenuItem(
                                value: 'editar', child: Text('Editar')),
                            const PopupMenuItem(
                                value: 'eliminar',
                                child: Text('Eliminar',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
