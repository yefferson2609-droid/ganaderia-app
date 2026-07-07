import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/toro.dart';

class ToroRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<Toro>> getAll({bool soloActivos = false}) async {
    final where = soloActivos
        ? 'deleted = 0 AND estado = "activo"'
        : 'deleted = 0';
    final rows =
        await _db.query('toros', where: where, orderBy: 'numero ASC');
    return rows.map(Toro.fromMap).toList();
  }

  Future<Toro?> getById(String id) async {
    final rows = await _db
        .query('toros', where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Toro.fromMap(rows.first);
  }

  Future<Toro> create({
    required String numero,
    required String nombre,
    DateTime? fechaNacimiento,
    String estado = 'activo',
    String? padreId,
    String? madreId,
    String? ubicacionId,
  }) async {
    final now = DateTime.now();
    final toro = Toro(
      id: _uuid.v4(),
      numero: numero,
      nombre: nombre,
      fechaNacimiento: fechaNacimiento,
      estado: estado,
      padreId: padreId,
      madreId: madreId,
      ubicacionId: ubicacionId,
      createdAt: now,
      updatedAt: now,
    );
    final map = toro.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.insert('toros', map);
    return toro;
  }

  Future<void> update(Toro toro) async {
    final map = toro.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.update('toros', map, where: 'id = ?', whereArgs: [toro.id]);
  }

  Future<void> delete(String id) async {
    await _db.update('toros', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> existeNumero(String numero, {String? excludeId}) async {
    final where = excludeId != null
        ? 'numero = ? AND id != ? AND deleted = 0'
        : 'numero = ? AND deleted = 0';
    final args = excludeId != null ? [numero, excludeId] : [numero];
    final rows = await _db.query('toros', where: where, whereArgs: args);
    return rows.isNotEmpty;
  }
}
