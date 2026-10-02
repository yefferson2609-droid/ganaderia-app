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

  /// Conteos de animales activos. Con [ubicacionId] null cuenta los que no
  /// tienen ubicación; con [todas] cuenta todos sin filtrar por ubicación.
  Future<Map<String, int>> getConteosPorUbicacion(String? ubicacionId,
      {bool todas = false}) async {
    final filtro = todas
        ? ''
        : ubicacionId == null
            ? ' AND ubicacion_id IS NULL'
            : ' AND ubicacion_id=?';
    final args = (todas || ubicacionId == null) ? null : [ubicacionId];

    Future<int> contar(String sql) async {
      final r = await _db.rawQuery('$sql$filtro', args);
      return (r.first['c'] as int?) ?? 0;
    }

    return {
      'vacas': await contar(
          "SELECT COUNT(*) as c FROM vacas WHERE deleted=0 AND estado='activa'"),
      'toros': await contar(
          "SELECT COUNT(*) as c FROM toros WHERE deleted=0 AND estado='activo'"),
      'terneros': await contar(
          "SELECT COUNT(*) as c FROM terneros WHERE deleted=0 AND estado='activo'"),
      'caballos': await contar(
          "SELECT COUNT(*) as c FROM caballos WHERE deleted=0 AND estado='activo'"),
      'cerdos': await contar(
          "SELECT COALESCE(SUM(hembras+machos),0) as c FROM lotes WHERE deleted=0 AND tipo='cerdo'"),
      'ovejos': await contar(
          "SELECT COALESCE(SUM(hembras+machos),0) as c FROM lotes WHERE deleted=0 AND tipo='ovejo'"),
    };
  }
}
