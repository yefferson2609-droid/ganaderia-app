import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/vaca.dart';
import '../../core/models/ternero.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/ternero_repository.dart';
import '../../core/repositories/vaca_repository.dart';
import '../../core/theme/app_theme.dart';

final _fmt = DateFormat('dd/MM/yyyy');

/// Resultado elegido para una vaca en la visita.
class _Resultado {
  bool? prenada; // null = no se palpó
  int meses = 3;
}

/// Visita del veterinario: marcar de una vez qué vacas están preñadas
/// (y de cuántos meses) y cuáles vacías.
class PalpacionScreen extends StatefulWidget {
  const PalpacionScreen({super.key});

  @override
  State<PalpacionScreen> createState() => _PalpacionScreenState();
}

class _PalpacionScreenState extends State<PalpacionScreen> {
  List<Vaca> _vacas = [];
  List<Ternero> _novillas = [];
  final Map<String, _Resultado> _res = {};
  DateTime _fecha = DateTime.now();
  final _notasCtrl = TextEditingController();
  String _buscar = '';
  bool _loading = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _vacas = await VacaRepository().getAll(soloActivas: true);
    for (final v in _vacas) {
      _res[v.id] = _Resultado();
    }
    // Novillas destetadas: si quedan preñadas pasan a Vacas.
    _novillas = (await TerneroRepository().getAll(soloActivos: true))
        .where((t) =>
            t.categoriaActual == 'novilla_levante' ||
            t.categoriaActual == 'novilla_vientre')
        .toList();
    for (final t in _novillas) {
      _res[t.id] = _Resultado();
    }
    if (mounted) setState(() => _loading = false);
  }

  int get _marcadas => _res.values.where((r) => r.prenada != null).length;

  Future<void> _guardar() async {
    if (_marcadas == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Marca al menos una vaca como preñada o vacía')));
      return;
    }
    setState(() => _guardando = true);
    final repo = ReproduccionRepository();
    final notas = _notasCtrl.text.trim();
    var prenadas = 0;
    for (final v in _vacas) {
      final r = _res[v.id]!;
      if (r.prenada == null) continue;
      if (r.prenada!) prenadas++;
      await repo.registrarPalpacion(
        vaca: v,
        fecha: _fecha,
        prenada: r.prenada!,
        meses: r.prenada! ? r.meses : null,
        notas: notas.isEmpty ? null : notas,
      );
    }
    var aVacas = 0;
    for (final t in _novillas) {
      final r = _res[t.id]!;
      if (r.prenada != true) continue; // vacía: sigue como novilla
      prenadas++;
      aVacas++;
      await TerneroRepository().promoverAVaca(t,
          prenadaMeses: r.meses,
          fechaChequeo: _fecha,
          notas: notas.isEmpty ? null : notas);
    }
    if (!mounted) return;
    if (aVacas > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '$aVacas novilla${aVacas == 1 ? '' : 's'} preñada${aVacas == 1 ? '' : 's'} pasaron a Vacas')));
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Palpación guardada: $prenadas preñadas, ${_marcadas - prenadas} vacías')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    bool coincide(String numero) =>
        _buscar.isEmpty || numero.toLowerCase().contains(_buscar.toLowerCase());
    final visibles = _vacas.where((v) => coincide(v.numero)).toList();
    final novillasVisibles =
        _novillas.where((t) => coincide(t.numero)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Palpación (veterinario)')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: const Icon(Icons.save),
            label: Text('Guardar resultados ($_marcadas)'),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                InkWell(
                  onTap: () async {
                    final p = await showDatePicker(
                        context: context,
                        initialDate: _fecha,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (p != null) setState(() => _fecha = p);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Fecha de la visita',
                        prefixIcon: Icon(Icons.calendar_today)),
                    child: Text(_fmt.format(_fecha)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notasCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Veterinario / notas (opcional)',
                      prefixIcon: Icon(Icons.medical_services_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                      hintText: 'Buscar vaca por número...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true),
                  onChanged: (v) => setState(() => _buscar = v.trim()),
                ),
                const SizedBox(height: 8),
                const Text(
                    'Marca solo las vacas que revisó. Las que dejes sin marcar no cambian.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                ...visibles.map((v) => _fila(v)),
                if (novillasVisibles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Novillas',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...novillasVisibles.map(_filaNovilla),
                ],
              ],
            ),
    );
  }

  Widget _fila(Vaca v) => _filaAnimal(
        id: v.id,
        titulo: 'Vaca #${v.numero}',
        actual: v.estadoReproductivo == 'prenada'
            ? 'Hoy figura: preñada${v.fechaEstimadaParto != null ? ' · parto ${_fmt.format(v.fechaEstimadaParto!)}' : ''}'
            : 'Hoy figura: vacía',
      );

  Widget _filaNovilla(Ternero t) => _filaAnimal(
        id: t.id,
        titulo: '${t.categoriaLabel} #${t.numero}',
        actual: '${t.edad} · si está preñada pasa a Vacas',
      );

  Widget _filaAnimal(
      {required String id, required String titulo, required String actual}) {
    final r = _res[id]!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: r.prenada == null
          ? null
          : (r.prenada! ? AppColors.success : AppColors.warning)
              .withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(actual, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              SegmentedButton<bool?>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: null, label: Text('—')),
                  ButtonSegment(value: false, label: Text('Vacía')),
                  ButtonSegment(value: true, label: Text('Preñada')),
                ],
                selected: {r.prenada},
                onSelectionChanged: (s) => setState(() => r.prenada = s.first),
              ),
            ]),
            if (r.prenada == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Text('Meses de preñez:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: r.meses,
                    items: List.generate(
                        9,
                        (i) => DropdownMenuItem(
                            value: i + 1, child: Text('${i + 1}'))),
                    onChanged: (m) => setState(() => r.meses = m!),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Parto ≈ ${_fmt.format(_fecha.subtract(Duration(days: (r.meses * 30.4).round())).add(const Duration(days: 283)))}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
