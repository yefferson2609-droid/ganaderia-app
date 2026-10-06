import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/ternero_repository.dart';
import '../../core/theme/app_theme.dart';

final _fmt = DateFormat('dd/MM/yyyy');

Color estadoProduccionColor(EstadoProduccion e) {
  switch (e) {
    case EstadoProduccion.enOrdeno:
      return AppColors.info;
    case EstadoProduccion.seca:
      return AppColors.warning;
    case EstadoProduccion.sinPartos:
      return Colors.grey;
  }
}

/// Partos, intervalos entre partos, ordeño/seca y última vitamina.
class ReproduccionSection extends StatefulWidget {
  final Vaca vaca;
  final VoidCallback onCambio;

  /// false = sin tarjeta ni título (dentro de un cuadro plegable).
  final bool marco;

  const ReproduccionSection(
      {super.key,
      required this.vaca,
      required this.onCambio,
      this.marco = true});

  @override
  State<ReproduccionSection> createState() => _ReproduccionSectionState();
}

class _ReproduccionSectionState extends State<ReproduccionSection> {
  final _repo = ReproduccionRepository();
  ResumenReproductivo? _r;
  SugerenciaSecado? _secado;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReproduccionSection old) {
    super.didUpdateWidget(old);
    if (old.vaca.updatedAt != widget.vaca.updatedAt) _load();
  }

  Future<void> _load() async {
    final r = await _repo.resumen(widget.vaca.id);
    final s = await _repo.sugerenciaSecado(widget.vaca);
    if (mounted) {
      setState(() {
        _r = r;
        _secado = s;
      });
    }
  }

  Future<DateTime?> _fecha(BuildContext ctx, DateTime inicial) => showDatePicker(
        context: ctx,
        initialDate: inicial,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );

  Future<void> _registrarParto() async {
    DateTime fecha = DateTime.now();
    final notasCtrl = TextEditingController();
    final numeroCtrl = TextEditingController();
    bool conTernero = true;
    String sexo = 'hembra';
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Parto de Vaca #${widget.vaca.numero}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    final p = await _fecha(ctx, fecha);
                    if (p != null) setSt(() => fecha = p);
                  },
                  child: InputDecorator(
                    decoration:
                        const InputDecoration(labelText: 'Fecha del parto'),
                    child: Text(_fmt.format(fecha)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notasCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Notas (opcional)'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: conTernero,
                  onChanged: (v) => setSt(() => conTernero = v!),
                  title: const Text('Registrar el ternero'),
                ),
                if (conTernero) ...[
                  TextField(
                    controller: numeroCtrl,
                    decoration: InputDecoration(
                        labelText: 'Número del ternero *', errorText: error),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'hembra', label: Text('Hembra')),
                      ButtonSegment(value: 'macho', label: Text('Macho')),
                    ],
                    selected: {sexo},
                    onSelectionChanged: (s) => setSt(() => sexo = s.first),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (conTernero) {
                  final n = numeroCtrl.text.trim();
                  if (n.isEmpty) {
                    setSt(() => error = 'Campo requerido');
                    return;
                  }
                  if (await TerneroRepository().existeNumero(n)) {
                    setSt(() => error = 'Ya existe un ternero con ese número');
                    return;
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final terneroId = await _repo.registrarParto(
      vaca: widget.vaca,
      fecha: fecha,
      notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
      numeroTernero: conTernero ? numeroCtrl.text.trim() : null,
      sexoTernero: conTernero ? sexo : null,
    );
    widget.onCambio();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Parto registrado. La vaca pasa a ordeño.'),
      action: terneroId != null
          ? SnackBarAction(
              label: 'Ver ternero',
              onPressed: () => context.push('/terneros/$terneroId'))
          : null,
    ));
  }

  Future<void> _secar() async {
    DateTime fecha = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Secar vaca'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('La Vaca #${widget.vaca.numero} dejará de contarse en ordeño.'),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final p = await _fecha(ctx, fecha);
                if (p != null) setSt(() => fecha = p);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha de secado'),
                child: Text(_fmt.format(fecha)),
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Secar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.secar(vacaId: widget.vaca.id, fecha: fecha);
    widget.onCambio();
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    if (r == null) return const SizedBox.shrink();
    final estado = r.estado;
    final color = estadoProduccionColor(estado);
    final titulo = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);
    final activa = widget.vaca.estado == 'activa';

    return _marco(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.marco) Row(children: [
              Expanded(child: Text('Partos y ordeño', style: titulo)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  kEstadoProduccionLabels[estado]! +
                      (r.diasEnLeche != null ? ' · ${r.diasEnLeche} días' : ''),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            _fila('Partos registrados', '${r.partos.length}'),
            if (r.ultimoParto != null)
              _fila(
                  estado == EstadoProduccion.enOrdeno
                      ? 'Entró a ordeño'
                      : 'Último parto',
                  _fmt.format(r.ultimoParto!)),
            if (_secado != null) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secar sugerido: ${_fmt.format(_secado!.fecha)}'
                      '${_secado!.fecha.isBefore(DateTime.now()) && estado == EstadoProduccion.enOrdeno ? ' (¡ya toca!)' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_secado!.diasDescanso} días de descanso antes del parto '
                      '(${_fmt.format(widget.vaca.fechaEstimadaParto!)}) · '
                      'según ${_secado!.fuente}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (r.intervaloPromedio != null)
              _fila('Intervalo promedio', '${r.intervaloPromedio} días'
                  ' (${(r.intervaloPromedio! / 30.4).toStringAsFixed(1)} meses)'),
            if (estado == EstadoProduccion.seca && r.ultimoSecado != null)
              _fila('Seca desde', _fmt.format(r.ultimoSecado!)),
            _fila(
                'Última vitamina',
                r.ultimaVitamina != null
                    ? '${_fmt.format(r.ultimaVitamina!)} (${r.ultimaVitaminaNombre})'
                        ' · hace ${DateTime.now().difference(r.ultimaVitamina!).inDays} días'
                    : 'Sin registro'),
            if (r.partos.length > 1) ...[
              const SizedBox(height: 8),
              Text('Intervalos entre partos',
                  style: Theme.of(context).textTheme.labelLarge),
              for (var i = r.partos.length - 1; i >= 1; i--)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${_fmt.format(r.partos[i - 1])} → ${_fmt.format(r.partos[i])}: '
                    '${r.intervalos[i - 1]} días',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
            if (activa) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ElevatedButton.icon(
                  onPressed: _registrarParto,
                  icon: const Icon(Icons.child_friendly),
                  label: const Text('Registrar parto'),
                ),
                if (estado == EstadoProduccion.enOrdeno)
                  OutlinedButton.icon(
                    onPressed: _secar,
                    icon: const Icon(Icons.water_drop_outlined),
                    label: const Text('Secar vaca'),
                  ),
              ]),
            ],
          ],
        ));
  }

  Widget _marco(Widget w) => widget.marco
      ? Card(child: Padding(padding: const EdgeInsets.all(16), child: w))
      : w;

  Widget _fila(String label, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 130,
                child: Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 13))),
            Expanded(
                child: Text(valor,
                    style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
      );
}
