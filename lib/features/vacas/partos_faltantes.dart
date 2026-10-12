import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/theme/app_theme.dart';

final _fmt = DateFormat('dd/MM/yyyy');

/// Lista para revisar las crías cuyo parto falta en la madre. No guarda nada
/// hasta tocar "Registrar partos". Devuelve true si se guardó algo.
Future<bool> revisarPartosFaltantes(
    BuildContext context, List<PartoFaltante> lista) async {
  final incluir = {for (var i = 0; i < lista.length; i++) i: true};
  final seca = <String>{}; // vacas marcadas "ya está seca"

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        final n = incluir.values.where((v) => v).length;
        return AlertDialog(
          title: const Text('Partos que faltan'),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'Estas crías tienen madre y fecha de nacimiento, pero la '
                  'madre no tiene ese parto registrado. Desmarca las que no '
                  'quieras registrar.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < lista.length; i++) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: incluir[i],
                    onChanged: (v) => setSt(() => incluir[i] = v!),
                    title: Text('Vaca #${lista[i].vaca}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Parto ${_fmt.format(lista[i].fecha)} · cría ${lista[i].cria}'),
                  ),
                  if (lista[i].quedariaEnOrdeno && incluir[i]!)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.warning_amber,
                            size: 18, color: AppColors.warning),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text('Quedará "En ordeño"',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.warning)),
                        ),
                        FilterChip(
                          label: const Text('Ya está seca'),
                          selected: seca.contains(lista[i].vacaId),
                          onSelected: (s) => setSt(() => s
                              ? seca.add(lista[i].vacaId)
                              : seca.remove(lista[i].vacaId)),
                        ),
                      ]),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: n == 0 ? null : () => Navigator.pop(ctx, true),
              child: Text('Registrar $n parto${n == 1 ? '' : 's'}'),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true) return false;

  final repo = ReproduccionRepository();
  final secadas = <String>{};
  for (var i = 0; i < lista.length; i++) {
    if (!incluir[i]!) continue;
    final x = lista[i];
    await repo.partoSiFalta(x.vacaId, x.fecha,
        notas: 'Registrado por la cría ${x.cria}');
    if (x.quedariaEnOrdeno && seca.contains(x.vacaId) && secadas.add(x.vacaId)) {
      await repo.secar(
          vacaId: x.vacaId,
          fecha: DateTime.now(),
          notas: 'Marcada seca al completar partos (fecha aproximada)');
    }
  }
  return true;
}
