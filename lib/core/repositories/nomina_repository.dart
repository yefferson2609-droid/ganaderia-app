import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/nomina.dart';
import '../utils/auditoria.dart';
import 'movimiento_financiero_repository.dart';

String _dia(DateTime f) => f.toIso8601String().split('T')[0];

/// Nómina semanal. El pago lo hace el servidor (función `pagar_nomina`), sea
/// con el botón "Pagar ahora" o solo el domingo a las 11:55 p. m.; la app
/// muestra la vista previa con el mismo cálculo.
class NominaRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  // ---------- Trabajadores ----------
  Future<List<Trabajador>> getTrabajadores({bool soloActivos = false}) async {
    final rows = await _db.query('trabajadores',
        where: soloActivos ? 'deleted = 0 AND activo = 1' : 'deleted = 0',
        orderBy: 'activo DESC, nombre ASC');
    return rows.map(Trabajador.fromMap).toList();
  }

  Future<Trabajador?> getTrabajador(String id) async {
    final rows = await _db.query('trabajadores',
        where: 'id = ? AND deleted = 0', whereArgs: [id]);
    return rows.isEmpty ? null : Trabajador.fromMap(rows.first);
  }

  Future<void> guardarTrabajador({
    String? id,
    required String nombre,
    String? cedula,
    String? cargo,
    String? telefono,
    required double salarioSemanal,
    DateTime? fechaIngreso,
    bool activo = true,
    String? notas,
  }) async {
    final now = DateTime.now().toIso8601String();
    final datos = {
      'nombre': nombre,
      'cedula': cedula,
      'cargo': cargo,
      'telefono': telefono,
      'salario_semanal': salarioSemanal,
      'fecha_ingreso': fechaIngreso == null ? null : _dia(fechaIngreso),
      'activo': activo ? 1 : 0,
      'notas': notas,
      'updated_at': now,
    };
    if (id == null) {
      await _db.insert(
          'trabajadores',
          filaNueva({
            'id': _uuid.v4(),
            ...datos,
            'created_by': usuarioActualId(),
            'created_at': now,
          }, conAuditoria: false));
    } else {
      await _db.update('trabajadores', filaEditada(datos, conAuditoria: false),
          where: 'id = ?', whereArgs: [id]);
    }
  }

  // ---------- Bonos y anticipos ----------
  Future<List<NovedadNomina>> getNovedades(DateTime semana) async {
    final rows = await _db.query('nomina_novedades',
        where: 'deleted = 0 AND semana_fin = ?',
        whereArgs: [_dia(semana)],
        orderBy: 'created_at ASC');
    return rows.map(NovedadNomina.fromMap).toList();
  }

  /// Bono: se suma en la nómina del domingo.
  /// Anticipo: se registra ya como gasto y se descuenta el domingo.
  Future<void> agregarNovedad({
    required Trabajador trabajador,
    required String tipo,
    required double monto,
    required DateTime fecha,
    String? descripcion,
  }) async {
    String? movimientoId;
    if (tipo == 'anticipo') {
      final mov = await MovimientoFinancieroRepository().create(
        tipo: 'gasto',
        conceptoId: await conceptoNominaId(),
        nota: 'Anticipo a ${trabajador.nombre}'
            '${descripcion != null ? ' · $descripcion' : ''}',
        monto: monto,
        fecha: fecha,
      );
      movimientoId = mov.id;
    }
    // Si la nómina de esa semana ya se pagó, va a la semana siguiente.
    var semana = semanaFin(fecha);
    while ((await getSemana(semana))?.pagada ?? false) {
      semana = semana.add(const Duration(days: 7));
    }
    final now = DateTime.now().toIso8601String();
    await _db.insert(
        'nomina_novedades',
        filaNueva({
          'id': _uuid.v4(),
          'trabajador_id': trabajador.id,
          'semana_fin': _dia(semana),
          'tipo': tipo,
          'monto': monto,
          'descripcion': descripcion,
          'movimiento_id': movimientoId,
          'created_by': usuarioActualId(),
          'created_at': now,
          'updated_at': now,
        }, conAuditoria: false));
  }

  /// Borra un bono o anticipo (y el gasto del anticipo).
  Future<void> eliminarNovedad(NovedadNomina n) async {
    await _db.update('nomina_novedades', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [n.id]);
    if (n.movimientoId != null) {
      await MovimientoFinancieroRepository().delete(n.movimientoId!);
    }
  }

  // ---------- Préstamos ----------
  Future<List<PrestamoTrabajador>> getPrestamos({String? trabajadorId}) async {
    final rows = await _db.rawQuery('''
      SELECT p.*, COALESCE((SELECT SUM(c.monto) FROM prestamo_cuotas c
                             WHERE c.prestamo_id = p.id AND c.deleted = 0), 0) AS pagado
      FROM prestamos_trabajador p
      WHERE p.deleted = 0 ${trabajadorId != null ? 'AND p.trabajador_id = ?' : ''}
      ORDER BY p.estado ASC, p.fecha DESC
    ''', trabajadorId != null ? [trabajadorId] : null);
    return rows.map(PrestamoTrabajador.fromMap).toList();
  }

  /// El préstamo se registra como gasto el día que se entrega y luego se
  /// descuenta en cuotas cada domingo hasta saldarlo.
  Future<void> agregarPrestamo({
    required Trabajador trabajador,
    required double monto,
    required double cuotaSemanal,
    required DateTime fecha,
    String? descripcion,
  }) async {
    final mov = await MovimientoFinancieroRepository().create(
      tipo: 'gasto',
      conceptoId: await conceptoNominaId(),
      nota: 'Préstamo a ${trabajador.nombre}'
          '${descripcion != null ? ' · $descripcion' : ''}',
      monto: monto,
      fecha: fecha,
    );
    final now = DateTime.now().toIso8601String();
    await _db.insert(
        'prestamos_trabajador',
        filaNueva({
          'id': _uuid.v4(),
          'trabajador_id': trabajador.id,
          'fecha': _dia(fecha),
          'monto_total': monto,
          'cuota_semanal': cuotaSemanal,
          'descripcion': descripcion,
          'estado': 'activo',
          'movimiento_id': mov.id,
          'created_by': usuarioActualId(),
          'created_at': now,
          'updated_at': now,
        }, conAuditoria: false));
  }

  // ---------- Semanas ----------
  Future<NominaSemana?> getSemana(DateTime semana) async {
    final rows = await _db.query('nomina_semanas',
        where: 'deleted = 0 AND semana_fin = ?', whereArgs: [_dia(semana)]);
    return rows.isEmpty ? null : NominaSemana.fromMap(rows.first);
  }

  Future<NominaSemana?> getSemanaPorId(String id) async {
    final rows = await _db.query('nomina_semanas',
        where: 'deleted = 0 AND id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : NominaSemana.fromMap(rows.first);
  }

  /// Semana pagada a la que pertenece un gasto de Finanzas (para "Ver detalle").
  Future<NominaSemana?> getSemanaPorMovimiento(String movimientoId) async {
    final rows = await _db.query('nomina_semanas',
        where: 'deleted = 0 AND movimiento_id = ?', whereArgs: [movimientoId]);
    return rows.isEmpty ? null : NominaSemana.fromMap(rows.first);
  }

  Future<List<NominaSemana>> historial() async {
    final rows = await _db.query('nomina_semanas',
        where: "deleted = 0 AND estado = 'pagada'", orderBy: 'semana_fin DESC');
    return rows.map(NominaSemana.fromMap).toList();
  }

  Future<List<FilaNomina>> detalle(String nominaId) async {
    final rows = await _db.query('nomina_detalle',
        where: 'deleted = 0 AND nomina_id = ?',
        whereArgs: [nominaId],
        orderBy: 'trabajador_nombre ASC');
    return rows.map(FilaNomina.fromDetalle).toList();
  }

  /// Vista previa de la nómina de una semana, con el mismo cálculo que el
  /// servidor: sueldo + bonos − anticipos − cuota de cada préstamo activo.
  Future<List<FilaNomina>> calcular(DateTime semana) async {
    final novedades = await getNovedades(semana);
    final prestamos = await getPrestamos();
    final filas = <FilaNomina>[];
    for (final t in await getTrabajadores(soloActivos: true)) {
      if (t.fechaIngreso != null && t.fechaIngreso!.isAfter(semana)) continue;
      double suma(String tipo) => novedades
          .where((n) => n.trabajadorId == t.id && n.tipo == tipo)
          .fold(0.0, (a, n) => a + n.monto);
      final cuotas = prestamos
          .where((p) => p.trabajadorId == t.id && !p.fecha.isAfter(semana))
          .fold(0.0, (a, p) => a + p.proximaCuota);
      filas.add(FilaNomina(
        trabajadorId: t.id,
        nombre: t.nombre,
        salario: t.salarioSemanal,
        bonos: suma('bono'),
        anticipos: suma('anticipo'),
        cuotas: cuotas,
      ));
    }
    return filas;
  }

  /// Paga ya la nómina de la semana (en el servidor). Necesita internet.
  Future<void> pagarAhora(DateTime semana) async {
    try {
      await Supabase.instance.client
          .rpc('pagar_nomina', params: {'p_semana': _dia(semana)});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception(
          'No se pudo pagar. Revisa la conexión a internet e intenta de nuevo.');
    }
  }

  /// Id del concepto de gasto "Nómina" (lo crea si no existe).
  Future<String> conceptoNominaId() async {
    final rows = await _db.rawQuery(
        "SELECT id FROM conceptos_financieros WHERE deleted = 0 AND tipo = 'gasto' "
        "AND lower(nombre) IN ('nómina', 'nomina') ORDER BY created_at LIMIT 1");
    if (rows.isNotEmpty) return rows.first['id'] as String;
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();
    await _db.insert('conceptos_financieros', {
      'id': id,
      'nombre': 'Nómina',
      'tipo': 'gasto',
      'activo': 1,
      'created_at': now,
      'updated_at': now,
      'synced': 0,
      'deleted': 0,
    });
    return id;
  }
}
