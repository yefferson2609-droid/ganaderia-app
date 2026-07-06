import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/toro.dart';
import '../../core/repositories/toro_repository.dart';

class TorosScreen extends StatefulWidget {
  const TorosScreen({super.key});

  @override
  State<TorosScreen> createState() => _TorosScreenState();
}

class _TorosScreenState extends State<TorosScreen> {
  final _repo = ToroRepository();
  List<Toro> _toros = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _toros = await _repo.getAll();
    setState(() => _loading = false);
  }

  Future<void> _delete(Toro toro) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar toro'),
        content: Text('¿Eliminar al toro #${toro.numero} - ${toro.nombre}?'),
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
      await _repo.delete(toro.id);
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
        title: const Text('Toros'),
        leading: BackButton(onPressed: () => context.go('/dashboard')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/toros/nuevo').then((_) => _load()),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _toros.isEmpty
              ? const Center(child: Text('No hay toros registrados'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _toros.length,
                    itemBuilder: (_, i) {
                      final t = _toros[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _estadoColor(t.estado).withValues(alpha: 0.15),
                            child: Text(
                              t.numero.length > 3
                                  ? t.numero.substring(0, 3)
                                  : t.numero,
                              style: TextStyle(
                                color: _estadoColor(t.estado),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          title: Text(t.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '#${t.numero} · ${t.estado[0].toUpperCase()}${t.estado.substring(1)}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'editar') {
                                context
                                    .push('/toros/${t.id}/editar')
                                    .then((_) => _load());
                              } else {
                                _delete(t);
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
