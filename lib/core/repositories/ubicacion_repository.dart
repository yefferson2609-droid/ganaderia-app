import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/ubicacion.dart';

class UbicacionRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<Ubicacion>> getAll({bool soloActivas = false}) async {
    final where = soloActivas ? 'deleted = 0 AND activa = 1' : 'deleted = 0';
    final rows = await _db.query('ubicaciones',
        where: where, orderBy: 'nombre ASC');
    return rows.map(Ubicacion.fromMap).toList();
  }

  Future<Ubicacion?> getById(String id) async {
    final rows = await _db.query('ubicaciones',
        where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Ubicacion.fromMap(rows.first);
  }

  Future<Ubicacion> create({
    required String nombre,
    String? descripcion,
  }) async {
    final now = DateTime.now();
    final ub = Ubicacion(
      id: _uuid.v4(),
      nombre: nombre,
      descripcion: descripcion,
      activa: true,
      createdAt: now,
      updatedAt: now,
    );
    final map = ub.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.insert('ubicaciones', map);
    return ub;
  }

  Future<void> update(Ubicacion ub) async {
    final map = ub.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.update('ubicaciones', map,
        where: 'id = ?', whereArgs: [ub.id]);
  }

  Future<void> delete(String id) async {
    await _db.update('ubicaciones', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // Conteos por ubicación para dashboard
  Future<Map<String, dynamic>> getConteosPorUbicacion(String ubicacionId) async {
    final vacas = await _db.rawQuery(
        "SELECT COUNT(*) as c FROM vacas WHERE deleted=0 AND estado='activa' AND ubicacion_id=?",
        [ubicacionId]);
    final toros = await _db.rawQuery(
        "SELECT COUNT(*) as c FROM toros WHERE deleted=0 AND estado='activo' AND ubicacion_id=?",
        [ubicacionId]);
    final caballos = await _db.rawQuery(
        "SELECT COUNT(*) as c FROM caballos WHERE deleted=0 AND estado='activo' AND ubicacion_id=?",
        [ubicacionId]);
    final cerdos = await _db.rawQuery(
        "SELECT COALESCE(SUM(hembras+machos),0) as c FROM lotes WHERE deleted=0 AND tipo='cerdo' AND ubicacion_id=?",
        [ubicacionId]);
    final ovejos = await _db.rawQuery(
        "SELECT COALESCE(SUM(hembras+machos),0) as c FROM lotes WHERE deleted=0 AND tipo='ovejo' AND ubicacion_id=?",
        [ubicacionId]);

    return {
      'vacas': (vacas.first['c'] as int?) ?? 0,
      'toros': (toros.first['c'] as int?) ?? 0,
      'caballos': (caballos.first['c'] as int?) ?? 0,
      'cerdos': (cerdos.first['c'] as int?) ?? 0,
      'ovejos': (ovejos.first['c'] as int?) ?? 0,
    };
  }
}
