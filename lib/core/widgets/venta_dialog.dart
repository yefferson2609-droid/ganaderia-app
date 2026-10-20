import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/movimiento_financiero.dart';
import '../repositories/caballo_repository.dart';
import '../repositories/concepto_financiero_repository.dart';
import '../repositories/movimiento_financiero_repository.dart';
import '../repositories/ternero_repository.dart';
import '../repositories/toro_repository.dart';
import '../repositories/vaca_repository.dart';

final _fmt = DateFormat('dd/MM/yyyy');

/// Botón "Vender" visible en la barra de arriba de la ficha de un animal.
class BotonVender extends StatelessWidget {
  final VoidCallback onPressed;
  const BotonVender({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: Colors.white),
        onPressed: onPressed,
        icon: const Icon(Icons.sell_outlined),
        label: const Text('Vender'),
      );
}

/// Un animal que se va a vender.
class AnimalEnVenta {
  final String tipo; // 'vaca' | 'toro' | 'ternero' | 'caballo'
  final String id;
  final String descripcion; // p. ej. 'Vaca #12', 'Ternero #santo'
  final String? ubicacionId;
  const AnimalEnVenta(this.tipo, this.id, this.descripcion, {this.ubicacionId});
}

/// Datos de la venta que se piden en la ventana.
class DatosVenta {
  final double? precio;
  final DateTime fecha;
  final String? comprador;
  final String? nota;
  const DatosVenta(this.precio, this.fecha, this.comprador, this.nota);
}

/// Nota del ingreso: "Venta de Vaca #12, Ternero #3 · Comprador: X · nota".
String notaDeVenta(List<String> descripciones, DatosVenta d) => [
      'Venta de ${descripciones.join(', ')}',
      if (d.comprador != null) 'Comprador: ${d.comprador}',
      if (d.nota != null) d.nota!,
    ].join(' · ');

/// Animales que nombra la nota de un ingreso de venta.
List<String> animalesDeNota(String? nota) {
  if (nota == null || !nota.startsWith('Venta de ')) return const [];
  return nota
      .substring('Venta de '.length)
      .split(' · ')
      .first
      .split(', ')
      .map((s) => s.trim())
      .toList();
}

/// Ventana única de venta: precio (opcional), fecha, comprador y nota.
/// [titulo] es lo que se vende ("Vaca #12" o "3 animales"); con
/// [cantidad] se pide también cuántos (para lotes de cerdos u ovejos).
Future<(DatosVenta, int)?> pedirDatosVenta(BuildContext context,
    {required String titulo, int? maxCantidad}) async {
  final precioCtrl = TextEditingController();
  final compradorCtrl = TextEditingController();
  final notaCtrl = TextEditingController();
  final cantidadCtrl = TextEditingController(text: '1');
  var fecha = DateTime.now();
  fecha = DateTime(fecha.year, fecha.month, fecha.day);
  String? errorCantidad;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: Text('Vender $titulo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (maxCantidad != null) ...[
                TextField(
                  controller: cantidadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'Cantidad (hay $maxCantidad)',
                      errorText: errorCantidad),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: precioCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: r'Precio total ($)',
                  helperText: 'Se anota el ingreso en Finanzas',
                  prefixText: r'$ ',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: fecha,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) setSt(() => fecha = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha'),
                  child: Text(_fmt.format(fecha)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: compradorCtrl,
                decoration:
                    const InputDecoration(labelText: 'Comprador (opcional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notaCtrl,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
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
                if (maxCantidad != null) {
                  final n = int.tryParse(cantidadCtrl.text.trim());
                  if (n == null || n < 1 || n > maxCantidad) {
                    setSt(() => errorCantidad = 'Entre 1 y $maxCantidad');
                    return;
                  }
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Confirmar venta')),
        ],
      ),
    ),
  );
  if (ok != true) return null;
  String? texto(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();
  final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.'));
  return (
    DatosVenta(precio != null && precio > 0 ? precio : null, fecha,
        texto(compradorCtrl), texto(notaCtrl)),
    int.tryParse(cantidadCtrl.text.trim()) ?? 1,
  );
}

/// Anota el ingreso de una venta con el concepto "Venta de animal". Si ya
/// hay un ingreso del mismo monto cerca de esa fecha, pregunta antes (para
/// no contarlo dos veces). Devuelve si lo anotó.
Future<bool> anotarIngresoDeVenta(BuildContext context,
    {required String nota,
    required DatosVenta datos,
    String? ubicacionId}) async {
  final precio = datos.precio;
  if (precio == null) return false;
  final movs = MovimientoFinancieroRepository();
  final parecidos = (await movs.getAll(
          tipo: 'ingreso',
          desde: datos.fecha.subtract(const Duration(days: 7)),
          hasta: datos.fecha.add(const Duration(days: 7))))
      .where((m) => (m.monto - precio).abs() < 0.01)
      .toList();
  if (parecidos.isNotEmpty && context.mounted) {
    final m = parecidos.first;
    final registrar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Ya anotaste este ingreso?'),
        content: Text('Ya hay un ingreso de \$${m.monto.toStringAsFixed(2)} '
            'el ${_fmt.format(m.fecha)}'
            '${m.nota != null ? ' ("${m.nota}")' : ''}.\n\n'
            'Si es esta misma venta, no la anotes otra vez.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ya está, no anotar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Anotar igual')),
        ],
      ),
    );
    if (registrar != true) return false;
  }
  await movs.create(
    tipo: 'ingreso',
    conceptoId: await ConceptoFinancieroRepository().idVentaDeAnimal(),
    nota: nota,
    monto: precio,
    fecha: datos.fecha,
    ubicacionId: ubicacionId,
  );
  return true;
}

/// Marca el animal como vendido (vacas: 'vendida'; los demás: 'vendido').
Future<void> marcarVendido(AnimalEnVenta a) async {
  switch (a.tipo) {
    case 'vaca':
      final v = await VacaRepository().getById(a.id);
      if (v != null) await VacaRepository().update(v.copyWith(estado: 'vendida'));
    case 'toro':
      final t = await ToroRepository().getById(a.id);
      if (t != null) await ToroRepository().update(t.copyWith(estado: 'vendido'));
    case 'ternero':
      final t = await TerneroRepository().getById(a.id);
      if (t != null) {
        await TerneroRepository().update(t.copyWith(estado: 'vendido'));
      }
    case 'caballo':
      final c = await CaballoRepository().getById(a.id);
      if (c != null) {
        await CaballoRepository().update(c.copyWith(estado: 'vendido'));
      }
  }
}

/// Venta de uno o varios animales: pide los datos, los marca vendidos y
/// anota UN ingreso con todos en la nota. Devuelve true si se vendió.
Future<bool> venderAnimales(
    BuildContext context, List<AnimalEnVenta> animales) async {
  if (animales.isEmpty) return false;
  final r = await pedirDatosVenta(context,
      titulo: animales.length == 1
          ? animales.first.descripcion
          : '${animales.length} animales');
  if (r == null) return false;
  final (datos, _) = r;
  for (final a in animales) {
    await marcarVendido(a);
  }
  if (context.mounted) {
    await anotarIngresoDeVenta(context,
        nota: notaDeVenta(animales.map((a) => a.descripcion).toList(), datos),
        datos: datos,
        ubicacionId: animales.first.ubicacionId);
  }
  return true;
}

/// Al volver un animal vendido a activo: si su venta tiene un ingreso
/// propio, ofrece borrarlo de Finanzas. Si el ingreso incluye otros
/// animales, solo avisa (hay que corregirlo a mano en Finanzas).
Future<void> ofrecerAnularIngresoDeVenta(
    BuildContext context, String descripcion) async {
  final repo = MovimientoFinancieroRepository();
  final ventaId = await ConceptoFinancieroRepository().idVentaDeAnimal();
  final ingresos = (await repo.getAll(tipo: 'ingreso', conceptoId: ventaId))
      .where((m) => animalesDeNota(m.nota).contains(descripcion))
      .toList();
  if (ingresos.isEmpty || !context.mounted) return;
  final MovimientoFinanciero m = ingresos.first;
  final soloEste = animalesDeNota(m.nota).length == 1;
  final borrar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ingreso de la venta'),
      content: Text(soloEste
          ? 'La venta de $descripcion tiene un ingreso de '
              '\$${m.monto.toStringAsFixed(2)} del ${_fmt.format(m.fecha)}.\n\n'
              '¿Lo borro de Finanzas?'
          : 'La venta de $descripcion está en un ingreso de '
              '\$${m.monto.toStringAsFixed(2)} junto con otros animales '
              '(${m.nota}).\n\nCorrige el monto en Finanzas si hace falta.'),
      actions: soloEste
          ? [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Dejarlo')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Borrar ingreso')),
            ]
          : [
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Entendido')),
            ],
    ),
  );
  if (borrar == true) await repo.delete(m.id);
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
