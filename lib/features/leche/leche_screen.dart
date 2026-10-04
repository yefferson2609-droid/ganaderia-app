import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/produccion_leche.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/leche_repository.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/vaca_repository.dart';
import '../../core/theme/app_theme.dart';

final _fmt = DateFormat('dd/MM/yyyy');
final _fmtCorto = DateFormat('dd/MM');
final _l = NumberFormat('#,##0.#', 'en_US');

String litros(double v) => '${_l.format(v)} L';

class LecheScreen extends StatefulWidget {
  const LecheScreen({super.key});

  @override
  State<LecheScreen> createState() => _LecheScreenState();
}

class _LecheScreenState extends State<LecheScreen> {
  final _repo = LecheRepository();
  List<LecheDia> _dias = []; // últimos 60 días, del más antiguo al más nuevo
  List<Vaca> _enOrdeno = [];
  Map<String, double> _promVaca = {};
  Map<String, PromediosCiclo> _ciclo = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hoy = DateTime.now();
    _dias = await _repo.diasFinca(hoy.subtract(const Duration(days: 59)), hoy);
    final estados = await ReproduccionRepository().estadosProduccion();
    final vacas = await VacaRepository().getAll(soloActivas: true);
    _enOrdeno = vacas
        .where((v) => estados[v.id] == EstadoProduccion.enOrdeno)
        .toList();
    _promVaca = await _repo.promedioPorVaca();
    _ciclo = await ReproduccionRepository().promediosPorRaza();
    if (mounted) setState(() => _loading = false);
  }

  LecheDia get _hoy => _dias.last;

  double _suma(Iterable<LecheDia> d) => d.fold(0, (a, b) => a + b.total);

  Future<void> _registrar({DateTime? fecha, String? turno}) async {
    final ahora = DateTime.now();
    DateTime f = fecha ?? ahora;
    String t = turno ?? (ahora.hour < 12 ? 'manana' : 'tarde');
    final litrosCtrl = TextEditingController();
    final notasCtrl = TextEditingController();

    Future<void> cargarExistente(StateSetter? setSt) async {
      final e = await _repo.getFinca(f, t);
      litrosCtrl.text = e != null ? _l.format(e.litros) : '';
      notasCtrl.text = e?.notas ?? '';
      setSt?.call(() {});
    }

    await cargarExistente(null);
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Registrar ordeño'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                      context: ctx,
                      initialDate: f,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now());
                  if (p != null) {
                    f = p;
                    await cargarExistente(setSt);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha'),
                  child: Text(_fmt.format(f)),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'manana',
                      label: Text('Mañana'),
                      icon: Icon(Icons.wb_sunny_outlined)),
                  ButtonSegment(
                      value: 'tarde',
                      label: Text('Tarde'),
                      icon: Icon(Icons.nights_stay_outlined)),
                ],
                selected: {t},
                onSelectionChanged: (s) async {
                  t = s.first;
                  await cargarExistente(setSt);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: litrosCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Litros totales *', suffixText: 'L'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notasCtrl,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () {
                  final v = double.tryParse(
                      litrosCtrl.text.replaceAll(',', '.'));
                  if (v == null || v < 0) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.guardarFinca(
      fecha: f,
      turno: t,
      litros: double.parse(litrosCtrl.text.replaceAll(',', '.')),
      notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
    );
    _load();
  }

  Future<void> _registrarPorVaca() async {
    if (_enOrdeno.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No hay vacas en ordeño. Registra sus partos primero.')));
      return;
    }
    final ahora = DateTime.now();
    String t = ahora.hour < 12 ? 'manana' : 'tarde';
    final ctrls = {for (final v in _enOrdeno) v.id: TextEditingController()};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Leche por vaca · ${_fmt.format(ahora)}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'manana', label: Text('Mañana')),
                  ButtonSegment(value: 'tarde', label: Text('Tarde')),
                ],
                selected: {t},
                onSelectionChanged: (s) => setSt(() => t = s.first),
              ),
              const SizedBox(height: 8),
              const Text('Deja vacías las que no pesaste.',
                  style: TextStyle(fontSize: 12)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _enOrdeno
                      .map((v) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextField(
                              controller: ctrls[v.id],
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Vaca #${v.numero}',
                                suffixText: 'L',
                                isDense: true,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    for (final e in ctrls.entries) {
      final v = double.tryParse(e.value.text.replaceAll(',', '.'));
      if (v == null) continue;
      await _repo.guardarVaca(vacaId: e.key, fecha: ahora, turno: t, litros: v);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(title: const Text('Producción de leche')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _registrar(),
        icon: const Icon(Icons.water_drop),
        label: const Text('Registrar ordeño'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _resumenHoy(),
                  const SizedBox(height: 12),
                  _resumenPeriodos(),
                  const SizedBox(height: 16),
                  Text('Últimos 14 días', style: titulo),
                  const SizedBox(height: 8),
                  _grafica(_dias.sublist(_dias.length - 14)),
                  const SizedBox(height: 16),
                  _vacasEnOrdeno(titulo),
                  const SizedBox(height: 16),
                  _promediosCiclo(titulo),
                  const SizedBox(height: 16),
                  Text('Registro diario', style: titulo),
                  const SizedBox(height: 4),
                  ..._dias.reversed.take(30).map((d) => Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          title: Text(_fmt.format(d.fecha),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              'Mañana ${litros(d.manana)} · Tarde ${litros(d.tarde)}'),
                          trailing: Text(litros(d.total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          onTap: () => _registrar(fecha: d.fecha),
                        ),
                      )),
                ],
              ),
            ),
    );
  }

  Widget _resumenHoy() {
    final h = _hoy;
    final porVaca = _enOrdeno.isEmpty ? null : h.total / _enOrdeno.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hoy', style: TextStyle(color: Colors.grey)),
            Text(litros(h.total),
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.info)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _turno('Mañana', h.manana, Icons.wb_sunny_outlined,
                    () => _registrar(fecha: h.fecha, turno: 'manana')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _turno('Tarde', h.tarde, Icons.nights_stay_outlined,
                    () => _registrar(fecha: h.fecha, turno: 'tarde')),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              '${_enOrdeno.length} vaca${_enOrdeno.length == 1 ? '' : 's'} en ordeño'
              '${porVaca != null && h.total > 0 ? ' · ${litros(porVaca)} por vaca' : ''}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _turno(String label, double v, IconData icon, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(10)),
      child: Row(children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text(label)),
        Text(v > 0 ? litros(v) : 'Anotar',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _resumenPeriodos() {
    final hoy = DateTime.now();
    final semana = _dias.where(
        (d) => !d.fecha.isBefore(hoy.subtract(const Duration(days: 6))));
    final mes = _dias.where((d) => d.fecha.month == hoy.month && d.fecha.year == hoy.year);
    final mesAnt = _dias.where((d) =>
        d.fecha.month == DateTime(hoy.year, hoy.month - 1).month &&
        d.fecha.year == DateTime(hoy.year, hoy.month - 1).year);
    int conDatos(Iterable<LecheDia> d) => d.where((x) => x.total > 0).length;
    Widget dato(String label, Iterable<LecheDia> d) {
      final n = conDatos(d);
      final total = _suma(d);
      return Expanded(
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(litros(total),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(n > 0 ? '${litros(total / n)}/día' : '—',
              style: const TextStyle(fontSize: 12)),
        ]),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          dato('7 días', semana),
          dato('Este mes', mes),
          dato('Mes anterior', mesAnt),
        ]),
      ),
    );
  }

  Widget _grafica(List<LecheDia> dias) {
    final max = dias.fold<double>(0, (a, b) => b.total > a ? b.total : a);
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: dias.map((d) {
          final alto = max == 0 ? 0.0 : (d.total / max) * 100;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (d.total > 0)
                    FittedBox(
                      child: Text(_l.format(d.total),
                          style: const TextStyle(fontSize: 9)),
                    ),
                  Container(
                    height: alto,
                    decoration: BoxDecoration(
                      color: AppColors.info,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    child: Text(_fmtCorto.format(d.fecha),
                        style: const TextStyle(fontSize: 9)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _vacasEnOrdeno(TextStyle? titulo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text('Vacas en ordeño (${_enOrdeno.length})',
                      style: titulo)),
              TextButton.icon(
                onPressed: _registrarPorVaca,
                icon: const Icon(Icons.edit_note),
                label: const Text('Leche por vaca'),
              ),
            ]),
            if (_enOrdeno.isEmpty)
              const Text(
                  'Ninguna. Una vaca entra a ordeño al registrar su parto.')
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _enOrdeno.map((v) {
                  final p = _promVaca[v.id];
                  return ActionChip(
                    label: Text('#${v.numero}${p != null ? ' · ${litros(p)}' : ''}'),
                    onPressed: () => context.push('/vacas/${v.id}').then((_) => _load()),
                  );
                }).toList(),
              ),
            if (_promVaca.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Litros = promedio diario de los últimos 30 días',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _promediosCiclo(TextStyle? titulo) {
    final filas = _ciclo.entries.toList()
      ..sort((a, b) => a.key == 'Todas' ? 1 : b.key == 'Todas' ? -1 : a.key.compareTo(b.key));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Promedios del ciclo por raza', style: titulo),
            const SizedBox(height: 4),
            const Text(
                'Calculado con los partos y secados registrados. Se usa para sugerir cuándo secar.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            if (filas.isEmpty)
              const Text('Aún no hay suficientes partos y secados registrados.')
            else
              Table(
                columnWidths: const {0: FlexColumnWidth(1.4)},
                children: [
                  const TableRow(children: [
                    Text('Raza', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('En ordeño', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Seca', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Entre partos', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  ...filas.map((e) {
                    String d(int? v, int n) => v == null ? '—' : '$v d ($n)';
                    final p = e.value;
                    return TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(e.key,
                            style: TextStyle(
                                fontWeight: e.key == 'Todas'
                                    ? FontWeight.bold
                                    : null)),
                      ),
                      Text(d(p.diasLactancia, p.casosLactancia)),
                      Text(d(p.diasSeco, p.casosSeco)),
                      Text(d(p.intervalo, p.casosIntervalo)),
                    ]);
                  }),
                ],
              ),
            if (filas.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('d = días · (n) = casos registrados',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}
