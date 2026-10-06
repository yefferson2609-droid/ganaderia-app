import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/widgets/grupos_ubicacion.dart';
import '../../core/repositories/vaca_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animal_face.dart';
import 'partos_faltantes.dart';

const _filtroLabels = {
  'todos': 'Todas',
  'activa': 'Activas',
  'ordeno': 'En ordeño',
  'seca': 'Secas',
  'prenada': 'Preñadas',
  'vendida': 'Vendidas',
  'fallecida': 'Fallecidas',
};

class VacasScreen extends StatefulWidget {
  /// Filtro inicial, p. ej. 'ordeno' desde el panel principal.
  final String? filtro;
  const VacasScreen({super.key, this.filtro});

  @override
  State<VacasScreen> createState() => _VacasScreenState();
}

class _VacasScreenState extends State<VacasScreen> {
  final _repo = VacaRepository();
  List<Vaca> _vacas = [];
  List<Vaca> _filtradas = [];
  Map<String, EstadoProduccion> _produccion = {};
  Map<String, String> _ubicaciones = {};
  List<PartoFaltante> _faltantes = [];
  bool _loading = true;
  String _filtroEstado = 'todos';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_filtroLabels.containsKey(widget.filtro)) _filtroEstado = widget.filtro!;
    _load();
    _searchCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _vacas = await _repo.getAll();
    _produccion = await ReproduccionRepository().estadosProduccion();
    _faltantes = await ReproduccionRepository().partosFaltantes();
    _ubicaciones = {
      for (final u in await UbicacionRepository().getAll()) u.id: u.nombre
    };
    _filtrar();
    setState(() => _loading = false);
  }

  bool _cumple(Vaca v, [String? filtro]) {
    final f = filtro ?? _filtroEstado;
    switch (f) {
      case 'todos':
        return true;
      case 'ordeno':
        return _produccion[v.id] == EstadoProduccion.enOrdeno;
      case 'seca':
        return _produccion[v.id] == EstadoProduccion.seca;
      case 'prenada':
        return v.estado == 'activa' && v.estadoReproductivo == 'prenada';
      default:
        return v.estado == f;
    }
  }

  void _filtrar() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtradas = _vacas.where((v) {
        final matchEstado = _cumple(v);
        final matchSearch = q.isEmpty || v.numero.toLowerCase().contains(q);
        return matchEstado && matchSearch;
      }).toList();
    });
  }

  /// "Preñada 4 m · Parto 12/02/2027".
  String _prenez(Vaca v) {
    final d = v.diasGestacion;
    final parto = v.fechaPartoProbable;
    return [
      'Preñada${d != null && d >= 0 ? ' ${d ~/ 30} m' : ''}',
      if (parto != null) 'Parto ${DateFormat('dd/MM/yyyy').format(parto)}',
    ].join(' · ');
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'activa':
        return AppColors.success;
      case 'vendida':
        return AppColors.warning;
      case 'fallecida':
      case 'muerta':
        return AppColors.danger;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vacas'),
        leading: BackButton(onPressed: () => context.go('/dashboard')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('/vacas/nueva').then((_) => _load()),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Buscar por número...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filtroLabels.keys.map((e) {
                  final selected = _filtroEstado == e;
                  final n = _vacas.isEmpty
                      ? null
                      : _vacas.where((v) => _cumple(v, e)).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${_filtroLabels[e]}${n != null ? ' ($n)' : ''}'),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _filtroEstado = e);
                        _filtrar();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (_faltantes.isNotEmpty)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              color: AppColors.warning.withValues(alpha: 0.1),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.child_friendly,
                    color: AppColors.warning),
                title: Text(
                    '${_faltantes.length} cría${_faltantes.length == 1 ? '' : 's'} '
                    'sin parto registrado en su madre'),
                subtitle: const Text('Toca para revisar antes de registrar'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  if (await revisarPartosFaltantes(context, _faltantes)) {
                    _load();
                  }
                },
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : GruposUbicacion<Vaca>(
                    clave: 'vacas',
                    items: _filtradas,
                    ubicacionDe: (v) => v.ubicacionId,
                    numeroDe: (v) => v.numero,
                    nombresUbicacion: _ubicaciones,
                    onRefresh: _load,
                    textoVacio: 'No hay vacas en este filtro',
                    itemBuilder: (vaca) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: AnimalFace(
                                    tipo: 'vaca',
                                    fotoLocal: vaca.fotoLocal,
                                    fotoUrl: vaca.fotoUrl,
                                    estadoColor: _estadoColor(vaca.estado)),
                                title: Text('Vaca #${vaca.numero}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    '${vaca.estado == 'activa' && _produccion[vaca.id] != null ? kEstadoProduccionLabels[_produccion[vaca.id]]! : vaca.estado[0].toUpperCase() + vaca.estado.substring(1)}'
                                    '${vaca.prenada ? ' · ${_prenez(vaca)}' : ''}'
                                    '${vaca.fechaNacimiento != null ? ' · ${vaca.edad}' : ''}'
                                    '${vaca.color != null ? ' · ${vaca.color}' : ''}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context
                                    .push('/vacas/${vaca.id}')
                                    .then((_) => _load()),
                              ),
                            );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
