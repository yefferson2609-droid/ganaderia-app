import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tipo_evento.dart';
import '../repositories/evento_animal_repository.dart';
import '../repositories/reproduccion_repository.dart';
import '../repositories/tipo_evento_repository.dart';
import '../theme/app_theme.dart';

final _fmt = DateFormat('dd/MM/yyyy');

/// Historial de eventos (vacunas, desparasitación, baños…) de un toro,
/// animal de levante y ceba o caballo, con botón para agregar uno.
class EventosAnimalSection extends StatefulWidget {
  final String animalTipo; // 'toro' | 'ternero' | 'caballo'
  final String animalId;
  const EventosAnimalSection(
      {super.key, required this.animalTipo, required this.animalId});

  @override
  State<EventosAnimalSection> createState() => _EventosAnimalSectionState();
}

class _EventosAnimalSectionState extends State<EventosAnimalSection> {
  final _repo = EventoAnimalRepository();
  List<EventoAnimal> _eventos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await _repo.getByAnimal(widget.animalTipo, widget.animalId);
    if (mounted) {
      setState(() {
        _eventos = e;
        _loading = false;
      });
    }
  }

  Future<void> _agregar() async {
    final tipos = (await TipoEventoRepository().getAll(soloActivos: true))
        .where((t) => !esTipoConBotonPropio(t.nombre))
        .toList();
    if (!mounted) return;
    if (tipos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Primero crea los tipos de evento (Menú ☰ → Tipos de evento)')));
      return;
    }
    TipoEvento tipo = tipos.first;
    DateTime fecha = DateTime.now();
    final notasCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Registrar evento'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<TipoEvento>(
              initialValue: tipo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de evento'),
              items: [
                for (final t in tipos)
                  DropdownMenuItem(value: t, child: Text(t.nombre))
              ],
              onChanged: (v) => setSt(() => tipo = v!),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final p = await showDatePicker(
                    context: ctx,
                    initialDate: fecha,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now());
                if (p != null) setSt(() => fecha = p);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha'),
                child: Text(_fmt.format(fecha)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notasCtrl,
              decoration: const InputDecoration(
                  labelText: 'Notas (producto, dosis…)'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.create(
      animalTipo: widget.animalTipo,
      animalId: widget.animalId,
      tipoEventoId: tipo.id,
      fecha: fecha,
      notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
    );
    _load();
  }

  Future<void> _eliminar(EventoAnimal e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text('¿Eliminar "${e.tipoEventoNombre ?? 'Evento'}" del '
            '${_fmt.format(e.fecha)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.delete(e.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('Historial de eventos (${_eventos.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: _agregar,
                icon: const Icon(Icons.add),
                label: const Text('Evento'),
              ),
            ]),
            if (_eventos.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Sin eventos registrados',
                    style: TextStyle(color: AppColors.textoSuave)),
              )
            else
              for (final e in _eventos)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.event_note, color: AppColors.primary),
                  title: Text(e.tipoEventoNombre ?? 'Evento',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([
                    _fmt.format(e.fecha),
                    if (e.notas != null && e.notas!.isNotEmpty) e.notas!,
                  ].join(' · ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AppColors.danger),
                    onPressed: () => _eliminar(e),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
