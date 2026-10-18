import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/concepto_financiero.dart';
import '../../core/repositories/concepto_financiero_repository.dart';
import '../../core/theme/app_theme.dart';

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
  bool _verArchivados = false;

  int get _archivados =>
      [..._ingresos, ..._gastos].where((c) => !c.activo).length;

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

  Widget _buildLista(List<ConceptoFinanciero> todos) {
    // Activos arriba; los finalizados (archivados) solo si se piden.
    final conceptos = [
      ...todos.where((c) => c.activo),
      if (_verArchivados) ...todos.where((c) => !c.activo),
    ];
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
                    c.activo ? AppColors.primaryContainer : Colors.grey[200],
                child: Icon(
                    c.tipo == 'ingreso'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: c.activo ? AppColors.primary : AppColors.textoSuave),
              ),
              title: Text(c.nombre,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: c.activo ? null : AppColors.textoSuave,
                  )),
              subtitle: c.activo
                  ? null
                  : const Text('Finalizado (archivado)'),
              trailing: const Icon(Icons.edit, color: AppColors.primary),
              onTap: () => context
                  .push('/finanzas/conceptos/${c.id}/editar')
                  .then((_) => _load()),
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
        actions: [
          if (_archivados > 0)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => setState(() => _verArchivados = !_verArchivados),
              icon: Icon(_verArchivados
                  ? Icons.visibility_off_outlined
                  : Icons.inventory_2_outlined),
              label: Text(_verArchivados
                  ? 'Ocultar archivados'
                  : 'Archivados ($_archivados)'),
            ),
        ],
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
