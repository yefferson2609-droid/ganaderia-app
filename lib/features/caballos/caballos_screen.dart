import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/caballo.dart';
import '../../core/repositories/caballo_repository.dart';

class CaballosScreen extends StatefulWidget {
  const CaballosScreen({super.key});

  @override
  State<CaballosScreen> createState() => _CaballosScreenState();
}

class _CaballosScreenState extends State<CaballosScreen> {
  final _repo = CaballoRepository();
  List<Caballo> _caballos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _caballos = await _repo.getAll();
    setState(() => _loading = false);
  }

  Future<void> _delete(Caballo caballo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar caballo'),
        content: Text('¿Eliminar a ${caballo.nombre}?'),
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
      await _repo.delete(caballo.id);
      _load();
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'activo': return Colors.green;
      case 'vendido': return Colors.orange;
      case 'muerto': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caballos'),
        leading: BackButton(onPressed: () => context.go('/dashboard')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/caballos/nuevo').then((_) => _load()),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _caballos.isEmpty
              ? const Center(child: Text('No hay caballos registrados'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _caballos.length,
                    itemBuilder: (_, i) {
                      final c = _caballos[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _estadoColor(c.estado).withOpacity(0.15),
                            child: Icon(Icons.directions_run,
                                color: _estadoColor(c.estado)),
                          ),
                          title: Text(c.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Estado: ${c.estado[0].toUpperCase()}${c.estado.substring(1)}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'editar') {
                                context
                                    .push('/caballos/${c.id}/editar')
                                    .then((_) => _load());
                              } else {
                                _delete(c);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'editar', child: Text('Editar')),
                              PopupMenuItem(
                                  value: 'eliminar',
                                  child: Text('Eliminar',
                                      style: TextStyle(color: Colors.red))),
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
