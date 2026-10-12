import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/nomina.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/repositories/nomina_repository.dart';
import '../../core/theme/app_theme.dart';

final _fmt = DateFormat('dd/MM/yyyy');
final _corto = DateFormat('dd/MM');
final money = NumberFormat.currency(locale: 'en_US', symbol: r'$');

/// Nómina de la semana en curso: vista previa, bonos/anticipos y pago.
class NominaScreen extends StatefulWidget {
  const NominaScreen({super.key});

  @override
  State<NominaScreen> createState() => _NominaScreenState();
}

class _NominaScreenState extends State<NominaScreen> {
  final _repo = NominaRepository();
  late DateTime _semana;
  NominaSemana? _estado;
  List<FilaNomina> _filas = [];
  List<NovedadNomina> _novedades = [];
  Map<String, Trabajador> _trabajadores = {};
  List<NominaSemana> _historial = [];
  bool _loading = true;
  bool _pagando = false;

  @override
  void initState() {
    super.initState();
    _semana = semanaFin(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    _estado = await _repo.getSemana(_semana);
    final ts = await _repo.getTrabajadores();
    _trabajadores = {for (final t in ts) t.id: t};
    _novedades = await _repo.getNovedades(_semana);
    _filas = _estado?.pagada == true
        ? await _repo.detalle(_estado!.id)
        : await _repo.calcular(_semana);
    _historial = await _repo.historial();
    if (mounted) setState(() => _loading = false);
  }

  double get _total => _filas.fold(0, (a, f) => a + f.neto);

  Future<void> _agregar(Trabajador t, String tipo) async {
    final montoCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime fecha = DateTime.now();
    final esBono = tipo == 'bono';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('${esBono ? 'Bono / pago extra' : 'Anticipo'} · ${t.nombre}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: montoCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto (USD) *', prefixText: r'$ '),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                  labelText: esBono ? 'Motivo (ej. horas extra)' : 'Nota (opcional)'),
            ),
            if (!esBono) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                      context: ctx,
                      initialDate: fecha,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now());
                  if (p != null) setSt(() => fecha = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha en que se entregó'),
                  child: Text(_fmt.format(fecha)),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Se registra ya como gasto y se descuenta el domingo.',
                  style: TextStyle(fontSize: 12)),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Se suma en la nómina de este domingo.',
                    style: TextStyle(fontSize: 12)),
              ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () {
                  final v = double.tryParse(montoCtrl.text.replaceAll(',', '.'));
                  if (v == null || v <= 0) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.agregarNovedad(
      trabajador: t,
      tipo: tipo,
      monto: double.parse(montoCtrl.text.replaceAll(',', '.')),
      fecha: esBono ? DateTime.now() : fecha,
      descripcion: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
    );
    _load();
  }

  Future<void> _pagar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagar nómina'),
        content: Text(
            'Se registrará un gasto de ${money.format(_total)} en Finanzas '
            '(${_filas.length} trabajadores). Después ya no se puede modificar esta semana.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pagar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _pagando = true);
    final sync = context.read<SyncProvider>();
    try {
      await sync.syncAll(); // que el servidor tenga los últimos bonos/anticipos
      await _repo.pagarAhora(_semana);
      await sync.syncAll(); // trae el detalle y el gasto
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nómina pagada y registrada en Finanzas')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger));
      }
    }
    if (mounted) setState(() => _pagando = false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final pagada = _estado?.pagada == true;
    final hoyDomingo = DateTime.now().weekday == DateTime.sunday;
    final titulo = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nómina'),
        actions: [
          IconButton(
            tooltip: 'Trabajadores',
            icon: const Icon(Icons.badge_outlined),
            onPressed: () =>
                context.push('/nomina/trabajadores').then((_) => _load()),
          ),
        ],
      ),
      floatingActionButton: (!pagada && _filas.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _pagando ? null : _pagar,
              icon: _pagando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.payments),
              label: const Text('Pagar ahora'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Card(
                    color: (pagada ? AppColors.success : AppColors.warning)
                        .withOpacity(0.10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Semana del ${_corto.format(_semana.subtract(const Duration(days: 6)))} '
                              'al domingo ${_fmt.format(_semana)}',
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(money.format(_total),
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(pagada
                              ? '✅ Pagada${_estado!.automatica ? ' automáticamente' : ''}'
                                  '${_estado!.pagadaAt != null ? ' el ${_fmt.format(_estado!.pagadaAt!.toLocal())}' : ''}'
                              : hoyDomingo
                                  ? '⏰ Revísala hoy: si no la pagas, se registra sola a las 11:55 p. m.'
                                  : 'Se registra sola el domingo a las 11:55 p. m. Puedes agregar bonos y anticipos durante la semana.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_trabajadores.isEmpty)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_add),
                        title: const Text('Aún no hay trabajadores'),
                        subtitle: const Text('Agrégalos con su sueldo semanal'),
                        onTap: () => context
                            .push('/nomina/trabajadores')
                            .then((_) => _load()),
                      ),
                    ),
                  ..._filas.map((f) => _filaTrabajador(f, pagada)),
                  if (_historial.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Semanas pagadas', style: titulo),
                    const SizedBox(height: 8),
                    ..._historial.take(12).map((s) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                                s.automatica ? Icons.schedule : Icons.check_circle,
                                color: AppColors.success),
                            title: Text(
                                'Semana al ${_fmt.format(s.semanaFin)}'),
                            subtitle: Text(
                                '${s.trabajadores} trabajadores${s.automatica ? ' · automática' : ''}'),
                            trailing: Text(money.format(s.total),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () => context.push('/nomina/semana/${s.id}'),
                          ),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _filaTrabajador(FilaNomina f, bool pagada) {
    final t = _trabajadores[f.trabajadorId];
    final novs = _novedades.where((n) => n.trabajadorId == f.trabajadorId).toList();
    Widget linea(String label, double v, {Color? color, String signo = ''}) => Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text('$signo${money.format(v)}', style: TextStyle(fontSize: 13, color: color)),
          ],
        );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(f.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Text(money.format(f.neto),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 6),
            linea('Sueldo semanal', f.salario),
            if (f.bonos > 0) linea('Bonos / extras', f.bonos, color: AppColors.success, signo: '+'),
            if (f.anticipos > 0)
              linea('Anticipos', f.anticipos, color: AppColors.danger, signo: '−'),
            if (f.cuotas > 0)
              linea('Cuota de préstamo', f.cuotas, color: AppColors.danger, signo: '−'),
            if (!pagada && novs.isNotEmpty) ...[
              const Divider(),
              ...novs.map((n) => Row(children: [
                    Icon(n.tipo == 'bono' ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        size: 16,
                        color: n.tipo == 'bono' ? AppColors.success : AppColors.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${n.tipo == 'bono' ? 'Bono' : 'Anticipo'} ${money.format(n.monto)}'
                          '${n.descripcion != null ? ' · ${n.descripcion}' : ''}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'Quitar',
                      onPressed: () async {
                        await _repo.eliminarNovedad(n);
                        _load();
                      },
                    ),
                  ])),
            ],
            if (!pagada && t != null)
              Wrap(spacing: 8, children: [
                TextButton.icon(
                  onPressed: () => _agregar(t, 'bono'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Bono'),
                ),
                TextButton.icon(
                  onPressed: () => _agregar(t, 'anticipo'),
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('Anticipo'),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
