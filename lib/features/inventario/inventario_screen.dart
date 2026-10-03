import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/inventario_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/animal_nombre.dart';
import '../../core/widgets/animal_face.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  List<GrupoInventario> _grupos = [];
  bool _loading = true;
  String _buscar = '';
  String? _tipo; // filtro por especie

  static const _tipos = {
    'vaca': 'Vacas',
    'toro': 'Toros',
    'ternero': 'Terneros',
    'caballo': 'Caballos',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _grupos = await InventarioService().generar();
    if (mounted) setState(() => _loading = false);
  }

  bool _coincide(FichaAnimal a) {
    if (_tipo != null && a.tipo != _tipo) return false;
    if (_buscar.isEmpty) return true;
    return a.titulo.toLowerCase().contains(_buscar.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            tooltip: 'Reporte PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => context.push('/reportes'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por número o nombre...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _buscar = v.trim()),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [null, ..._tipos.keys].map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t == null ? 'Todos' : _tipos[t]!),
                            selected: _tipo == t,
                            onSelected: (_) => setState(() => _tipo = t),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_grupos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No hay animales registrados')),
                    ),
                  for (final g in _grupos) ...[
                    const SizedBox(height: 16),
                    Row(children: [
                      Icon(
                          g.ubicacionId == null
                              ? Icons.location_off
                              : Icons.location_on,
                          color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(g.nombre, style: titulo)),
                      Text('${g.total} animales',
                          style: Theme.of(context).textTheme.bodySmall),
                    ]),
                    if (g.cerdos > 0 || g.ovejos > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 30),
                        child: Text([
                          if (g.cerdos > 0) '${g.cerdos} cerdos',
                          if (g.ovejos > 0) '${g.ovejos} ovejos',
                        ].join(' · ')),
                      ),
                    const SizedBox(height: 6),
                    ...g.animales.where(_coincide).map((a) => _FichaCard(
                          ficha: a,
                          onAbrir: () => context
                              .push(rutaAnimal(a.tipo, a.id))
                              .then((_) => _load()),
                        )),
                    if (g.animales.where(_coincide).isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 30, top: 4),
                        child: Text('Sin animales que coincidan',
                            style: TextStyle(color: Colors.grey)),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _FichaCard extends StatelessWidget {
  final FichaAnimal ficha;
  final VoidCallback onAbrir;
  const _FichaCard({required this.ficha, required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).textTheme.labelLarge;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: AnimalFace(
          tipo: ficha.tipo,
          estadoColor: ficha.enTratamiento ? AppColors.danger : null,
        ),
        title: Text(ficha.titulo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(ficha.resumen +
            (ficha.enTratamiento ? ' · En tratamiento' : '')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (k, v) in ficha.datos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 120,
                      child: Text(k,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 13))),
                  Expanded(child: Text(v)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text('Enfermedades y tratamientos', style: sub),
          if (ficha.salud.isEmpty)
            const Text('Sin registros de salud',
                style: TextStyle(color: Colors.grey))
          else
            ...ficha.salud.map((s) => Text('• $s')),
          if (ficha.tipo == 'vaca') ...[
            const SizedBox(height: 8),
            Text('Historial de eventos', style: sub),
            if (ficha.eventos.isEmpty)
              const Text('Sin eventos', style: TextStyle(color: Colors.grey))
            else
              ...ficha.eventos.map((e) => Text('• $e')),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAbrir,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir ficha'),
            ),
          ),
        ],
      ),
    );
  }
}
