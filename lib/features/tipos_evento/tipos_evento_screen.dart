import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/tipo_evento.dart';
import '../../core/repositories/tipo_evento_repository.dart';

class TiposEventoScreen extends StatefulWidget {
  const TiposEventoScreen({super.key});

  @override
  State<TiposEventoScreen> createState() => _TiposEventoScreenState();
}

class _TiposEventoScreenState extends State<TiposEventoScreen> {
  final _repo = TipoEventoRepository();
  List<TipoEvento> _tipos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _tipos = await _repo.getAll();
    setState(() => _loading = false);
  }

  Future<void> _delete(TipoEvento tipo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar tipo de evento'),
        content: Text('¿Eliminar "${tipo.nombre}"?'),
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
      await _repo.delete(tipo.id);
      _load();
    }
  }

  Future<void> _toggleActivo(TipoEvento tipo) async {
    await _repo.update(tipo.copyWith(activo: !tipo.activo));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipos de Evento'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('/tipos-evento/nuevo').then((_) => _load()),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tipos.isEmpty
              ? const Center(child: Text('No hay tipos de evento'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tipos.length,
                    itemBuilder: (_, i) {
                      final t = _tipos[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: t.activo
                                ? const Color(0xFFE8F5E9)
                                : Colors.grey[200],
                            child: Icon(Icons.event_note,
                                color: t.activo
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey),
                          ),
                          title: Text(t.nombre,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: t.activo ? null : Colors.grey,
                              )),
                          subtitle: t.descripcion != null
                              ? Text(t.descripcion!)
                              : null,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'editar') {
                                context
                                    .push('/tipos-evento/${t.id}/editar')
                                    .then((_) => _load());
                              } else if (v == 'toggle') {
                                _toggleActivo(t);
                              } else {
                                _delete(t);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(t.activo
                                      ? 'Desactivar'
                                      : 'Activar')),
                              const PopupMenuItem(
                                  value: 'editar', child: Text('Editar')),
                              const PopupMenuItem(
                                  value: 'eliminar',
                                  child: Text('Eliminar',
                                      style:
                                          TextStyle(color: Colors.red))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
