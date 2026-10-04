import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/caballo.dart';
import '../../core/repositories/caballo_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animal_face.dart';
import '../../core/widgets/creador_info.dart';
import '../../core/widgets/dato_fila.dart';
import '../../core/widgets/salud_section.dart';
import '../../core/widgets/venta_dialog.dart';
import 'caballos_screen.dart';

class CaballoDetalleScreen extends StatefulWidget {
  final String id;
  const CaballoDetalleScreen({super.key, required this.id});

  @override
  State<CaballoDetalleScreen> createState() => _CaballoDetalleScreenState();
}

class _CaballoDetalleScreenState extends State<CaballoDetalleScreen> {
  final _repo = CaballoRepository();
  Caballo? _c;
  String? _ubicacion;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _c = await _repo.getById(widget.id);
    _ubicacion = _c?.ubicacionId != null
        ? (await UbicacionRepository().getById(_c!.ubicacionId!))?.nombre
        : null;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _accion(String v) async {
    final c = _c!;
    switch (v) {
      case 'vendido':
        if (await confirmarVenta(context,
            descripcion: 'Caballo ${c.nombre}', ubicacionId: c.ubicacionId)) {
          await _repo.update(c.copyWith(estado: 'vendido'));
          _load();
        }
      case 'fallecido':
        if (await confirmarFallecimiento(context, 'a ${c.nombre}')) {
          await _repo.update(c.copyWith(estado: 'fallecido'));
          _load();
        }
      case 'activo':
        await _repo.update(c.copyWith(estado: 'activo'));
        _load();
      case 'eliminar':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar caballo'),
            content: Text('¿Eliminar a ${c.nombre}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await _repo.delete(c.id);
          if (mounted) context.pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final c = _c;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Caballo')),
        body: const Center(child: Text('Caballo no encontrado')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(c.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/caballos/${c.id}/editar').then((_) => _load()),
          ),
          PopupMenuButton<String>(
            onSelected: _accion,
            itemBuilder: (_) => [
              if (c.estado == 'activo') ...[
                const PopupMenuItem(
                    value: 'vendido', child: Text('Marcar como vendido')),
                const PopupMenuItem(
                    value: 'fallecido', child: Text('Marcar como fallecido')),
              ] else
                const PopupMenuItem(
                    value: 'activo', child: Text('Volver a activo')),
              const PopupMenuItem(
                  value: 'eliminar',
                  child: Text('Eliminar',
                      style: TextStyle(color: AppColors.danger))),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      AnimalFace(
                          tipo: 'caballo',
                          size: 56,
                          estadoColor: estadoCaballoColor(c.estado)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.nombre,
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(
                                c.estado[0].toUpperCase() + c.estado.substring(1),
                                style: TextStyle(
                                    color: estadoCaballoColor(c.estado),
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ]),
                    const Divider(height: 24),
                    DatoFila('Edad', c.edad),
                    DatoFila(
                        'Nacimiento',
                        c.fechaNacimiento != null
                            ? DateFormat('dd/MM/yyyy').format(c.fechaNacimiento!)
                            : 'No registrada'),
                    DatoFila('Color', c.color ?? 'Sin registrar'),
                    DatoFila('Ubicación', _ubicacion ?? 'Sin ubicación'),
                    DatoFila('Notas', c.nota ?? 'Sin notas'),
                    const SizedBox(height: 8),
                    CreadorInfo(
                      createdBy: c.createdBy,
                      updatedBy: c.updatedBy,
                      createdAt: c.createdAt,
                      updatedAt: c.updatedAt,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SaludSection(animalTipo: 'caballo', animalId: c.id),
          ],
        ),
      ),
    );
  }
}
