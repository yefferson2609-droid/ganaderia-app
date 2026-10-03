import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/local_db.dart';
import '../repositories/actividad_repository.dart';
import '../repositories/concepto_financiero_repository.dart';
import '../repositories/movimiento_financiero_repository.dart';
import '../repositories/perfil_usuario_repository.dart';
import '../repositories/registro_salud_repository.dart';
import '../repositories/ubicacion_repository.dart';
import '../utils/animal_nombre.dart';
import 'inventario_service.dart';

class SeccionesReporte {
  final bool inventario;
  final bool detalleAnimales; // ficha de cada animal dentro del inventario
  final bool finanzas;
  final bool salud;
  final bool eventos;

  const SeccionesReporte({
    this.inventario = true,
    this.detalleAnimales = true,
    this.finanzas = true,
    this.salud = true,
    this.eventos = true,
  });

  bool get alguna => inventario || finanzas || salud || eventos;
}

final _fmt = DateFormat('dd/MM/yyyy');
final _money = NumberFormat.currency(locale: 'en_US', symbol: r'$');
const _verde = PdfColor.fromInt(0xFF2F6B3A);

/// La fuente base del PDF solo cubre Latin-1: se reemplaza lo demás
/// (guiones largos, flechas, emojis escritos por el usuario).
String _l(String s) => s
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll('→', '->')
    .replaceAll(RegExp(r'[^\u0000-ÿ]'), '?');

class ReportePdfService {
  /// Nombre de archivo sugerido para el reporte.
  static String nombreArchivo() =>
      'reporte_ganaderia_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

  Future<Uint8List> generar({
    required DateTime desde,
    required DateTime hasta,
    required SeccionesReporte secciones,
  }) async {
    final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/hierro_logo.jpeg'))
            .buffer
            .asUint8List());

    final contenido = <pw.Widget>[];
    if (secciones.inventario) {
      contenido.addAll(await _inventario());
      if (secciones.detalleAnimales) {
        contenido.addAll(await _inventarioDetallado());
      }
    }
    if (secciones.finanzas) contenido.addAll(await _finanzas(desde, hasta));
    if (secciones.salud) contenido.addAll(await _salud(desde, hasta));
    if (secciones.eventos) contenido.addAll(await _eventos(desde, hasta));

    final doc = pw.Document(title: 'Reporte general - Ganadería');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _verde, width: 2))),
        child: pw.Row(children: [
          pw.Image(logo, width: 36, height: 36),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Reporte general - Ganadería',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _verde)),
                pw.Text(
                    'Rango de fechas: ${_fmt.format(desde)} - ${_fmt.format(hasta)}',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          pw.Text('Generado: ${_fmt.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8)),
        ]),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (ctx) => contenido,
    ));
    return doc.save();
  }

  pw.Widget _titulo(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: _verde)),
      );

  pw.Widget _tabla(List<String> encabezados, List<List<String>> filas,
      {Map<int, pw.Alignment>? alineacion}) {
    if (filas.isEmpty) {
      return pw.Text('Sin registros',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700));
    }
    return pw.TableHelper.fromTextArray(
      headers: encabezados,
      data: filas.map((f) => f.map(_l).toList()).toList(),
      headerStyle: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _verde),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: alineacion ?? {},
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    );
  }

  Future<List<pw.Widget>> _inventario() async {
    final ubRepo = UbicacionRepository();
    final etiquetas = {
      'vacas': 'Vacas',
      'toros': 'Toros',
      'terneros': 'Terneros',
      'caballos': 'Caballos',
      'cerdos': 'Cerdos',
      'ovejos': 'Ovejos',
    };
    final total = await ubRepo.getConteosPorUbicacion(null, todas: true);
    final filas = <List<String>>[];
    for (final u in await ubRepo.getAll(soloActivas: true)) {
      final c = await ubRepo.getConteosPorUbicacion(u.id);
      filas.add([u.nombre, ...etiquetas.keys.map((k) => '${c[k] ?? 0}')]);
    }
    final sin = await ubRepo.getConteosPorUbicacion(null);
    if (sin.values.any((v) => v > 0)) {
      filas.add(['Sin ubicación', ...etiquetas.keys.map((k) => '${sin[k] ?? 0}')]);
    }
    filas.add(['TOTAL', ...etiquetas.keys.map((k) => '${total[k] ?? 0}')]);

    return [
      _titulo('Inventario de animales'),
      pw.Text('Estado actual (no depende del rango de fechas).',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      pw.SizedBox(height: 4),
      _tabla(['Ubicación', ...etiquetas.values], filas, alineacion: {
        for (var i = 1; i <= etiquetas.length; i++) i: pw.Alignment.centerRight
      }),
    ];
  }

  Future<List<pw.Widget>> _inventarioDetallado() async {
    final grupos = await InventarioService().generar();
    final w = <pw.Widget>[_titulo('Inventario detallado por ubicación')];
    const chico = pw.TextStyle(fontSize: 8);
    for (final g in grupos) {
      w.add(pw.Container(
        margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        color: PdfColors.green50,
        child: pw.Text(
          _l('${g.nombre} - ${g.animales.length} animales'
              '${g.cerdos > 0 ? ' · ${g.cerdos} cerdos' : ''}'
              '${g.ovejos > 0 ? ' · ${g.ovejos} ovejos' : ''}'),
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ));
      for (final a in g.animales) {
        w.add(pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(
                  color: a.enTratamiento ? PdfColors.red300 : PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(3)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                  _l('${a.titulo}  ·  ${a.resumen}'
                      '${a.enTratamiento ? '  ·  EN TRATAMIENTO' : ''}'),
                  style:
                      pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              if (a.datos.isNotEmpty)
                pw.Text(
                    _l(a.datos.map((d) => '${d.$1}: ${d.$2}').join('  |  ')),
                    style: chico),
              pw.Text(
                  _l('Salud: ${a.salud.isEmpty ? 'sin registros' : a.salud.join('; ')}'),
                  style: chico),
              if (a.eventos.isNotEmpty)
                pw.Text(_l('Eventos: ${a.eventos.join('; ')}'), style: chico),
            ],
          ),
        ));
      }
    }
    return w;
  }

  Future<List<pw.Widget>> _finanzas(DateTime desde, DateTime hasta) async {
    final repo = MovimientoFinancieroRepository();
    final conceptos = {
      for (final c in await ConceptoFinancieroRepository().getAll()) c.id: c.nombre
    };
    final movs = await repo.getAll(desde: desde, hasta: hasta);
    final tot = await repo.getTotales(desde: desde, hasta: hasta);

    return [
      _titulo('Finanzas'),
      pw.Row(children: [
        _dato('Ingresos', _money.format(tot['ingresos'] ?? 0)),
        _dato('Gastos', _money.format(tot['gastos'] ?? 0)),
        _dato('Utilidad', _money.format(tot['utilidad'] ?? 0)),
      ]),
      pw.SizedBox(height: 6),
      _tabla(
        ['Fecha', 'Tipo', 'Concepto', 'Nota', 'Monto'],
        movs
            .map((m) => [
                  _fmt.format(m.fecha),
                  m.tipo == 'ingreso' ? 'Ingreso' : 'Gasto',
                  conceptos[m.conceptoId] ?? '-',
                  m.nota ?? '',
                  '${m.tipo == 'gasto' ? '-' : ''}${_money.format(m.monto)}',
                ])
            .toList(),
        alineacion: {4: pw.Alignment.centerRight},
      ),
    ];
  }

  pw.Widget _dato(String label, String valor) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
                pw.Text(valor,
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ]),
        ),
      );

  Future<List<pw.Widget>> _salud(DateTime desde, DateTime hasta) async {
    final repo = RegistroSaludRepository();
    final activos = await repo.getEnTratamiento();
    final filasActivos = <List<String>>[];
    for (final r in activos) {
      filasActivos.add([
        await nombreAnimal(r.animalTipo, r.animalId),
        r.diagnostico,
        _fmt.format(r.fechaInicio),
      ]);
    }
    final aplicados = await repo.getAplicados(desde: desde, hasta: hasta);
    final filasAplicados = <List<String>>[];
    for (final t in aplicados) {
      filasAplicados.add([
        _fmt.format(t.fecha),
        t.animalTipo != null && t.animalId != null
            ? await nombreAnimal(t.animalTipo!, t.animalId!)
            : '',
        t.medicamento,
        t.dosis ?? '',
      ]);
    }
    final programadas = (await repo.getDosisProgramadas()).length;

    return [
      _titulo('Salud'),
      pw.Text('Animales en tratamiento actualmente',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      _tabla(['Animal', 'Diagnóstico', 'Desde'], filasActivos),
      pw.SizedBox(height: 8),
      pw.Text('Tratamientos aplicados en el rango',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      _tabla(['Fecha', 'Animal', 'Medicamento', 'Dosis'], filasAplicados),
      pw.SizedBox(height: 4),
      pw.Text('Dosis programadas pendientes (todas las fechas): $programadas',
          style: const pw.TextStyle(fontSize: 9)),
    ];
  }

  Future<List<pw.Widget>> _eventos(DateTime desde, DateTime hasta) async {
    final db = LocalDb.instance.db;
    final eventos = await db.rawQuery('''
      SELECT e.fecha, e.notas, v.numero, t.nombre AS tipo
      FROM eventos_vaca e
      LEFT JOIN vacas v ON v.id = e.vaca_id
      LEFT JOIN tipos_evento t ON t.id = e.tipo_evento_id
      WHERE e.deleted = 0 AND e.fecha >= ? AND e.fecha <= ?
      ORDER BY e.fecha DESC
    ''', [
      desde.toIso8601String().split('T')[0],
      hasta.toIso8601String().split('T')[0],
    ]);

    final perfiles = {
      for (final p in await PerfilUsuarioRepository().getAll())
        p.id: p.nombre.isNotEmpty ? p.nombre : p.correo
    };
    final actividades = await ActividadRepository()
        .getCompletadasEnRango(desde: desde, hasta: hasta);

    return [
      _titulo('Eventos y actividades'),
      pw.Text('Eventos de vacas',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      _tabla(
        ['Fecha', 'Vaca', 'Evento', 'Notas'],
        eventos
            .map((e) => [
                  _fmt.format(DateTime.parse(e['fecha'] as String)),
                  e['numero'] != null ? '#${e['numero']}' : '-',
                  (e['tipo'] as String?) ?? 'Evento',
                  (e['notas'] as String?) ?? '',
                ])
            .toList(),
      ),
      pw.SizedBox(height: 8),
      pw.Text('Actividades completadas',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      _tabla(
        ['Completada', 'Actividad', 'Responsable'],
        actividades
            .map((a) => [
                  a.fechaCompletada != null ? _fmt.format(a.fechaCompletada!) : '',
                  a.descripcion,
                  perfiles[a.completadoPor ?? a.asignadoA] ?? '',
                ])
            .toList(),
      ),
    ];
  }
}
