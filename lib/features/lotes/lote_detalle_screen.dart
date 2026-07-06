import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/lote.dart';
import '../../core/models/movimiento_lote.dart';
import '../../core/repositories/lote_repository.dart';

class LoteDetalleScreen extends StatefulWidget {
  final String id;
  const LoteDetalleScreen({super.key, required this.id});

  @override
  State<LoteDetalleScreen> createState() => _LoteDetalleScreenState();
}

class _LoteDetalleScreenState extends State<LoteDetalleScreen> {
  final _repo = LoteRepository();
  Lote? _lote;
  List<MovimientoLote> _movimientos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _lote = await _repo.getById(widget.id);
    _movimientos = await _repo.getMovimientos(widget.id);
    setState(() => _loading = false);
  }

  Future<void> _registrarBaja() async {
    String tipoMovimiento = 'muerte';
    String sexo = 'hembra';
    final cantCtrl = TextEditingController(text: '1');
    DateTime fecha = DateTime.now();
    final notasCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Registrar baja'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tipoMovimiento,
                  decoration:
                      const InputDecoration(labelText: 'Tipo de baja'),
                  items: const [
                    DropdownMenuItem(value: 'muerte', child: Text('Muerte')),
                    DropdownMenuItem(value: 'venta', child: Text('Venta')),
                  ],
                  onChanged: (v) => setSt(() => tipoMovimiento = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: sexo,
                  decoration: const InputDecoration(labelText: 'Sexo'),
                  items: const [
                    DropdownMenuItem(value: 'hembra', child: Text('Hembra ♀')),
                    DropdownMenuItem(value: 'macho', child: Text('Macho ♂')),
                  ],
                  onChanged: (v) => setSt(() => sexo = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cantCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: fecha,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSt(() => fecha = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha'),
                    child:
                        Text(DateFormat('dd/MM/yyyy').format(fecha)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notasCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Notas (opcional)'),
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
                final cant = int.tryParse(cantCtrl.text) ?? 1;
                await _repo.registrarBaja(
                  loteId: widget.id,
                  tipoMovimiento: tipoMovimiento,
                  cantidad: cant,
                  sexo: sexo,
                  fecha: fecha,
                  notas: notasCtrl.text.isEmpty ? null : notasCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_lote == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lote')),
        body: const Center(child: Text('Lote no encontrado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_lote!.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/lotes/${widget.id}/editar').then((_) => _load()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registrarBaja,
        icon: const Icon(Icons.remove_circle_outline),
        label: const Text('Registrar baja'),
        backgroundColor: Colors.red[700],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Resumen del lote
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _lote!.tipo == 'cerdo' ? 'Lote de Cerdos' : 'Lote de Ovejos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _CountChip(
                            label: 'Total',
                            count: _lote!.total,
                            color: Colors.green),
                        _CountChip(
                            label: 'Hembras ♀',
                            count: _lote!.hembras,
                            color: Colors.pink),
                        _CountChip(
                            label: 'Machos ♂',
                            count: _lote!.machos,
                            color: Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Historial de bajas',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text('${_movimientos.length} registros',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            if (_movimientos.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Sin bajas registradas')),
                ),
              )
            else
              ..._movimientos.map((m) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: m.tipoMovimiento == 'muerte'
                            ? Colors.red.withOpacity(0.15)
                            : Colors.orange.withOpacity(0.15),
                        child: Icon(
                          m.tipoMovimiento == 'muerte'
                              ? Icons.close
                              : Icons.sell_outlined,
                          color: m.tipoMovimiento == 'muerte'
                              ? Colors.red
                              : Colors.orange,
                        ),
                      ),
                      title: Text(
                          '${m.tipoMovimiento[0].toUpperCase()}${m.tipoMovimiento.substring(1)} — ${m.cantidad} ${m.sexo == 'hembra' ? '♀' : '♂'}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(m.fecha)),
                          if (m.notas != null && m.notas!.isNotEmpty)
                            Text(m.notas!,
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic)),
                        ],
                      ),
                      isThreeLine: m.notas != null && m.notas!.isNotEmpty,
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
