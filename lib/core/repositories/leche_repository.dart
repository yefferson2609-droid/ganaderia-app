import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/produccion_leche.dart';
import '../utils/auditoria.dart';

String _dia(DateTime f) => f.toIso8601String().split('T')[0];

class LecheRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  /// Registro de la finca para ese día y turno, si existe.
  Future<ProduccionLeche?> getFinca(DateTime fecha, String turno) async {
    final rows = await _db.query('produccion_leche',
        where: 'deleted = 0 AND vaca_id IS NULL AND fecha = ? AND turno = ?',
        whereArgs: [_dia(fecha), turno],
        limit: 1);
    return rows.isEmpty ? null : ProduccionLeche.fromMap(rows.first);
  }

  /// Guarda el total de la finca de un ordeño (crea o reemplaza).
  Future<void> guardarFinca({
    required DateTime fecha,
    required String turno,
    required double litros,
    String? notas,
  }) async {
    final existente = await getFinca(fecha, turno);
    final now = DateTime.now();
    if (existente != null) {
      await _db.update(
          'produccion_leche',
          filaEditada({
            'litros': litros,
            'notas': notas,
            'updated_at': now.toIso8601String(),
          }, conAuditoria: false),
          where: 'id = ?',
          whereArgs: [existente.id]);
      return;
    }
    await _insertar(ProduccionLeche(
      id: _uuid.v4(),
      fecha: fecha,
      turno: turno,
      litros: litros,
      notas: notas,
      createdBy: usuarioActualId(),
      createdAt: now,
      updatedAt: now,
    ));
  }

  /// Registra la leche de una vaca en un ordeño (crea o reemplaza).
  Future<void> guardarVaca({
    required String vacaId,
    required DateTime fecha,
    required String turno,
    required double litros,
  }) async {
    final rows = await _db.query('produccion_leche',
        where: 'deleted = 0 AND vaca_id = ? AND fecha = ? AND turno = ?',
        whereArgs: [vacaId, _dia(fecha), turno],
        limit: 1);
    final now = DateTime.now();
    if (rows.isNotEmpty) {
      await _db.update(
          'produccion_leche',
          filaEditada({'litros': litros, 'updated_at': now.toIso8601String()},
              conAuditoria: false),
          where: 'id = ?',
          whereArgs: [rows.first['id']]);
      return;
    }
    await _insertar(ProduccionLeche(
      id: _uuid.v4(),
      fecha: fecha,
      turno: turno,
      litros: litros,
      vacaId: vacaId,
      createdBy: usuarioActualId(),
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> _insertar(ProduccionLeche p) async {
    final map = p.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.insert('produccion_leche', map);
  }

  Future<void> delete(String id) async {
    await _db.update('produccion_leche', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Totales diarios de la finca entre dos fechas (días sin registro = 0).
  Future<List<LecheDia>> diasFinca(DateTime desde, DateTime hasta) async {
    final rows = await _db.rawQuery('''
      SELECT fecha,
        SUM(CASE WHEN turno = 'manana' THEN litros ELSE 0 END) AS manana,
        SUM(CASE WHEN turno = 'tarde' THEN litros ELSE 0 END) AS tarde
      FROM produccion_leche
      WHERE deleted = 0 AND vaca_id IS NULL AND fecha >= ? AND fecha <= ?
      GROUP BY fecha
    ''', [_dia(desde), _dia(hasta)]);
    final porDia = {
      for (final r in rows)
        r['fecha'] as String: (
          (r['manana'] as num?)?.toDouble() ?? 0,
          (r['tarde'] as num?)?.toDouble() ?? 0,
        )
    };
    final dias = <LecheDia>[];
    for (var d = DateTime(desde.year, desde.month, desde.day);
        !d.isAfter(hasta);
        d = d.add(const Duration(days: 1))) {
      final v = porDia[_dia(d)];
      dias.add(LecheDia(d, v?.$1 ?? 0, v?.$2 ?? 0));
    }
    return dias;
  }

  /// Promedio diario de litros por vaca en los últimos [dias] días.
  Future<Map<String, double>> promedioPorVaca({int dias = 30}) async {
    final desde = DateTime.now().subtract(Duration(days: dias));
    final rows = await _db.rawQuery('''
      SELECT vaca_id, SUM(litros) AS total, COUNT(DISTINCT fecha) AS dias
      FROM produccion_leche
      WHERE deleted = 0 AND vaca_id IS NOT NULL AND fecha >= ?
      GROUP BY vaca_id
    ''', [_dia(desde)]);
    return {
      for (final r in rows)
        r['vaca_id'] as String: ((r['total'] as num).toDouble()) /
            ((r['dias'] as int?) ?? 1).clamp(1, 9999),
    };
  }

  /// Últimos registros de una vaca.
  Future<List<ProduccionLeche>> getByVaca(String vacaId, {int limite = 20}) async {
    final rows = await _db.query('produccion_leche',
        where: 'deleted = 0 AND vaca_id = ?',
        whereArgs: [vacaId],
        orderBy: 'fecha DESC, turno DESC',
        limit: limite);
    return rows.map(ProduccionLeche.fromMap).toList();
  }
}
