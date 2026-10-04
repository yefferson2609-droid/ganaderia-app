import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/ternero.dart';
import '../../core/models/toro.dart';
import '../../core/models/ubicacion.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/ternero_repository.dart';
import '../../core/repositories/toro_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/repositories/vaca_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animal_face.dart';
import '../../core/widgets/creador_info.dart';
import '../../core/widgets/salud_section.dart';
import '../../core/widgets/venta_dialog.dart';
import 'terneros_screen.dart';

final _fmt = DateFormat('dd/MM/yyyy');

class TerneroDetalleScreen extends StatefulWidget {
  final String id;
  const TerneroDetalleScreen({super.key, required this.id});

  @override
  State<TerneroDetalleScreen> createState() => _TerneroDetalleScreenState();
}

class _TerneroDetalleScreenState extends State<TerneroDetalleScreen> {
  final _repo = TerneroRepository();

  Ternero? _t;
  Toro? _padre;
  Vaca? _madre;
  List<PesadaTernero> _pesadas = [];
  List<TrasladoTernero> _traslados = [];
  Map<String, Ubicacion> _ubicaciones = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _t = await _repo.getById(widget.id);
    final ubs = await UbicacionRepository().getAll();
    _ubicaciones = {for (final u in ubs) u.id: u};
    if (_t != null) {
      _padre = _t!.padreId != null
          ? await ToroRepository().getById(_t!.padreId!)
          : null;
      _madre = _t!.madreId != null
          ? await VacaRepository().getById(_t!.madreId!)
          : null;
      _pesadas = await _repo.getPesadas(widget.id);
      _traslados = await _repo.getTraslados(widget.id);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _ubic(String? id) =>
      id == null ? 'Sin ubicación' : (_ubicaciones[id]?.nombre ?? '—');

  Future<bool> _confirmar(String titulo, String mensaje) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    return ok == true;
  }

  void _error(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger));

  Future<void> _accion(String v) async {
    final t = _t!;
    switch (v) {
      case 'destete':
        DateTime fecha = DateTime.now();
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setSt) => AlertDialog(
              title: const Text('Registrar destete'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${nombreJoven(t)} se separa de la madre.'),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final p = await showDatePicker(
                        context: ctx,
                        initialDate: fecha,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now());
                    if (p != null) setSt(() => fecha = p);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha de destete'),
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
                    child: const Text('Guardar')),
              ],
            ),
          ),
        );
        if (ok == true) {
          await _repo.registrarDestete(t, fecha);
          _load();
        }
      case 'categoria':
        final opciones = (t.esMacho ? kCategoriasMacho : kCategoriasHembra)
            .where((c) => !(t.capado && (c == 'torete' || c == 'torete_venta')))
            .toList();
        final elegida = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Cambiar categoría'),
            children: opciones
                .map((c) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, c),
                      child: Row(children: [
                        Icon(
                            c == t.categoriaActual
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(kCategoriaLabels[c]!)),
                        if (c == t.categoriaSugerida && c != t.categoriaActual)
                          const Text('sugerida',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.info)),
                      ]),
                    ))
                .toList(),
          ),
        );
        if (elegida != null && elegida != t.categoriaActual) {
          await _repo.cambiarCategoria(t, elegida);
          _load();
        }
      case 'sugerida':
        final s = t.cambioSugerido;
        if (s != null &&
            await _confirmar('Cambiar categoría',
                '¿Pasar a ${kCategoriaLabels[s]}?')) {
          await _repo.cambiarCategoria(t, s);
          _load();
        }
      case 'venta_reproductor':
        await _repo.cambiarCategoria(
            t, t.categoriaActual == 'torete_venta' ? 'torete' : 'torete_venta');
        _load();
      case 'prenada':
        await _marcarPrenada(t);
      case 'capado':
        if (await _confirmar(
            'Marcar como capado', '¿Confirmas que este macho fue capado?')) {
          await _repo.marcarCapado(t);
          _load();
        }
      case 'promover_vaca':
        if (await _confirmar('Promover a Vaca',
            '¿Convertir a ${nombreJoven(t)} en vaca? Pasará a la lista de vacas.')) {
          try {
            final id = await _repo.promoverAVaca(t);
            if (mounted) context.pushReplacement('/vacas/$id');
          } on StateError catch (e) {
            _error(e.message);
          }
        }
      case 'promover_toro':
        await _promoverAToro(t);
      case 'vendido':
        if (mounted &&
            await confirmarVenta(context,
                descripcion: nombreJoven(t),
                ubicacionId: t.ubicacionId)) {
          await _repo.update(t.copyWith(estado: 'vendido'));
          _load();
        }
      case 'fallecido':
        if (mounted &&
            await confirmarFallecimiento(context, nombreJoven(t))) {
          await _repo.update(t.copyWith(estado: 'fallecido'));
          _load();
        }
      case 'activo':
        await _repo.update(t.copyWith(estado: 'activo'));
        _load();
      case 'eliminar':
        if (await _confirmar('Eliminar ternero',
            '¿Seguro? Se eliminarán también sus pesadas y traslados.')) {
          await _repo.delete(t.id);
          if (mounted) context.pop();
        }
    }
  }

  /// Novilla preñada: pasa a Vacas con su fecha estimada de parto.
  Future<void> _marcarPrenada(Ternero t) async {
    int meses = 2;
    DateTime fecha = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Novilla preñada'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${nombreJoven(t)} pasará a la lista de Vacas.'),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Meses de preñez:'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: meses,
                items: List.generate(9,
                    (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                onChanged: (m) => setSt(() => meses = m!),
              ),
            ]),
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
                decoration:
                    const InputDecoration(labelText: 'Fecha del chequeo'),
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
                child: const Text('Pasar a Vacas')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final id = await _repo.promoverAVaca(t,
          prenadaMeses: meses, fechaChequeo: fecha);
      if (mounted) context.pushReplacement('/vacas/$id');
    } on StateError catch (e) {
      _error(e.message);
    }
  }

  Future<void> _promoverAToro(Ternero t) async {
    if (t.capado) {
      _error('Un macho capado no puede promoverse a Toro');
      return;
    }
    final nombreCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promover a Toro'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('¿Convertir a ${nombreJoven(t)} en toro?'),
          const SizedBox(height: 12),
          TextField(
            controller: nombreCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre del toro *'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () {
                if (nombreCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Promover')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final id = await _repo.promoverAToro(t, nombre: nombreCtrl.text.trim());
      if (mounted) context.pushReplacement('/toros/$id');
    } on StateError catch (e) {
      _error(e.message);
    }
  }

  Future<void> _registrarPesada() async {
    final pesoCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    DateTime fecha = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Registrar pesada'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: pesoCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Peso (kg) *'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final p = await showDatePicker(
                    context: ctx,
                    initialDate: fecha,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now());
                if (p != null) setSt(() => fecha = p);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha'),
                child: Text(_fmt.format(fecha)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notasCtrl,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () {
                  final p = double.tryParse(pesoCtrl.text.replaceAll(',', '.'));
                  if (p == null || p <= 0) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.registrarPesada(
      terneroId: widget.id,
      fecha: fecha,
      peso: double.parse(pesoCtrl.text.replaceAll(',', '.')),
      notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
    );
    _load();
  }

  Future<void> _registrarTraslado() async {
    final destinos =
        _ubicaciones.values.where((u) => u.activa && u.id != _t!.ubicacionId).toList();
    if (destinos.isEmpty) {
      _error('No hay otras ubicaciones. Créalas en Ubicaciones.');
      return;
    }
    String destino = destinos.first.id;
    DateTime fecha = DateTime.now();
    final notasCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Registrar traslado'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Origen'),
              child: Text(_ubic(_t!.ubicacionId)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: destino,
              decoration: const InputDecoration(labelText: 'Destino *'),
              items: destinos
                  .map((u) =>
                      DropdownMenuItem(value: u.id, child: Text(u.nombre)))
                  .toList(),
              onChanged: (v) => setSt(() => destino = v!),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final p = await showDatePicker(
                    context: ctx,
                    initialDate: fecha,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now());
                if (p != null) setSt(() => fecha = p);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha'),
                child: Text(_fmt.format(fecha)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notasCtrl,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
          ]),
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
    await _repo.registrarTraslado(
      ternero: _t!,
      destinoId: destino,
      fecha: fecha,
      notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = _t;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Levante y ceba')),
        body: const Center(child: Text('Ternero no encontrado')),
      );
    }
    final titulo = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(
        title: Text(nombreJoven(t)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/terneros/${t.id}/editar').then((_) => _load()),
          ),
          PopupMenuButton<String>(
            onSelected: _accion,
            itemBuilder: (_) => [
              if (t.estado == 'activo' && !t.destetado)
                const PopupMenuItem(
                    value: 'destete', child: Text('Registrar destete')),
              if (t.estado == 'activo' && t.cambioSugerido != null)
                PopupMenuItem(
                    value: 'sugerida',
                    child: Text(
                        'Pasar a ${kCategoriaLabels[t.cambioSugerido]}')),
              if (t.estado == 'activo')
                const PopupMenuItem(
                    value: 'categoria', child: Text('Cambiar categoría')),
              if (t.estado == 'activo' && t.esMacho && !t.capado)
                const PopupMenuItem(
                    value: 'capado', child: Text('Marcar como capado')),
              if (t.estado == 'activo' &&
                  t.esMacho &&
                  !t.capado &&
                  t.destetado)
                PopupMenuItem(
                    value: 'venta_reproductor',
                    child: Text(t.categoriaActual == 'torete_venta'
                        ? 'Quitar de venta como reproductor'
                        : 'Marcar para venta como reproductor')),
              if (t.estado == 'activo' && !t.esMacho)
                const PopupMenuItem(
                    value: 'prenada',
                    child: Text('Quedó preñada → pasar a Vacas')),
              if (t.estado == 'activo' && !t.esMacho)
                const PopupMenuItem(
                    value: 'promover_vaca', child: Text('Promover a Vaca')),
              if (t.estado == 'activo' && t.esMacho && !t.capado)
                const PopupMenuItem(
                    value: 'promover_toro', child: Text('Promover a Toro')),
              if (t.estado == 'activo') ...[
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
                      AnimalFaceEditable(
                          tipo: 'ternero',
                          id: t.id,
                          fotoLocal: t.fotoLocal,
                          fotoUrl: t.fotoUrl,
                          estadoColor: estadoTerneroColor(t.estado),
                          onCambio: _load),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombreJoven(t),
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(
                                '${t.esMacho ? 'Macho' : 'Hembra'}'
                                '${t.capado ? ' · Capado' : ''}'
                                '${t.fechaDestete != null ? ' · Destetado ${_fmt.format(t.fechaDestete!)}' : (t.destetado ? '' : ' · Sin destetar')}'),
                          ],
                        ),
                      ),
                    ]),
                    const Divider(height: 24),
                    _InfoRow('Categoría', t.categoriaLabel,
                        color: t.categoria == null ? Colors.grey : null),
                    if (t.cambioSugerido != null)
                      _InfoRow('Sugerencia',
                          'Pasar a ${kCategoriaLabels[t.cambioSugerido]} (menú ⋮)',
                          color: AppColors.info),
                    _InfoRow(
                        'Destete',
                        t.fechaDestete != null
                            ? _fmt.format(t.fechaDestete!)
                            : (t.destetado
                                ? 'Destetado (sin fecha)'
                                : t.debeDestetarse
                                    ? 'Pendiente · ya cumplió ${t.meses} meses'
                                    : 'Aún no'),
                        color: t.debeDestetarse ? AppColors.warning : null),
                    _InfoRow('Estado',
                        t.estado[0].toUpperCase() + t.estado.substring(1),
                        color: estadoTerneroColor(t.estado)),
                    _InfoRow(
                        'Nacimiento',
                        t.fechaNacimiento != null
                            ? '${_fmt.format(t.fechaNacimiento!)} (${t.edad})'
                            : 'No registrada'),
                    _InfoRow('Ubicación', _ubic(t.ubicacionId)),
                    _InfoRow('Madre',
                        _madre != null ? 'Vaca #${_madre!.numero}' : 'No registrada'),
                    _InfoRow('Padre',
                        _padre != null ? 'Toro ${_padre!.displayName}' : 'No registrado'),
                    _InfoRow('Edad', t.edad),
                    _InfoRow('Raza', t.raza ?? 'Sin registrar'),
                    _InfoRow('Color', t.color ?? 'Sin registrar'),
                    _InfoRow('Notas', t.nota ?? 'Sin notas'),
                    const SizedBox(height: 8),
                    CreadorInfo(
                      createdBy: t.createdBy,
                      updatedBy: t.updatedBy,
                      createdAt: t.createdAt,
                      updatedAt: t.updatedAt,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SaludSection(
                animalTipo: 'ternero',
                animalId: t.id,
                femenino: !t.esMacho),
            const SizedBox(height: 12),
            // Pesadas
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Historial de pesadas', style: titulo)),
                      TextButton.icon(
                        onPressed: _registrarPesada,
                        icon: const Icon(Icons.add),
                        label: const Text('Pesada'),
                      ),
                    ]),
                    if (_pesadas.isEmpty)
                      const Text('Sin pesadas registradas')
                    else
                      ..._pesadas.asMap().entries.map((e) {
                        final p = e.value;
                        final anterior = e.key + 1 < _pesadas.length
                            ? _pesadas[e.key + 1]
                            : null;
                        String? ganancia;
                        if (anterior != null) {
                          final dias =
                              p.fecha.difference(anterior.fecha).inDays;
                          final dif = p.peso - anterior.peso;
                          ganancia =
                              '${dif >= 0 ? '+' : ''}${dif.toStringAsFixed(1)} kg'
                              '${dias > 0 ? ' (${(dif / dias * 1000).toStringAsFixed(0)} g/día)' : ''}';
                        }
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.monitor_weight_outlined),
                          title: Text('${p.peso.toStringAsFixed(1)} kg'),
                          subtitle: Text([
                            _fmt.format(p.fecha),
                            if (ganancia != null) ganancia,
                            if (p.notas != null) p.notas!,
                          ].join(' · ')),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: AppColors.danger),
                            onPressed: () async {
                              if (await _confirmar('Eliminar pesada',
                                  '¿Eliminar esta pesada?')) {
                                await _repo.deletePesada(p.id);
                                _load();
                              }
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Traslados
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Historial de traslados', style: titulo)),
                      TextButton.icon(
                        onPressed: _registrarTraslado,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Traslado'),
                      ),
                    ]),
                    if (_traslados.isEmpty)
                      const Text('Sin traslados registrados')
                    else
                      ..._traslados.map((tr) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.local_shipping_outlined),
                            title: Text(
                                '${_ubic(tr.ubicacionOrigenId)} → ${_ubic(tr.ubicacionDestinoId)}'),
                            subtitle: Text([
                              _fmt.format(tr.fecha),
                              if (tr.notas != null) tr.notas!,
                            ].join(' · ')),
                          )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _InfoRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontWeight: FontWeight.w500, color: color)),
          ),
        ],
      ),
    );
  }
}
