import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_db.dart';
import '../models/movimiento_financiero.dart';

class MovimientoFinancieroRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<MovimientoFinanciero>> getAll({
    String? tipo,
    String? conceptoId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    String where = 'deleted = 0';
    List<dynamic> args = [];
    if (tipo != null) {
      where += ' AND tipo = ?';
      args.add(tipo);
    }
    if (conceptoId != null) {
      where += ' AND concepto_id = ?';
      args.add(conceptoId);
    }
    if (desde != null) {
      where += ' AND fecha >= ?';
      args.add(desde.toIso8601String().split('T')[0]);
    }
    if (hasta != null) {
      where += ' AND fecha <= ?';
      args.add(hasta.toIso8601String().split('T')[0]);
    }
    final rows = await _db.query('movimientos_financieros',
        where: where,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'fecha DESC, created_at DESC');
    return rows.map(MovimientoFinanciero.fromMap).toList();
  }

  Future<MovimientoFinanciero?> getById(String id) async {
    final rows = await _db.query('movimientos_financieros',
        where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return MovimientoFinanciero.fromMap(rows.first);
  }

  /// Totales {ingresos, gastos, utilidad} para el rango de filtros dado.
  Future<Map<String, double>> getTotales({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final movimientos = await getAll(desde: desde, hasta: hasta);
    double ingresos = 0;
    double gastos = 0;
    for (final m in movimientos) {
      if (m.tipo == 'ingreso') {
        ingresos += m.monto;
      } else {
        gastos += m.monto;
      }
    }
    return {
      'ingresos': ingresos,
      'gastos': gastos,
      'utilidad': ingresos - gastos,
    };
  }

  Future<MovimientoFinanciero> create({
    required String tipo,
    String? conceptoId,
    String? nota,
    required double monto,
    required DateTime fecha,
    String? ubicacionId,
  }) async {
    final now = DateTime.now();
    final movimiento = MovimientoFinanciero(
      id: _uuid.v4(),
      tipo: tipo,
      conceptoId: conceptoId,
      nota: nota,
      monto: monto,
      fecha: fecha,
      ubicacionId: ubicacionId,
      createdBy: Supabase.instance.client.auth.currentUser?.id,
      createdAt: now,
      updatedAt: now,
    );
    final map = movimiento.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.insert('movimientos_financieros', map);
    return movimiento;
  }

  Future<void> update(MovimientoFinanciero movimiento) async {
    final map = movimiento.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.update('movimientos_financieros', map,
        where: 'id = ?', whereArgs: [movimiento.id]);
  }

  Future<void> delete(String id) async {
    await _db.update('movimientos_financieros', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
