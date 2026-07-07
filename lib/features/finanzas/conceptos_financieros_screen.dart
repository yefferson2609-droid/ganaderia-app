import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/concepto_financiero.dart';
import '../../core/repositories/concepto_financiero_repository.dart';

class ConceptosFinancierosScreen extends StatefulWidget {
  const ConceptosFinancierosScreen({super.key});

  @override
  State<ConceptosFinancierosScreen> createState() =>
      _ConceptosFinancierosScreenState();
}

class _ConceptosFinancierosScreenState
    extends State<ConceptosFinancierosScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ConceptoFinancieroRepository();
  late final TabController _tabController;
  List<ConceptoFinanciero> _ingresos = [];
  List<ConceptoFinanciero> _gastos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _ingresos = await _repo.getAll(tipo: 'ingreso');
    _gastos = await _repo.getAll(tipo: 'gasto');
    setState(() => _loading = false);
  }

  Future<void> _delete(ConceptoFinanciero concepto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar concepto'),
        content: Text('¿Eliminar "${concepto.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.delete(concepto.id);
      _load();
    }
  }

  Future<void> _toggleActivo(ConceptoFinanciero concepto) async {
    await _repo.update(concepto.copyWith(activo: !concepto.activo));
    _load();
  }

  Widget _buildLista(List<ConceptoFinanciero> conceptos) {
    if (conceptos.isEmpty) {
      return const Center(child: Text('No hay conceptos'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: conceptos.length,
        itemBuilder: (_, i) {
          final c = conceptos[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    c.activo ? const Color(0xFFE8F5E9) : Colors.grey[200],
                child: Icon(
                    c.tipo == 'ingreso'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: c.activo ? const Color(0xFF2E7D32) : Colors.grey),
              ),
              title: Text(c.nombre,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: c.activo ? null : Colors.grey,
                  )),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'editar') {
                    context
                        .push('/finanzas/conceptos/${c.id}/editar')
                        .then((_) => _load());
                  } else if (v == 'toggle') {
                    _toggleActivo(c);
                  } else {
                    _delete(c);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'toggle',
                      child: Text(c.activo ? 'Desactivar' : 'Activar')),
                  const PopupMenuItem(
                      value: 'editar', child: Text('Editar')),
                  const PopupMenuItem(
                      value: 'eliminar',
                      child: Text('Eliminar',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conceptos Financieros'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ingresos'),
            Tab(text: 'Gastos'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context
            .push(
                '/finanzas/conceptos/nuevo?tipo=${_tabController.index == 0 ? 'ingreso' : 'gasto'}')
            .then((_) => _load()),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLista(_ingresos),
                _buildLista(_gastos),
              ],
            ),
    );
  }
}
