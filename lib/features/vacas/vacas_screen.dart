import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/vaca_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animal_face.dart';

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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtradas.isEmpty
                    ? const Center(child: Text('No hay vacas registradas'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtradas.length,
                          itemBuilder: (_, i) {
                            final vaca = _filtradas[i];
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
                                    'Estado: ${vaca.estado[0].toUpperCase()}${vaca.estado.substring(1)}'
                                    '${vaca.estadoReproductivo == 'prenada' ? ' · Preñada' : ''}'
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
          ),
        ],
      ),
    );
  }
}
