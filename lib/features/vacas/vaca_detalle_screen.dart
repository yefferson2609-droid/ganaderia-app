import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/evento_vaca.dart';
import '../../core/models/tipo_evento.dart';
import '../../core/models/toro.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/evento_vaca_repository.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/tipo_evento_repository.dart';
import '../../core/repositories/toro_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/repositories/vaca_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animal_face.dart';
import '../../core/widgets/creador_info.dart';
import '../../core/widgets/pesajes_section.dart';
import '../../core/widgets/salud_section.dart';
import '../../core/widgets/venta_dialog.dart';
import 'reproduccion_section.dart';

class VacaDetalleScreen extends StatefulWidget {
  final String id;
  const VacaDetalleScreen({super.key, required this.id});

  @override
  State<VacaDetalleScreen> createState() => _VacaDetalleScreenState();
}

class _VacaDetalleScreenState extends State<VacaDetalleScreen> {
  final _vacaRepo = VacaRepository();
  final _toroRepo = ToroRepository();
  final _eventoRepo = EventoVacaRepository();
  final _tipoRepo = TipoEventoRepository();

  Vaca? _vaca;
  Toro? _padre;
  Vaca? _madre;
  String? _ubicacion;
  ResumenReproductivo? _resumen;
  List<EventoVaca> _eventos = [];
  List<TipoEvento> _tipos = [];
  bool _loading = true;
  int _version = 0; // fuerza recargar las secciones tras un cambio

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _vaca = await _vacaRepo.getById(widget.id);
    if (_vaca != null) {
      if (_vaca!.padreId != null) _padre = await _toroRepo.getById(_vaca!.padreId!);
      if (_vaca!.madreId != null) _madre = await _vacaRepo.getById(_vaca!.madreId!);
      _eventos = await _eventoRepo.getByVaca(widget.id);
      _ubicacion = _vaca!.ubicacionId != null
          ? (await UbicacionRepository().getById(_vaca!.ubicacionId!))?.nombre
          : null;
      _resumen = await ReproduccionRepository().resumen(widget.id);
    }
    _tipos = await _tipoRepo.getAll(soloActivos: true);
    setState(() => _loading = false);
  }

  Future<void> _agregarEvento() async {
    if (_tipos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura tipos de evento primero')),
      );
      return;
    }

    String? tipoSeleccionado = _tipos.first.id;
    DateTime fechaSeleccionada = DateTime.now();
    final notasCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Registrar evento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tipoSeleccionado,
                  decoration:
                      const InputDecoration(labelText: 'Tipo de evento'),
                  items: _tipos
                      .map((t) =>
                          DropdownMenuItem(value: t.id, child: Text(t.nombre)))
                      .toList(),
                  onChanged: (v) => setSt(() => tipoSeleccionado = v),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: fechaSeleccionada,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSt(() => fechaSeleccionada = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha'),
                    child: Text(
                        DateFormat('dd/MM/yyyy').format(fechaSeleccionada)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                await _eventoRepo.create(
                  vacaId: widget.id,
                  tipoEventoId: tipoSeleccionado!,
                  fecha: fechaSeleccionada,
                  notas: notasCtrl.text.isEmpty ? null : notasCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarEvento(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: const Text('¿Seguro que quieres eliminar este evento?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _eventoRepo.delete(id);
      _load();
    }
  }

  Future<void> _eliminarVaca() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar vaca'),
        content: const Text(
            '¿Seguro? Se eliminarán también todos sus eventos registrados.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _vacaRepo.delete(widget.id);
      if (mounted) context.pop();
    }
  }

  Future<void> _accion(String v) async {
    final vaca = _vaca!;
    switch (v) {
      case 'vendida':
        if (await confirmarVenta(context,
            descripcion: 'Vaca #${vaca.numero}', ubicacionId: vaca.ubicacionId)) {
          await _vacaRepo.update(vaca.copyWith(estado: 'vendida'));
          _load();
        }
      case 'fallecida':
        if (await confirmarFallecimiento(context, 'la vaca #${vaca.numero}')) {
          await _vacaRepo.update(vaca.copyWith(estado: 'fallecida'));
          _load();
        }
      case 'activa':
        await _vacaRepo.update(vaca.copyWith(estado: 'activa'));
        _load();
      case 'eliminar':
        await _eliminarVaca();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _vaca == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_vaca == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vaca')),
        body: const Center(child: Text('Vaca no encontrada')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Vaca #${_vaca!.numero}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/vacas/${widget.id}/editar').then((_) => _load()),
          ),
          PopupMenuButton<String>(
            onSelected: _accion,
            itemBuilder: (_) => [
              if (_vaca!.estado == 'activa') ...[
                const PopupMenuItem(
                    value: 'vendida', child: Text('Marcar como vendida')),
                const PopupMenuItem(
                    value: 'fallecida', child: Text('Marcar como fallecida')),
              ] else
                const PopupMenuItem(
                    value: 'activa', child: Text('Volver a activa')),
              const PopupMenuItem(
                  value: 'eliminar',
                  child: Text('Eliminar vaca',
                      style: TextStyle(color: AppColors.danger))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarEvento,
        icon: const Icon(Icons.add),
        label: const Text('Evento'),
      ),
      body: DefaultTabController(
        length: 5,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: _resumenCard()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PestanasDelegate(
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    const Tab(text: 'Datos'),
                    Tab(text: 'Partos (${_resumen?.partos.length ?? 0})'),
                    const Tab(text: 'Salud'),
                    const Tab(text: 'Pesos'),
                    Tab(text: 'Historial (${_eventos.length})'),
                  ],
                ),
                Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ],
          body: TabBarView(children: [
            _pestana([
              _Plegable(
                titulo: 'Información',
                icono: Icons.info_outline,
                abierto: true,
                children: [
                  _InfoRow(label: 'Número', value: _vaca!.numero),
                  _InfoRow(
                    label: 'Fecha de nacimiento',
                    value: _vaca!.fechaNacimiento != null
                        ? DateFormat('dd/MM/yyyy').format(_vaca!.fechaNacimiento!)
                        : 'No registrada',
                  ),
                  _InfoRow(
                    label: 'Estado',
                    value: _vaca!.estado[0].toUpperCase() +
                        _vaca!.estado.substring(1),
                    valueColor: _estadoColor(_vaca!.estado),
                  ),
                  _InfoRow(label: 'Raza', value: _vaca!.raza ?? 'Sin registrar'),
                  _InfoRow(label: 'Color', value: _vaca!.color ?? 'Sin registrar'),
                  _InfoRow(label: 'Ubicación', value: _ubicacion ?? 'Sin ubicación'),
                  _InfoRow(label: 'Notas', value: _vaca!.nota ?? 'Sin notas'),
                  const SizedBox(height: 8),
                  CreadorInfo(
                    createdBy: _vaca!.createdBy,
                    updatedBy: _vaca!.updatedBy,
                    createdAt: _vaca!.createdAt,
                    updatedAt: _vaca!.updatedAt,
                  ),
                ],
              ),
              _Plegable(
                titulo: 'Descendencia',
                icono: Icons.account_tree_outlined,
                children: [
                  _InfoRow(
                      label: 'Padre',
                      value: _padre != null
                          ? 'Toro #${_padre!.numero} - ${_padre!.nombre}'
                          : 'No registrado'),
                  _InfoRow(
                      label: 'Madre',
                      value: _madre != null
                          ? 'Vaca #${_madre!.numero}'
                          : 'No registrada'),
                ],
              ),
            ]),
            _pestana([
              ReproduccionSection(
                key: ValueKey('repro$_version'),
                vaca: _vaca!,
                onCambio: () {
                  _version++;
                  _load();
                },
              ),
            ]),
            _pestana([
              SaludSection(
                  animalTipo: 'vaca', animalId: widget.id, femenino: true),
            ]),
            _pestana([
              PesajesSection(animalTipo: 'vaca', animalId: widget.id),
            ]),
            _pestana([
              if (_eventos.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Sin eventos registrados')),
                  ),
                )
              else
                ..._eventos.map((e) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primaryContainer,
                          child: Icon(Icons.event_note, color: AppColors.primary),
                        ),
                        title: Text(e.tipoEventoNombre ?? 'Evento'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(e.fecha)),
                            if (e.notas != null && e.notas!.isNotEmpty)
                              Text(e.notas!,
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.danger, size: 20),
                          onPressed: () => _eliminarEvento(e.id),
                        ),
                        isThreeLine: e.notas != null && e.notas!.isNotEmpty,
                      ),
                    )),
            ]),
          ]),
        ),
      ),
    );
  }

  /// Contenido de una pestaña, con espacio abajo para el botón "Evento".
  Widget _pestana(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: children,
      );

  /// Resumen de arriba: foto, edad, partos, ordeño y preñez.
  Widget _resumenCard() {
    final v = _vaca!;
    final r = _resumen;
    final fmt = DateFormat('dd/MM/yyyy');
    final estadoProd = r?.estado;
    final chips = <Widget>[
      if (v.estado != 'activa')
        _Chip(v.estado[0].toUpperCase() + v.estado.substring(1),
            _estadoColor(v.estado))
      else if (estadoProd != null)
        _Chip(
            kEstadoProduccionLabels[estadoProd]! +
                (r!.diasEnLeche != null ? ' · ${r.diasEnLeche} días' : ''),
            estadoProduccionColor(estadoProd)),
    ];

    // Preñez o días vacía.
    Widget? prenez;
    if (v.estado == 'activa' && v.prenada) {
      final parto = v.fechaPartoProbable;
      final faltan = v.diasParaParto;
      prenez = _Destacado(
        color: AppColors.success,
        icono: Icons.pregnant_woman,
        lineas: [
          'Preñada${v.gestacionTexto != null ? ' · ${v.gestacionTexto}' : ''}',
          if (parto != null)
            'Parto posible: ${fmt.format(parto)}'
                '${faltan == null ? '' : faltan > 0 ? ' (faltan $faltan días)' : faltan == 0 ? ' (hoy)' : ' (pasó hace ${-faltan} días)'}'
          else
            'Sin fecha de monta ni de parto registrada',
        ],
      );
    } else if (v.estado == 'activa') {
      final ultimo = r?.ultimoParto;
      prenez = _Destacado(
        color: AppColors.warning,
        icono: Icons.event_busy,
        lineas: [
          ultimo != null
              ? 'Vacía · ${DateTime.now().difference(ultimo).inDays} días desde el parto'
              : 'Vacía',
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              AnimalFaceEditable(
                  tipo: 'vaca',
                  id: v.id,
                  fotoLocal: v.fotoLocal,
                  fotoUrl: v.fotoUrl,
                  estadoColor: _estadoColor(v.estado),
                  onCambio: _load),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vaca #${v.numero}',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      [
                        v.fechaNacimiento != null ? v.edad : 'Edad sin registrar',
                        '${r?.partos.length ?? 0} parto${(r?.partos.length ?? 0) == 1 ? '' : 's'}',
                      ].join(' · '),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: chips),
                    ],
                  ],
                ),
              ),
            ]),
            if (prenez != null) ...[
              const SizedBox(height: 12),
              prenez,
            ],
          ],
        ),
      ),
    );
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
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuadro que se abre o cierra tocando su título.
class _Plegable extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final bool abierto;
  final List<Widget> children;
  const _Plegable(
      {required this.titulo,
      required this.icono,
      this.abierto = false,
      required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: abierto,
        shape: const Border(),
        leading: Icon(icono, color: AppColors.primary),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final Color color;
  const _Chip(this.texto, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(texto,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      );
}

/// Recuadro de color con la preñez o los días vacía.
class _Destacado extends StatelessWidget {
  final Color color;
  final IconData icono;
  final List<String> lineas;
  const _Destacado(
      {required this.color, required this.icono, required this.lineas});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lineas.length; i++)
                  Text(lineas[i],
                      style: TextStyle(
                          fontWeight:
                              i == 0 ? FontWeight.bold : FontWeight.normal,
                          fontSize: i == 0 ? 15 : 13)),
              ],
            ),
          ),
        ]),
      );
}

/// Mantiene las pestañas visibles arriba al desplazarse.
class _PestanasDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color fondo;
  _PestanasDelegate(this.tabBar, this.fondo);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Material(color: fondo, child: tabBar);

  @override
  bool shouldRebuild(_PestanasDelegate old) =>
      old.tabBar != tabBar || old.fondo != fondo;
}
