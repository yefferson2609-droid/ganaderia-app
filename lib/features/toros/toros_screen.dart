import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/toro.dart';
import '../../core/repositories/toro_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/widgets/grupos_ubicacion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animal_face.dart';

class TorosScreen extends StatefulWidget {
  const TorosScreen({super.key});

  @override
  State<TorosScreen> createState() => _TorosScreenState();
}

class _TorosScreenState extends State<TorosScreen> {
  final _repo = ToroRepository();
  List<Toro> _toros = [];
  Map<String, String> _ubicaciones = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _toros = await _repo.getAll();
    _ubicaciones = {
      for (final u in await UbicacionRepository().getAll()) u.id: u.nombre
    };
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
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
      case 'activo': return AppColors.success;
      case 'vendido': return AppColors.warning;
      case 'fallecido':
      case 'muerto': return AppColors.danger;
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
          : GruposUbicacion<Toro>(
                  clave: 'toros',
                  items: _toros,
                  ubicacionDe: (t) => t.ubicacionId,
                  numeroDe: (t) => t.numero,
                  nombresUbicacion: _ubicaciones,
                  onRefresh: _load,
                  textoVacio: 'No hay toros registrados',
                  itemBuilder: (t) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: AnimalFace(
                              tipo: 'toro',
                              fotoLocal: t.fotoLocal,
                              fotoUrl: t.fotoUrl,
                              estadoColor: _estadoColor(t.estado)),
                          title: Text(t.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '#${t.numero} · ${t.estado[0].toUpperCase()}${t.estado.substring(1)} · ${t.edad}'),
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
                                      style: TextStyle(color: AppColors.danger))),
                            ],
                          ),
                          onTap: () => context
                              .push('/toros/${t.id}')
                              .then((_) => _load()),
                        ),
                      );
                  },
                ),
    );
  }
}
