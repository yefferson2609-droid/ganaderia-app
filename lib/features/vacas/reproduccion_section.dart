import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/ternero.dart';
import '../../core/models/vaca.dart';
import '../../core/widgets/descendencia_section.dart';
import '../../core/widgets/grupos_ubicacion.dart' show compararNumero;
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/ternero_repository.dart';
import '../../core/repositories/toro_repository.dart';
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
  List<Pariente> _crias = [];
  Map<String, String> _padres = {}; // id del toro → "#12 - Rey"

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
    final desc = DescendenciaRepository();
    final crias = await desc.hijosDe(widget.vaca.id);
    final padres = <String, String>{};
    for (final c in crias) {
      final p = c.padreId;
      if (p != null && !padres.containsKey(p)) {
        final x = await desc.buscar(p);
        if (x != null) padres[p] = x.nombre.replaceFirst('Toro ', '');
      }
    }
    if (mounted) {
      setState(() {
        _r = r;
        _secado = s;
        _crias = crias;
        _padres = padres;
      });
    }
  }

  /// Crías nacidas a menos de 30 días de ese parto.
  List<Pariente> _criasDe(DateTime parto) => _crias
      .where((c) =>
          c.nacimiento != null &&
          c.nacimiento!.difference(parto).inDays.abs() <= 30)
      .toList();

  String _edad(DateTime n) {
    final dias = DateTime.now().difference(n).inDays;
    final meses = (dias / 30.44).floor();
    if (meses >= 24) return '${meses ~/ 12} años';
    if (meses >= 1) return '$meses ${meses == 1 ? 'mes' : 'meses'}';
    return '$dias días';
  }

  Widget _filaCria(Pariente c) => InkWell(
        onTap: () => context.push(c.ruta).then((_) => widget.onCambio()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 0, 2),
          child: Row(children: [
            Icon(c.macho ? Icons.male : Icons.female,
                size: 18, color: c.macho ? AppColors.info : Colors.pink),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                [
                  c.nombre,
                  if (c.nacimiento != null) _edad(c.nacimiento!),
                  if (c.padreId != null && _padres[c.padreId] != null)
                    'Padre: ${_padres[c.padreId]}',
                  if (c.estado != null) c.estado!,
                ].join(' · '),
                style: const TextStyle(fontSize: 13, color: AppColors.primary),
              ),
            ),
          ]),
        ),
      );

  Future<void> _agregarCria() async {
    final toros = await ToroRepository().getAll(soloActivos: true);
    // Todo Levante y ceba, menos las que ya son crías de esta vaca.
    final sinMadre = (await TerneroRepository().getAll())
        .where((t) => t.madreId != widget.vaca.id)
        .toList()
      ..sort((a, b) => compararNumero(a.numero, b.numero));
    final madres = <String, String>{};
    for (final t in sinMadre) {
      final m = t.madreId;
      if (m != null && !madres.containsKey(m)) {
        madres[m] = (await DescendenciaRepository().buscar(m))?.nombre ?? '';
      }
    }
    if (!mounted) return;

    bool nueva = sinMadre.isEmpty;
    Ternero? existente;
    final numeroCtrl = TextEditingController();
    final mesesCtrl = TextEditingController();
    String sexo = 'macho';
    bool porMeses = true;
    DateTime? fecha;
    String? padreId;
    String? error;

    DateTime? nacimiento() {
      if (!porMeses) return fecha;
      final m = int.tryParse(mesesCtrl.text.trim());
      if (m == null) return null;
      final hoy = DateTime.now();
      final f = hoy.subtract(Duration(days: (m * 30.44).round()));
      return DateTime(f.year, f.month, f.day);
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final n = nacimiento();
          return AlertDialog(
            title: Text('Agregar cría de Vaca #${widget.vaca.numero}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sinMadre.isNotEmpty) ...[
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Ya registrada')),
                        ButtonSegment(value: true, label: Text('Nueva')),
                      ],
                      selected: {nueva},
                      onSelectionChanged: (s) => setSt(() {
                        nueva = s.first;
                        error = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!nueva) ...[
                    LayoutBuilder(
                      builder: (ctx, c) => DropdownMenu<Ternero>(
                        width: c.maxWidth,
                        menuHeight: 300,
                        enableFilter: true,
                        requestFocusOnTap: true,
                        label: const Text('Buscar por número o nombre'),
                        errorText: error,
                        dropdownMenuEntries: [
                          for (final t in sinMadre)
                            DropdownMenuEntry(
                              value: t,
                              label: '${t.esMacho ? '♂' : '♀'} '
                                  '${t.categoriaLabel} #${t.numero}'
                                  '${t.fechaNacimiento != null ? ' · ${t.edad}' : ''}'
                                  '${t.estado != 'activo' ? ' · ${t.estado}' : ''}',
                            ),
                        ],
                        onSelected: (t) => setSt(() {
                          existente = t;
                          error = null;
                          padreId ??= t?.padreId;
                        }),
                      ),
                    ),
                    if (existente?.madreId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Ahora figura como cría de '
                          '${madres[existente!.madreId] ?? 'otra vaca'}. '
                          'Al guardar pasa a ser cría de esta vaca.',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.warning),
                        ),
                      ),
                  ]
                  else ...[
                    TextField(
                      controller: numeroCtrl,
                      decoration: InputDecoration(
                          labelText: 'Número y nombre *',
                          hintText: 'Ej: 7655 bigote',
                          errorText: error),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'macho', label: Text('Macho')),
                        ButtonSegment(value: 'hembra', label: Text('Hembra')),
                      ],
                      selected: {sexo},
                      onSelectionChanged: (s) => setSt(() => sexo = s.first),
                    ),
                  ],
                  if (nueva || existente?.fechaNacimiento == null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Text('Edad: '),
                      ChoiceChip(
                        label: const Text('En meses'),
                        selected: porMeses,
                        onSelected: (_) => setSt(() => porMeses = true),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Fecha'),
                        selected: !porMeses,
                        onSelected: (_) => setSt(() => porMeses = false),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (porMeses)
                      TextField(
                        controller: mesesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Meses de edad',
                          helperText: n != null
                              ? 'Nació aprox. el ${_fmt.format(n)}'
                              : null,
                        ),
                        onChanged: (_) => setSt(() {}),
                      )
                    else
                      InkWell(
                        onTap: () async {
                          final p = await _fecha(ctx, fecha ?? DateTime.now());
                          if (p != null) setSt(() => fecha = p);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'Fecha de nacimiento'),
                          child: Text(
                              fecha != null ? _fmt.format(fecha!) : 'Elegir'),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: padreId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Padre'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('No se sabe')),
                      for (final t in toros)
                        DropdownMenuItem(
                            value: t.id, child: Text('Toro ${t.displayName}')),
                    ],
                    onChanged: (v) => setSt(() => padreId = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (!nueva) {
                    if (existente == null) {
                      setSt(() => error = 'Elige la cría');
                      return;
                    }
                  } else {
                    final num = numeroCtrl.text.trim();
                    if (num.isEmpty) {
                      setSt(() => error = 'Campo requerido');
                      return;
                    }
                    if (await TerneroRepository().existeNumero(num)) {
                      setSt(() => error = 'Ya existe un animal con ese número');
                      return;
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;

    final (_, partoNuevo) = await _repo.agregarCria(
      vaca: widget.vaca,
      existente: nueva ? null : existente,
      numero: nueva ? numeroCtrl.text.trim() : null,
      sexo: nueva ? sexo : null,
      fechaNacimiento: nacimiento(),
      padreId: padreId,
    );
    widget.onCambio();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(partoNuevo
            ? 'Cría agregada. También se registró el parto de la vaca.'
            : 'Cría agregada a la vaca.')));
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
    // Padre: el toro de la monta, si está anotado.
    final toros = await ToroRepository().getAll(soloActivos: true);
    String? padreId = toros.any((t) => t.id == widget.vaca.toroId)
        ? widget.vaca.toroId
        : null;
    if (!mounted) return;

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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: padreId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Padre'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('No se sabe')),
                      for (final t in toros)
                        DropdownMenuItem(
                            value: t.id, child: Text('Toro ${t.displayName}')),
                    ],
                    onChanged: (v) => setSt(() => padreId = v),
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
      padreId: padreId,
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
            if (r.partos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Partos y crías', style: Theme.of(context).textTheme.labelLarge),
              for (var i = r.partos.length - 1; i >= 0; i--) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Parto ${_fmt.format(r.partos[i])}'
                    '${i > 0 ? ' · ${r.intervalos[i - 1]} días desde el anterior' : ''}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                ..._criasDe(r.partos[i]).map(_filaCria),
              ],
            ],
            // Crías sin un parto registrado cerca de su nacimiento.
            if (_crias.any((c) => !r.partos.any((p) =>
                c.nacimiento != null &&
                c.nacimiento!.difference(p).inDays.abs() <= 30))) ...[
              const SizedBox(height: 8),
              Text('Otras crías', style: Theme.of(context).textTheme.labelLarge),
              ..._crias
                  .where((c) => !r.partos.any((p) =>
                      c.nacimiento != null &&
                      c.nacimiento!.difference(p).inDays.abs() <= 30))
                  .map(_filaCria),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: _agregarCria,
                icon: const Icon(Icons.add),
                label: const Text('Agregar cría'),
              ),
            ]),
            if (activa) ...[
              const SizedBox(height: 8),
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
