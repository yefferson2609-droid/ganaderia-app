import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/actividad.dart';
import '../utils/auditoria.dart';

class ActividadRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<Actividad>> getAll({String? estado, String? asignadoA}) async {
    String where = 'deleted = 0';
    final args = <dynamic>[];
    if (estado != null) {
      where += ' AND estado = ?';
      args.add(estado);
    }
    if (asignadoA != null) {
      where += ' AND asignado_a = ?';
      args.add(asignadoA);
    }
    final rows = await _db.query('actividades',
        where: where,
        whereArgs: args.isEmpty ? null : args,
        orderBy:
            "CASE prioridad WHEN 'alta' THEN 0 WHEN 'media' THEN 1 ELSE 2 END, "
            "COALESCE(fecha_limite, '9999-12-31') ASC, created_at DESC");
    return rows.map(Actividad.fromMap).toList();
  }

  Future<Actividad?> getById(String id) async {
    final rows = await _db.query('actividades',
        where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Actividad.fromMap(rows.first);
  }

  Future<void> create({
    required String descripcion,
    required String asignadoA,
    String prioridad = 'media',
    DateTime? fechaLimite,
    String? ubicacionId,
  }) async {
    final now = DateTime.now();
    final a = Actividad(
      id: _uuid.v4(),
      descripcion: descripcion,
      asignadoA: asignadoA,
      prioridad: prioridad,
      fechaLimite: fechaLimite,
      ubicacionId: ubicacionId,
      creadoPor: usuarioActualId(),
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('actividades', filaNueva(a.toMap(), conAuditoria: false));
  }

  Future<void> update(Actividad a) async {
    final map = a.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    await _db.update('actividades', filaEditada(map, conAuditoria: false),
        where: 'id = ?', whereArgs: [a.id]);
  }

  Future<void> marcarCompletada(String id) async {
    final now = DateTime.now().toIso8601String();
    await _db.update(
        'actividades',
        {
          'estado': 'completada',
          'completado_por': usuarioActualId(),
          'fecha_completada': now,
          'updated_at': now,
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> reabrir(String id) async {
    await _db.update(
        'actividades',
        {
          'estado': 'pendiente',
          'completado_por': null,
          'fecha_completada': null,
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    await _db.update('actividades', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> contarPendientesDe(String usuarioId) async {
    final r = await _db.rawQuery(
        "SELECT COUNT(*) as c FROM actividades WHERE deleted=0 AND estado='pendiente' AND asignado_a=?",
        [usuarioId]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> contarCompletadasDesde(DateTime desde) async {
    final r = await _db.rawQuery(
        "SELECT COUNT(*) as c FROM actividades WHERE deleted=0 AND estado='completada' AND fecha_completada >= ?",
        [desde.toIso8601String()]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<List<Actividad>> getCompletadasEnRango(
      {DateTime? desde, DateTime? hasta}) async {
    String where = "deleted = 0 AND estado = 'completada'";
    final args = <dynamic>[];
    if (desde != null) {
      where += ' AND fecha_completada >= ?';
      args.add(desde.toIso8601String());
    }
    if (hasta != null) {
      where += ' AND fecha_completada <= ?';
      args.add(DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59)
          .toIso8601String());
    }
    final rows = await _db.query('actividades',
        where: where, whereArgs: args, orderBy: 'fecha_completada DESC');
    return rows.map(Actividad.fromMap).toList();
  }
}
