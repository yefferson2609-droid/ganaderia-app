import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/tipo_evento.dart';
import '../../core/repositories/caballo_repository.dart';
import '../../core/repositories/evento_masivo_repository.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/ternero_repository.dart';
import '../../core/repositories/tipo_evento_repository.dart';
import '../../core/repositories/toro_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/repositories/vaca_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/grupos_ubicacion.dart' show compararNumero;
import '../terneros/terneros_screen.dart' show nombreJoven;

/// Un animal que se puede elegir en el evento masivo.
class _Animal {
  final String tipo; // 'vaca' | 'ternero' | 'toro' | 'caballo'
  final String id;
  final String titulo;
  final String detalle;
  final String? ubicacionId;
  const _Animal(this.tipo, this.id, this.titulo, this.detalle, this.ubicacionId);
  String get clave => '$tipo:$id';
}

const _pestanas = [
  ('vaca', 'Vacas'),
  ('ternero', 'Levante'),
  ('toro', 'Toros'),
  ('caballo', 'Caballos'),
];

/// Evento masivo: un mismo evento (vacuna, desparasitación, baño…) para
/// muchos animales a la vez, de cualquier tipo, elegidos por potrero.
class EventoMasivoScreen extends StatefulWidget {
  const EventoMasivoScreen({super.key});

  @override
  State<EventoMasivoScreen> createState() => _EventoMasivoScreenState();
}

class _EventoMasivoScreenState extends State<EventoMasivoScreen> {
  List<TipoEvento> _tipos = [];
  final Map<String, List<_Animal>> _animales = {};
  Map<String, String> _ubicaciones = {};
  final Set<String> _sel = {};
  String? _tipoSeleccionado;
  DateTime _fecha = DateTime.now();
  final _notasCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Partos, secados y palpaciones se registran con su propio botón.
    _tipos = (await TipoEventoRepository().getAll(soloActivos: true))
        .where((t) => !esTipoConBotonPropio(t.nombre))
        .toList();
    if (_tipos.isNotEmpty) _tipoSeleccionado = _tipos.first.id;
    _ubicaciones = {
      for (final u in await UbicacionRepository().getAll()) u.id: u.nombre
    };
    // Solo animales activos (los vendidos o fallecidos no se tratan).
    _animales['vaca'] = [
      for (final v in await VacaRepository().getAll())
        if (v.estado == 'activa')
          _Animal('vaca', v.id, 'Vaca #${v.numero}',
              v.prenada ? 'Preñada' : '', v.ubicacionId)
    ];
    _animales['ternero'] = [
      for (final t in await TerneroRepository().getAll(soloActivos: true))
        _Animal('ternero', t.id, nombreJoven(t),
            [t.esMacho ? 'Macho' : 'Hembra', t.edad].join(' · '), t.ubicacionId)
    ];
    _animales['toro'] = [
      for (final t in await ToroRepository().getAll(soloActivos: true))
        _Animal('toro', t.id, 'Toro #${t.numero}', t.nombre, t.ubicacionId)
    ];
    _animales['caballo'] = [
      for (final c in await CaballoRepository().getAll())
        if (c.estado == 'activo')
          _Animal('caballo', c.id, c.nombre, c.raza ?? '', c.ubicacionId)
    ];
    for (final l in _animales.values) {
      l.sort((a, b) => compararNumero(a.titulo.split('#').last,
          b.titulo.split('#').last));
    }
    setState(() => _loadingData = false);
  }

  int _seleccionadosDe(String tipo) =>
      (_animales[tipo] ?? []).where((a) => _sel.contains(a.clave)).length;

  Future<void> _guardar() async {
    if (_tipoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elige el tipo de evento')));
      return;
    }
    if (_sel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elige al menos un animal')));
      return;
    }
    setState(() => _loading = true);
    final todos = _animales.values.expand((l) => l).where((a) => _sel.contains(a.clave));
    await EventoMasivoRepository().registrar(
      tipoEventoId: _tipoSeleccionado!,
      vacaIds: [for (final a in todos) if (a.tipo == 'vaca') a.id],
      otros: [for (final a in todos) if (a.tipo != 'vaca') (a.tipo, a.id)],
      fecha: _fecha,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Evento registrado para ${_sel.length} '
          'animal${_sel.length == 1 ? '' : 'es'}'),
    ));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _pestanas.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Evento masivo'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final (tipo, nombre) in _pestanas)
                Tab(
                    text: _seleccionadosDe(tipo) > 0
                        ? '$nombre (${_seleccionadosDe(tipo)})'
                        : nombre),
            ],
          ),
        ),
        body: _loadingData
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(children: [
                    DropdownButtonFormField<String>(
                      initialValue: _tipoSeleccionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Tipo de evento', isDense: true),
                      items: [
                        for (final t in _tipos)
                          DropdownMenuItem(value: t.id, child: Text(t.nombre))
                      ],
                      onChanged: (v) => setState(() => _tipoSeleccionado = v),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final p = await showDatePicker(
                              context: context,
                              initialDate: _fecha,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (p != null) setState(() => _fecha = p);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'Fecha', isDense: true),
                            child: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _notasCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Notas (producto, dosis…)',
                              isDense: true),
                        ),
                      ),
                    ]),
                  ]),
                ),
                Expanded(
                  child: TabBarView(children: [
                    for (final (tipo, nombre) in _pestanas)
                      _lista(_animales[tipo] ?? [], nombre),
                  ]),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _guardar,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Registrar evento (${_sel.length} '
                                'animal${_sel.length == 1 ? '' : 'es'})'),
                      ),
                    ),
                  ),
                ),
              ]),
      ),
    );
  }

  /// Animales de una pestaña agrupados por potrero, con "marcar todos".
  Widget _lista(List<_Animal> animales, String nombre) {
    if (animales.isEmpty) {
      return Center(child: Text('No hay ${nombre.toLowerCase()} activos'));
    }
    const sinUbicacion = '__sin__';
    final grupos = <String, List<_Animal>>{};
    for (final a in animales) {
      final u = a.ubicacionId != null && _ubicaciones.containsKey(a.ubicacionId)
          ? a.ubicacionId!
          : sinUbicacion;
      grupos.putIfAbsent(u, () => []).add(a);
    }
    final orden = grupos.keys.where((k) => k != sinUbicacion).toList()
      ..sort((a, b) => _ubicaciones[a]!
          .toLowerCase()
          .compareTo(_ubicaciones[b]!.toLowerCase()));
    if (grupos.containsKey(sinUbicacion)) orden.add(sinUbicacion);

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      children: [
        for (final g in orden) ...[
          _cabeceraGrupo(
              g == sinUbicacion ? 'Sin ubicación' : _ubicaciones[g]!, grupos[g]!),
          for (final a in grupos[g]!)
            CheckboxListTile(
              dense: true,
              value: _sel.contains(a.clave),
              onChanged: (v) => setState(
                  () => v == true ? _sel.add(a.clave) : _sel.remove(a.clave)),
              title: Text(a.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: a.detalle.isEmpty ? null : Text(a.detalle),
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ],
    );
  }

  Widget _cabeceraGrupo(String nombre, List<_Animal> lista) {
    final marcados = lista.where((a) => _sel.contains(a.clave)).length;
    final todos = marcados == lista.length;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CheckboxListTile(
        dense: true,
        tristate: true,
        value: todos ? true : (marcados == 0 ? false : null),
        onChanged: (_) => setState(() {
          for (final a in lista) {
            todos ? _sel.remove(a.clave) : _sel.add(a.clave);
          }
        }),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w800)),
        secondary: Text('$marcados / ${lista.length}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
