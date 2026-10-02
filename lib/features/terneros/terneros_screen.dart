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

  Widget _lista(List<Ternero> lista) {
    if (lista.isEmpty) {
      return const Center(child: Text('Sin terneros en esta etapa'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lista.length,
        itemBuilder: (_, i) {
          final t = lista[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: AnimalFace(
                  tipo: 'ternero', estadoColor: estadoTerneroColor(t.estado)),
              title: Text('Ternero #${t.numero}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text([
                t.esMacho ? 'Macho' : 'Hembra',
                if (t.capado) 'Capado',
                t.etapaLabel,
                t.edad,
                if (t.estado != 'activo')
                  t.estado[0].toUpperCase() + t.estado.substring(1),
              ].join(' · ')),
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
    return DefaultTabController(
      length: kEtapasTernero.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Terneros'),
          leading: BackButton(onPressed: () => context.go('/dashboard')),
          actions: [
            IconButton(
              tooltip: _soloActivos ? 'Ver todos' : 'Solo activos',
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
            tabs: [
              const Tab(text: 'Todos'),
              ...kEtapasTernero.map((e) => Tab(text: kEtapaLabels[e])),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () =>
              context.push('/terneros/nuevo').then((_) => _load()),
          child: const Icon(Icons.add),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _terneros.isEmpty
                ? const Center(child: Text('No hay terneros registrados'))
                : TabBarView(children: [
                    _lista(_terneros),
                    ...kEtapasTernero.map((e) =>
                        _lista(_terneros.where((t) => t.etapa == e).toList())),
                  ]),
      ),
    );
  }
}
