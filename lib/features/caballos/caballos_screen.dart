import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/caballo.dart';
import '../../core/repositories/caballo_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animal_face.dart';

Color estadoCaballoColor(String estado) {
  switch (estado) {
    case 'activo': return AppColors.success;
    case 'vendido': return AppColors.warning;
    case 'fallecido':
    case 'muerto': return AppColors.danger;
    default: return Colors.grey;
  }
}

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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
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
                          onTap: () => context
                              .push('/caballos/${c.id}')
                              .then((_) => _load()),
                          leading: AnimalFace(
                              tipo: 'caballo',
                              fotoLocal: c.fotoLocal,
                              fotoUrl: c.fotoUrl,
                              estadoColor: estadoCaballoColor(c.estado)),
                          title: Text(c.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text([
                            c.estado[0].toUpperCase() + c.estado.substring(1),
                            if (c.fechaNacimiento != null) c.edad,
                            if (c.raza != null) c.raza!,
                            if (c.color != null) c.color!,
                          ].join(' · ')),
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
                                      style: TextStyle(color: AppColors.danger))),
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
