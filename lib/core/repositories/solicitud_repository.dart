import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/solicitud.dart';
import '../utils/auditoria.dart';
import 'movimiento_financiero_repository.dart';

class SolicitudRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<Solicitud>> getAll({String? estado, String? solicitadoPor}) async {
    String where = 'deleted = 0';
    final args = <dynamic>[];
    if (estado != null) {
      where += ' AND estado = ?';
      args.add(estado);
    }
    if (solicitadoPor != null) {
      where += ' AND solicitado_por = ?';
      args.add(solicitadoPor);
    }
    final rows = await _db.query('solicitudes',
        where: where,
        whereArgs: args.isEmpty ? null : args,
        orderBy:
            "CASE estado WHEN 'pendiente' THEN 0 WHEN 'aprobada' THEN 1 ELSE 2 END, created_at DESC");
    return rows.map(Solicitud.fromMap).toList();
  }

  Future<void> create({
    required String item,
    String? cantidad,
    String? ubicacionId,
    String? nota,
  }) async {
    final now = DateTime.now();
    final s = Solicitud(
      id: _uuid.v4(),
      item: item,
      cantidad: cantidad,
      ubicacionId: ubicacionId,
      nota: nota,
      solicitadoPor: usuarioActualId(),
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('solicitudes', filaNueva(s.toMap(), conAuditoria: false));
  }

  Future<void> _resolver(String id, String estado, {double? costo}) async {
    final now = DateTime.now().toIso8601String();
    await _db.update(
        'solicitudes',
        {
          'estado': estado,
          'resuelto_por': usuarioActualId(),
          'fecha_resolucion': now,
          'updated_at': now,
          if (costo != null) 'costo': costo,
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> aprobar(String id) => _resolver(id, 'aprobada');

  Future<void> rechazar(String id) => _resolver(id, 'rechazada');

  /// Marca la solicitud como completada (comprada) y registra el gasto.
  Future<void> completar(Solicitud s, {required double costo}) async {
    await _resolver(s.id, 'completada', costo: costo);
    if (costo > 0) {
      await MovimientoFinancieroRepository().create(
        tipo: 'gasto',
        nota: 'Solicitud: ${s.item}${s.cantidad != null ? ' (${s.cantidad})' : ''}',
        monto: costo,
        fecha: DateTime.now(),
        ubicacionId: s.ubicacionId,
      );
    }
  }

  Future<void> delete(String id) async {
    await _db.update('solicitudes', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> contarPendientes() async {
    final r = await _db.rawQuery(
        "SELECT COUNT(*) as c FROM solicitudes WHERE deleted=0 AND estado='pendiente'");
    return (r.first['c'] as int?) ?? 0;
  }

  /// Solicitudes de un usuario resueltas desde una fecha (para avisos).
  Future<int> contarResueltasDe(String usuarioId, DateTime desde) async {
    final r = await _db.rawQuery(
        "SELECT COUNT(*) as c FROM solicitudes WHERE deleted=0 AND estado != 'pendiente' AND solicitado_por=? AND fecha_resolucion >= ?",
        [usuarioId, desde.toIso8601String()]);
    return (r.first['c'] as int?) ?? 0;
  }
}
