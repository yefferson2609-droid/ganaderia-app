import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/vaca_repository.dart';

class VacasScreen extends StatefulWidget {
  const VacasScreen({super.key});

  @override
  State<VacasScreen> createState() => _VacasScreenState();
}

class _VacasScreenState extends State<VacasScreen> {
  final _repo = VacaRepository();
  List<Vaca> _vacas = [];
  List<Vaca> _filtradas = [];
  bool _loading = true;
  String _filtroEstado = 'todos';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    _filtrar();
    setState(() => _loading = false);
  }

  void _filtrar() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtradas = _vacas.where((v) {
        final matchEstado =
            _filtroEstado == 'todos' || v.estado == _filtroEstado;
        final matchSearch = q.isEmpty || v.numero.toLowerCase().contains(q);
        return matchEstado && matchSearch;
      }).toList();
    });
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'activa':
        return Colors.green;
      case 'vendida':
        return Colors.orange;
      case 'muerta':
        return Colors.red;
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
                children: ['todos', 'activa', 'vendida', 'muerta'].map((e) {
                  final selected = _filtroEstado == e;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(e == 'todos' ? 'Todas' : e[0].toUpperCase() + e.substring(1)),
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
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _estadoColor(vaca.estado).withOpacity(0.2),
                                  child: Text(
                                    vaca.numero.length > 3
                                        ? vaca.numero.substring(0, 3)
                                        : vaca.numero,
                                    style: TextStyle(
                                      color: _estadoColor(vaca.estado),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text('Vaca #${vaca.numero}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    'Estado: ${vaca.estado[0].toUpperCase()}${vaca.estado.substring(1)}'),
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
