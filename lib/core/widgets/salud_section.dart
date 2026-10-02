import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/salud.dart';
import '../repositories/registro_salud_repository.dart';
import '../theme/app_theme.dart';

final _fmt = DateFormat('dd/MM/yyyy');

/// Sección de salud para la ficha de un animal: problema activo,
/// tratamientos (aplicados y programados) e historial.
class SaludSection extends StatefulWidget {
  final String animalTipo; // 'vaca' | 'toro' | 'ternero' | 'caballo'
  final String animalId;
  final bool femenino; // para "Marcar como recuperada"

  const SaludSection({
    super.key,
    required this.animalTipo,
    required this.animalId,
    this.femenino = false,
  });

  @override
  State<SaludSection> createState() => _SaludSectionState();
}

class _SaludSectionState extends State<SaludSection> {
  final _repo = RegistroSaludRepository();
  RegistroSalud? _activo;
  List<TratamientoSalud> _tratamientos = [];
  List<RegistroSalud> _historial = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final todos = await _repo.getByAnimal(widget.animalTipo, widget.animalId);
    final activo = todos.where((r) => r.activo).firstOrNull;
    final tratamientos =
        activo != null ? await _repo.getTratamientos(activo.id) : <TratamientoSalud>[];
    if (!mounted) return;
    setState(() {
      _activo = activo;
      _tratamientos = tratamientos;
      _historial = todos.where((r) => !r.activo).toList();
      _loading = false;
    });
  }

  Future<DateTime?> _pickFecha(BuildContext ctx, DateTime inicial,
      {bool permitirFuturo = false}) {
    return showDatePicker(
      context: ctx,
      initialDate: inicial,
      firstDate: DateTime(2000),
      lastDate: permitirFuturo
          ? DateTime.now().add(const Duration(days: 365))
          : DateTime.now(),
    );
  }

  Future<void> _registrarProblema() async {
    final diagCtrl = TextEditingController();
    DateTime fecha = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Registrar problema de salud'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: diagCtrl,
                decoration: const InputDecoration(
                    labelText: 'Síntomas / diagnóstico *'),
                maxLines: 2,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final p = await _pickFecha(ctx, fecha);
                  if (p != null) setSt(() => fecha = p);
                },
                child: InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Fecha de inicio'),
                  child: Text(_fmt.format(fecha)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () {
                  if (diagCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.create(
      animalTipo: widget.animalTipo,
      animalId: widget.animalId,
      fechaInicio: fecha,
      diagnostico: diagCtrl.text.trim(),
    );
    _load();
  }

  Future<void> _agregarTratamiento() async {
    if (_activo == null) return;
    final medCtrl = TextEditingController();
    final dosisCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    DateTime fecha = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Agregar tratamiento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: medCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Medicamento *'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dosisCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Dosis (opcional)'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final p =
                        await _pickFecha(ctx, fecha, permitirFuturo: true);
                    if (p != null) setSt(() => fecha = p);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      helperText:
                          'Una fecha futura queda como dosis programada',
                    ),
                    child: Text(_fmt.format(fecha)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notasCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Notas (opcional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () {
                  if (medCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.registrarTratamiento(
      registroId: _activo!.id,
      fecha: fecha,
      medicamento: medCtrl.text.trim(),
      dosis: dosisCtrl.text.trim().isEmpty ? null : dosisCtrl.text.trim(),
      notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
    );
    _load();
  }

  Future<void> _marcarRecuperado() async {
    final palabra = widget.femenino ? 'recuperada' : 'recuperado';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Marcar como $palabra'),
        content: const Text('Se cerrará el problema de salud activo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.marcarRecuperado(_activo!.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final titulo = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.healing,
                  color: _activo != null ? AppColors.danger : AppColors.success),
              const SizedBox(width: 8),
              Text('Salud', style: titulo),
            ]),
            const SizedBox(height: 8),
            if (_activo == null) ...[
              const Text('Sin problemas de salud activos'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _registrarProblema,
                icon: const Icon(Icons.add),
                label: const Text('Registrar problema de salud'),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_activo!.diagnostico,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger)),
                    Text(
                        'En tratamiento desde ${_fmt.format(_activo!.fechaInicio)}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_tratamientos.isNotEmpty)
                Text('Tratamientos aplicados',
                    style: Theme.of(context).textTheme.labelLarge),
              ..._tratamientos.map((t) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      t.programado ? Icons.schedule : Icons.check_circle,
                      color: t.programado
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                    title: Text(
                        '${t.medicamento}${t.dosis != null ? ' · ${t.dosis}' : ''}'),
                    subtitle: Text(
                        '${t.programado ? 'Programado: ' : ''}${_fmt.format(t.fecha)}'
                        '${t.notas != null ? '\n${t.notas}' : ''}'),
                    trailing: t.programado
                        ? IconButton(
                            tooltip: 'Marcar dosis como aplicada',
                            icon: const Icon(Icons.done_all),
                            onPressed: () async {
                              await _repo.marcarTratamientoAplicado(t.id);
                              _load();
                            },
                          )
                        : null,
                  )),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: _agregarTratamiento,
                  icon: const Icon(Icons.medication),
                  label: const Text('Agregar tratamiento'),
                ),
                ElevatedButton.icon(
                  onPressed: _marcarRecuperado,
                  icon: const Icon(Icons.favorite),
                  label: Text(widget.femenino
                      ? 'Marcar como recuperada'
                      : 'Marcar como recuperado'),
                ),
              ]),
            ],
            if (_historial.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Historial de salud',
                  style: Theme.of(context).textTheme.labelLarge),
              ..._historial.map((r) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• ${r.diagnostico} (${_fmt.format(r.fechaInicio)}'
                      '${r.fechaFin != null ? ' – ${_fmt.format(r.fechaFin!)}' : ''})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
