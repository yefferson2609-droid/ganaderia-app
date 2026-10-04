import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/pesaje_repository.dart';
import '../theme/app_theme.dart';

final _fmt = DateFormat('dd/MM/yyyy');

/// Historial de pesos (opcional) para la ficha de un animal adulto.
class PesajesSection extends StatefulWidget {
  final String animalTipo;
  final String animalId;
  const PesajesSection(
      {super.key, required this.animalTipo, required this.animalId});

  @override
  State<PesajesSection> createState() => _PesajesSectionState();
}

class _PesajesSectionState extends State<PesajesSection> {
  final _repo = PesajeRepository();
  List<PesajeAnimal> _pesajes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _repo.getByAnimal(widget.animalTipo, widget.animalId);
    if (mounted) setState(() => _pesajes = p);
  }

  Future<void> _registrar() async {
    final pesoCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    DateTime fecha = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Registrar peso'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: pesoCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Peso *', suffixText: 'kg'),
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
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () {
                  final p = double.tryParse(pesoCtrl.text.replaceAll(',', '.'));
                  if (p == null || p <= 0) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.registrar(
      tipo: widget.animalTipo,
      animalId: widget.animalId,
      fecha: fecha,
      peso: double.parse(pesoCtrl.text.replaceAll(',', '.')),
      notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  _pesajes.isEmpty
                      ? 'Peso'
                      : 'Peso: ${_pesajes.first.peso.toStringAsFixed(1)} kg',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _registrar,
                icon: const Icon(Icons.monitor_weight_outlined),
                label: const Text('Pesar'),
              ),
            ]),
            if (_pesajes.isEmpty)
              const Text('Sin pesajes (opcional)',
                  style: TextStyle(color: Colors.grey))
            else
              ..._pesajes.take(6).toList().asMap().entries.map((e) {
                final p = e.value;
                final ant = e.key + 1 < _pesajes.length ? _pesajes[e.key + 1] : null;
                final dif = ant != null ? p.peso - ant.peso : null;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${p.peso.toStringAsFixed(1)} kg'
                      '${dif != null ? '  (${dif >= 0 ? '+' : ''}${dif.toStringAsFixed(1)})' : ''}'),
                  subtitle: Text([_fmt.format(p.fecha), if (p.notas != null) p.notas!]
                      .join(' · ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AppColors.danger),
                    onPressed: () async {
                      await _repo.delete(p.id);
                      _load();
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
