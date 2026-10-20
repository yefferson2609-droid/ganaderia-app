import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/procedencia.dart';
import '../../core/models/evento_vaca.dart';
import '../../core/models/tipo_evento.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/evento_vaca_repository.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/tipo_evento_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/repositories/vaca_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animal_face.dart';
import '../../core/widgets/ficha_animal.dart';
import '../../core/widgets/creador_info.dart';
import '../../core/widgets/descendencia_section.dart';
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
  final _eventoRepo = EventoVacaRepository();
  final _tipoRepo = TipoEventoRepository();

  Vaca? _vaca;
  int? _crias;
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
      _eventos = await _eventoRepo.getByVaca(widget.id);
      _ubicacion = _vaca!.ubicacionId != null
          ? (await UbicacionRepository().getById(_vaca!.ubicacionId!))?.nombre
          : null;
      _resumen = await ReproduccionRepository().resumen(widget.id);
    }
    // Partos, secados y palpaciones tienen su propio botón.
    _tipos = (await _tipoRepo.getAll(soloActivos: true))
        .where((t) => !esTipoConBotonPropio(t.nombre))
        .toList();
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
        if (await venderAnimales(context, [
          AnimalEnVenta('vaca', vaca.id, 'Vaca #${vaca.numero}',
              ubicacionId: vaca.ubicacionId)
        ])) {
          _load();
        }
      case 'fallecida':
        if (await confirmarFallecimiento(context, 'la vaca #${vaca.numero}')) {
          await _vacaRepo.update(vaca.copyWith(estado: 'fallecida'));
          _load();
        }
      case 'activa':
        await _vacaRepo.update(vaca.copyWith(estado: 'activa'));
        if (vaca.estado == 'vendida' && mounted) {
          await ofrecerAnularIngresoDeVenta(context, 'Vaca #${vaca.numero}');
        }
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
          if (_vaca!.estado == 'activa') BotonVender(onPressed: () => _accion('vendida')),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        children: [
          _resumenCard(),
          _Plegable(
            titulo: 'Datos',
            icono: Icons.info_outline,
            abierto: true,
            children: [
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
              if (_vaca!.procedencia.origen != null)
                _InfoRow(
                    label: 'Origen',
                    value: Procedencia.origenTexto(_vaca!.procedencia.origen!,
                        hembra: true)),
              if (_vaca!.procedencia.registro != null)
                _InfoRow(label: 'Registro', value: _vaca!.procedencia.registro!),
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
            titulo: 'Partos y ordeño (${_resumen?.partos.length ?? 0})',
            icono: Icons.child_friendly,
            abierto: true,
            children: [
              ReproduccionSection(
                key: ValueKey('repro$_version'),
                vaca: _vaca!,
                marco: false,
                onCambio: () {
                  _version++;
                  _load();
                },
              ),
            ],
          ),
          _Plegable(
            titulo: 'Descendencia${_crias != null ? ' ($_crias)' : ''}',
            icono: Icons.account_tree_outlined,
            children: [
              DescendenciaSection(
                key: ValueKey(
                    'desc$_version${_vaca!.madreId}${_vaca!.padreId}'),
                animalId: widget.id,
                madreId: _vaca!.madreId,
                padreId: _vaca!.padreId,
                procedencia: _vaca!.procedencia,
                marco: false,
                onTotal: (n) {
                  if (n != _crias) setState(() => _crias = n);
                },
              ),
            ],
          ),
          _Plegable(
            titulo: 'Salud',
            icono: Icons.healing,
            children: [
              SaludSection(
                  animalTipo: 'vaca',
                  animalId: widget.id,
                  femenino: true,
                  marco: false),
            ],
          ),
          _Plegable(
            titulo: 'Pesos',
            icono: Icons.monitor_weight_outlined,
            children: [
              PesajesSection(
                  animalTipo: 'vaca', animalId: widget.id, marco: false),
            ],
          ),
          _Plegable(
            titulo: 'Historial (${_eventos.length})',
            icono: Icons.event_note,
            children: [
              if (_eventos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Sin eventos registrados',
                      style: TextStyle(color: AppColors.textoSuave)),
                )
              else
                for (final e in _eventos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.event_note,
                        color: AppColors.primary),
                    title: Text(e.tipoEventoNombre ?? 'Evento',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      DateFormat('dd/MM/yyyy').format(e.fecha),
                      if (e.notas != null && e.notas!.isNotEmpty) e.notas!,
                    ].join(' · ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.danger, size: 20),
                      onPressed: () => _eliminarEvento(e.id),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  /// Resumen de arriba: foto, edad, partos, ordeño y preñez.
  Widget _resumenCard() {
    final v = _vaca!;
    final r = _resumen;
    final fmt = DateFormat('dd/MM/yyyy');
    final estadoProd = r?.estado;
    final chips = <Widget>[
      if (v.estado != 'activa')
        Etiqueta(v.estado[0].toUpperCase() + v.estado.substring(1),
            _estadoColor(v.estado),
            sobreOscuro: true)
      else if (estadoProd != null)
        Etiqueta(
            kEstadoProduccionLabels[estadoProd]! +
                (r!.diasEnLeche != null ? ' · ${r.diasEnLeche} días' : ''),
            estadoProduccionColor(estadoProd),
            sobreOscuro: true),
      if (v.procedencia.origen == 'comprada' ||
          v.procedencia.origen == 'importada')
        Etiqueta(Procedencia.origenTexto(v.procedencia.origen!, hembra: true),
            AppColors.secondary,
            icono: Icons.local_shipping_outlined,
            sobreOscuro: true),
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

    return Column(children: [
      PortadaAnimal(
        cara: AnimalFaceEditable(
            tipo: 'vaca',
            id: v.id,
            fotoLocal: v.fotoLocal,
            fotoUrl: v.fotoUrl,
            estadoColor: _estadoColor(v.estado),
            onCambio: _load),
        titulo: 'Vaca #${v.numero}',
        detalle: [
          v.fechaNacimiento != null ? v.edad : 'Edad sin registrar',
          '${r?.partos.length ?? 0} parto${(r?.partos.length ?? 0) == 1 ? '' : 's'}',
          if (v.raza != null) v.raza!,
        ].join(' · '),
        etiquetas: chips,
      ),
      if (prenez != null)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: prenez),
    ]);
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
        return AppColors.textoSuave;
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
                style: const TextStyle(color: AppColors.textoSuave, fontSize: 13)),
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
          borderRadius: BorderRadius.circular(16),
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
