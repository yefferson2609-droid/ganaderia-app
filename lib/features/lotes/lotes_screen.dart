import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/lote.dart';
import '../../core/repositories/lote_repository.dart';

class LotesScreen extends StatefulWidget {
  const LotesScreen({super.key});

  @override
  State<LotesScreen> createState() => _LotesScreenState();
}

class _LotesScreenState extends State<LotesScreen>
    with SingleTickerProviderStateMixin {
  final _repo = LoteRepository();
  List<Lote> _cerdos = [];
  List<Lote> _ovejos = [];
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _cerdos = await _repo.getAll(tipo: 'cerdo');
    _ovejos = await _repo.getAll(tipo: 'ovejo');
    setState(() => _loading = false);
  }

  Future<void> _delete(Lote lote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar lote'),
        content: Text('¿Eliminar el lote "${lote.nombre}"?'),
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
      await _repo.delete(lote.id);
      _load();
    }
  }

  Widget _buildLista(List<Lote> lotes, String tipo) {
    if (lotes.isEmpty) {
      return Center(
          child: Text('No hay lotes de ${tipo == 'cerdo' ? 'cerdos' : 'ovejos'}'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lotes.length,
      itemBuilder: (_, i) {
        final l = lotes[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: tipo == 'cerdo'
                  ? const Color(0xFFE65100).withOpacity(0.15)
                  : const Color(0xFF1565C0).withOpacity(0.15),
              child: Icon(
                tipo == 'cerdo' ? Icons.set_meal : Icons.filter_vintage,
                color: tipo == 'cerdo'
                    ? const Color(0xFFE65100)
                    : const Color(0xFF1565C0),
              ),
            ),
            title: Text(l.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Total: ${l.total}  •  ♀ ${l.hembras}  •  ♂ ${l.machos}'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'ver') {
                  context.push('/lotes/${l.id}').then((_) => _load());
                } else if (v == 'editar') {
                  context.push('/lotes/${l.id}/editar').then((_) => _load());
                } else {
                  _delete(l);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'ver', child: Text('Ver detalle')),
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(
                    value: 'eliminar',
                    child:
                        Text('Eliminar', style: TextStyle(color: Colors.red))),
              ],
            ),
            onTap: () =>
                context.push('/lotes/${l.id}').then((_) => _load()),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes'),
        leading: BackButton(onPressed: () => context.go('/dashboard')),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Cerdos'),
            Tab(text: 'Ovejos'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/lotes/nuevo').then((_) => _load()),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildLista(_cerdos, 'cerdo'),
                  _buildLista(_ovejos, 'ovejo'),
                ],
              ),
            ),
    );
  }
}
