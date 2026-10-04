import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/ternero.dart';
import '../../core/repositories/ternero_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animal_face.dart';

Color estadoTerneroColor(String estado) {
  switch (estado) {
    case 'activo':
      return AppColors.success;
    case 'vendido':
      return AppColors.warning;
    case 'fallecido':
      return AppColors.danger;
    default:
      return Colors.grey;
  }
}

/// Nombre corto del animal según su categoría: "Novilla de levante #12".
String nombreJoven(Ternero t) => '${t.categoriaLabel} #${t.numero}';

/// Sección "Levante y ceba": animales desde que nacen hasta pasar a vaca
/// o toro, o venderse.
class TernerosScreen extends StatefulWidget {
  const TernerosScreen({super.key});

  @override
  State<TernerosScreen> createState() => _TernerosScreenState();
}

class _TernerosScreenState extends State<TernerosScreen> {
  final _repo = TerneroRepository();
  List<Ternero> _terneros = [];
  bool _loading = true;
  bool _soloActivos = true;
  String _buscar = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _terneros = await _repo.getAll(soloActivos: _soloActivos);
    setState(() => _loading = false);
  }

  int get _sinClasificar =>
      _terneros.where((t) => t.estado == 'activo' && t.categoria == null).length;

  Future<void> _clasificar() async {
    final n = await _repo.clasificarPendientes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$n animales clasificados. Puedes cambiar cualquiera desde su ficha.')));
    }
    _load();
  }

  List<Ternero> _filtrar(String? categoria) => _terneros
      .where((t) =>
          (categoria == null || t.categoriaActual == categoria) &&
          (_buscar.isEmpty ||
              t.numero.toLowerCase().contains(_buscar.toLowerCase())))
      .toList();

  Widget _lista(List<Ternero> lista) {
    if (lista.isEmpty) {
      return const Center(child: Text('No hay animales en esta categoría'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: lista.length,
        itemBuilder: (_, i) {
          final t = lista[i];
          final avisos = <Widget>[
            if (t.debeDestetarse) _Etiqueta('Por destetar', AppColors.warning),
            if (t.cambioSugerido != null)
              _Etiqueta('Pasar a ${kCategoriaLabels[t.cambioSugerido]}',
                  AppColors.info),
            if (t.categoria == null && t.estado == 'activo')
              _Etiqueta('Sin clasificar', Colors.grey),
          ];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: AnimalFace(
                  tipo: 'ternero',
                  fotoLocal: t.fotoLocal,
                  fotoUrl: t.fotoUrl,
                  estadoColor: estadoTerneroColor(t.estado)),
              title: Text(nombreJoven(t),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text([
                    t.esMacho ? (t.capado ? 'Macho capado' : 'Macho') : 'Hembra',
                    t.edad,
                    if (t.raza != null) t.raza!,
                    if (t.estado != 'activo')
                      t.estado[0].toUpperCase() + t.estado.substring(1),
                  ].join(' · ')),
                  if (avisos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(spacing: 4, runSpacing: 4, children: avisos),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push('/terneros/${t.id}').then((_) => _load()),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pestanas = <String?>[null, ...kCategorias];
    return DefaultTabController(
      length: pestanas.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Levante y ceba'),
          leading: BackButton(onPressed: () => context.go('/dashboard')),
          actions: [
            IconButton(
              tooltip: _soloActivos ? 'Ver también vendidos' : 'Solo activos',
              icon: Icon(_soloActivos ? Icons.filter_alt : Icons.filter_alt_off),
              onPressed: () {
                _soloActivos = !_soloActivos;
                _load();
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: pestanas.map((c) {
              final n = _filtrar(c).length;
              return Tab(
                  text: '${c == null ? 'Todos' : kCategoriaPlural[c]} ($n)');
            }).toList(),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/terneros/nuevo').then((_) => _load()),
          child: const Icon(Icons.add),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por número...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _buscar = v.trim()),
                  ),
                ),
                if (_sinClasificar > 0)
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    color: AppColors.info.withOpacity(0.08),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.category, color: AppColors.info),
                      title: Text('$_sinClasificar animales sin clasificar'),
                      subtitle: const Text(
                          'La app propone la categoría según sexo, edad y si están capados'),
                      trailing: TextButton(
                          onPressed: _clasificar, child: const Text('Clasificar')),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: pestanas.map((c) => _lista(_filtrar(c))).toList(),
                  ),
                ),
              ]),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  const _Etiqueta(this.texto, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
