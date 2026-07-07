import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/concepto_financiero.dart';
import '../../core/models/movimiento_financiero.dart';
import '../../core/repositories/concepto_financiero_repository.dart';
import '../../core/repositories/movimiento_financiero_repository.dart';

final _moneyFormat = NumberFormat.currency(locale: 'en_US', symbol: r'$');
final _dateFormat = DateFormat('dd/MM/yyyy');

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({super.key});

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen> {
  final _movimientoRepo = MovimientoFinancieroRepository();
  final _conceptoRepo = ConceptoFinancieroRepository();

  List<MovimientoFinanciero> _movimientos = [];
  Map<String, ConceptoFinanciero> _conceptosPorId = {};
  Map<String, double> _totales = {'ingresos': 0, 'gastos': 0, 'utilidad': 0};
  String _filtroTipo = 'todos';
  DateTimeRange _rango = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final conceptos = await _conceptoRepo.getAll();
    _conceptosPorId = {for (final c in conceptos) c.id: c};
    _movimientos = await _movimientoRepo.getAll(
      tipo: _filtroTipo == 'todos' ? null : _filtroTipo,
      desde: _rango.start,
      hasta: _rango.end,
    );
    _totales = await _movimientoRepo.getTotales(
      desde: _rango.start,
      hasta: _rango.end,
    );
    setState(() => _loading = false);
  }

  Future<void> _elegirRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _rango,
    );
    if (picked != null) {
      setState(() => _rango = picked);
      _load();
    }
  }

  Future<void> _delete(MovimientoFinanciero mov) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text('¿Eliminar este movimiento?'),
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
      await _movimientoRepo.delete(mov.id);
      _load();
    }
  }

  Future<void> _nuevoMovimiento() async {
    final tipo = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.green),
              title: const Text('Ingreso'),
              onTap: () => Navigator.pop(context, 'ingreso'),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Colors.red),
              title: const Text('Gasto'),
              onTap: () => Navigator.pop(context, 'gasto'),
            ),
          ],
        ),
      ),
    );
    if (tipo != null && mounted) {
      context.push('/finanzas/nuevo?tipo=$tipo').then((_) => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Conceptos',
            onPressed: () =>
                context.push('/finanzas/conceptos').then((_) => _load()),
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Rango de fechas',
            onPressed: _elegirRango,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevoMovimiento,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.grey[50],
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_dateFormat.format(_rango.start)} - ${_dateFormat.format(_rango.end)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _TotalCard(
                                label: 'Ingresos',
                                value: _totales['ingresos']!,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TotalCard(
                                label: 'Gastos',
                                value: _totales['gastos']!,
                                color: const Color(0xFFC62828),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TotalCard(
                                label: 'Utilidad',
                                value: _totales['utilidad']!,
                                color: _totales['utilidad']! >= 0
                                    ? const Color(0xFF1565C0)
                                    : const Color(0xFFC62828),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ...['todos', 'ingreso', 'gasto'].map((t) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(t == 'todos'
                                        ? 'Todos'
                                        : t == 'ingreso'
                                            ? 'Ingresos'
                                            : 'Gastos'),
                                    selected: _filtroTipo == t,
                                    onSelected: (_) {
                                      setState(() => _filtroTipo = t);
                                      _load();
                                    },
                                  ),
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _movimientos.isEmpty
                        ? const Center(child: Text('No hay movimientos'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _movimientos.length,
                            itemBuilder: (_, i) {
                              final m = _movimientos[i];
                              final concepto = m.conceptoId != null
                                  ? _conceptosPorId[m.conceptoId]
                                  : null;
                              final esIngreso = m.tipo == 'ingreso';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: esIngreso
                                        ? const Color(0xFFE8F5E9)
                                        : const Color(0xFFFFEBEE),
                                    child: Icon(
                                      esIngreso
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color: esIngreso
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                    ),
                                  ),
                                  title: Text(
                                      concepto?.nombre ?? m.nota ?? 'Sin concepto',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                      '${_dateFormat.format(m.fecha)}'
                                      '${concepto != null && m.nota != null && m.nota!.isNotEmpty ? ' · ${m.nota}' : ''}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${esIngreso ? '+' : '-'}${_moneyFormat.format(m.monto)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: esIngreso
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFFC62828),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'editar') {
                                            context
                                                .push('/finanzas/${m.id}/editar')
                                                .then((_) => _load());
                                          } else {
                                            _delete(m);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                              value: 'editar',
                                              child: Text('Editar')),
                                          const PopupMenuItem(
                                              value: 'eliminar',
                                              child: Text('Eliminar',
                                                  style: TextStyle(
                                                      color: Colors.red))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _TotalCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9))),
            const SizedBox(height: 4),
            Text(
              _moneyFormat.format(value),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
