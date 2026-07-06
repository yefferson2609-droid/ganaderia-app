import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/evento_vaca.dart';
import '../../core/models/tipo_evento.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/evento_vaca_repository.dart';
import '../../core/repositories/tipo_evento_repository.dart';
import '../../core/repositories/vaca_repository.dart';

class VacaDetalleScreen extends StatefulWidget {
  final String id;
  const VacaDetalleScreen({super.key, required this.id});

  @override
  State<VacaDetalleScreen> createState() => _VacaDetalleScreenState();
}

class _VacaDetalleScreenState extends State<VacaDetalleScreen> {
  final _vacaRepo = VacaRepository();
  final _eventoRepo = EventoVacaRepository();
  final _tipoRepo = TipoEventoRepository();

  Vaca? _vaca;
  Vaca? _padre;
  Vaca? _madre;
  List<EventoVaca> _eventos = [];
  List<TipoEvento> _tipos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _vaca = await _vacaRepo.getById(widget.id);
    if (_vaca != null) {
      if (_vaca!.padreId != null) _padre = await _vacaRepo.getById(_vaca!.padreId!);
      if (_vaca!.madreId != null) _madre = await _vacaRepo.getById(_vaca!.madreId!);
      _eventos = await _eventoRepo.getByVaca(widget.id);
    }
    _tipos = await _tipoRepo.getAll(soloActivos: true);
    setState(() => _loading = false);
  }

  Future<void> _agregarEvento() async {
    if (_tipos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura tipos de evento primero')),
      );
      return;
    }

    String? tipoSeleccionado = _tipos.first.id;
    DateTime fechaSeleccionada = DateTime.now();
    final notasCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Registrar evento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tipoSeleccionado,
                  decoration:
                      const InputDecoration(labelText: 'Tipo de evento'),
                  items: _tipos
                      .map((t) =>
                          DropdownMenuItem(value: t.id, child: Text(t.nombre)))
                      .toList(),
                  onChanged: (v) => setSt(() => tipoSeleccionado = v),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: fechaSeleccionada,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSt(() => fechaSeleccionada = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha'),
                    child: Text(
                        DateFormat('dd/MM/yyyy').format(fechaSeleccionada)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                await _eventoRepo.create(
                  vacaId: widget.id,
                  tipoEventoId: tipoSeleccionado!,
                  fecha: fechaSeleccionada,
                  notas: notasCtrl.text.isEmpty ? null : notasCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarEvento(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: const Text('¿Seguro que quieres eliminar este evento?'),
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
      await _eventoRepo.delete(id);
      _load();
    }
  }

  Future<void> _eliminarVaca() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar vaca'),
        content: const Text(
            '¿Seguro? Se eliminarán también todos sus eventos registrados.'),
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
      await _vacaRepo.delete(widget.id);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_vaca == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vaca')),
        body: const Center(child: Text('Vaca no encontrada')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Vaca #${_vaca!.numero}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/vacas/${widget.id}/editar').then((_) => _load()),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _eliminarVaca,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarEvento,
        icon: const Icon(Icons.add),
        label: const Text('Evento'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info básica
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: 'Número', value: _vaca!.numero),
                    _InfoRow(
                      label: 'Fecha de nacimiento',
                      value: _vaca!.fechaNacimiento != null
                          ? DateFormat('dd/MM/yyyy')
                              .format(_vaca!.fechaNacimiento!)
                          : 'No registrada',
                    ),
                    _InfoRow(
                      label: 'Estado',
                      value: _vaca!.estado[0].toUpperCase() +
                          _vaca!.estado.substring(1),
                      valueColor: _estadoColor(_vaca!.estado),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Descendencia
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
                            ? 'Vaca #${_padre!.numero}'
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
            const SizedBox(height: 12),
            // Historial
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Historial de eventos',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text('${_eventos.length} registros',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            if (_eventos.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Sin eventos registrados')),
                ),
              )
            else
              ..._eventos.map((e) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Icon(Icons.event_note, color: Color(0xFF2E7D32)),
                      ),
                      title: Text(e.tipoEventoNombre ?? 'Evento'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(e.fecha)),
                          if (e.notas != null && e.notas!.isNotEmpty)
                            Text(e.notas!,
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _eliminarEvento(e.id),
                      ),
                      isThreeLine: e.notas != null && e.notas!.isNotEmpty,
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'activa':
        return Colors.green;
      case 'vendida':
        return Colors.orange;
      case 'muerta':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
