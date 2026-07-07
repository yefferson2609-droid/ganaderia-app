import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/toro.dart';
import '../../core/models/ubicacion.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/toro_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/repositories/vaca_repository.dart';

class ToroDetalleScreen extends StatefulWidget {
  final String id;
  const ToroDetalleScreen({super.key, required this.id});

  @override
  State<ToroDetalleScreen> createState() => _ToroDetalleScreenState();
}

class _ToroDetalleScreenState extends State<ToroDetalleScreen> {
  final _toroRepo = ToroRepository();
  final _vacaRepo = VacaRepository();
  final _ubicacionRepo = UbicacionRepository();

  Toro? _toro;
  Toro? _padre;
  Vaca? _madre;
  Ubicacion? _ubicacion;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _toro = await _toroRepo.getById(widget.id);
    if (_toro != null) {
      if (_toro!.padreId != null) {
        _padre = await _toroRepo.getById(_toro!.padreId!);
      }
      if (_toro!.madreId != null) {
        _madre = await _vacaRepo.getById(_toro!.madreId!);
      }
      if (_toro!.ubicacionId != null) {
        _ubicacion = await _ubicacionRepo.getById(_toro!.ubicacionId!);
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _eliminarToro() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar toro'),
        content: const Text('¿Seguro que quieres eliminar este toro?'),
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
      await _toroRepo.delete(widget.id);
      if (mounted) context.pop();
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'activo':
        return Colors.green;
      case 'vendido':
        return Colors.orange;
      case 'muerto':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_toro == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Toro')),
        body: const Center(child: Text('Toro no encontrado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Toro #${_toro!.numero}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/toros/${widget.id}/editar').then((_) => _load()),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _eliminarToro,
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
                    _InfoRow(label: 'Número', value: _toro!.numero),
                    _InfoRow(label: 'Nombre', value: _toro!.nombre),
                    _InfoRow(
                      label: 'Fecha de nacimiento',
                      value: _toro!.fechaNacimiento != null
                          ? DateFormat('dd/MM/yyyy')
                              .format(_toro!.fechaNacimiento!)
                          : 'No registrada',
                    ),
                    _InfoRow(label: 'Edad', value: _toro!.edad),
                    _InfoRow(
                      label: 'Estado',
                      value: _toro!.estado[0].toUpperCase() +
                          _toro!.estado.substring(1),
                      valueColor: _estadoColor(_toro!.estado),
                    ),
                    _InfoRow(
                        label: 'Ubicación',
                        value: _ubicacion?.nombre ?? 'Sin asignar'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Descendencia',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _InfoRow(
                        label: 'Padre',
                        value: _padre != null
                            ? 'Toro #${_padre!.numero} - ${_padre!.nombre}'
                            : 'No registrado'),
                    _InfoRow(
                        label: 'Madre',
                        value: _madre != null
                            ? 'Vaca #${_madre!.numero}'
                            : 'No registrada'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
