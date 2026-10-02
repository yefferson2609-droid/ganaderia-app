import 'package:flutter/material.dart';
import '../repositories/movimiento_financiero_repository.dart';

/// Pide confirmación (y precio opcional) para marcar un animal como vendido.
/// Si se indica precio, registra el ingreso en Finanzas.
/// Devuelve true si el usuario confirmó.
Future<bool> confirmarVenta(
  BuildContext context, {
  required String descripcion, // p. ej. 'Vaca #12'
  String? ubicacionId,
}) async {
  final precioCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Marcar como vendido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Confirmas la venta de $descripcion?'),
          const SizedBox(height: 12),
          TextField(
            controller: precioCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio de venta (USD, opcional)',
              helperText: 'Si lo indicas, se registra el ingreso',
              prefixText: r'$ ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar venta')),
      ],
    ),
  );
  if (ok != true) return false;

  final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.'));
  if (precio != null && precio > 0) {
    await MovimientoFinancieroRepository().create(
      tipo: 'ingreso',
      nota: 'Venta de $descripcion',
      monto: precio,
      fecha: DateTime.now(),
      ubicacionId: ubicacionId,
    );
  }
  return true;
}

/// Confirmación simple antes de marcar un animal como fallecido.
Future<bool> confirmarFallecimiento(BuildContext context, String descripcion) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Marcar como fallecido'),
      content: Text('¿Marcar $descripcion como fallecido?'),
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
  return ok == true;
}
