import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/caballo.dart';

class CaballoRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<Caballo>> getAll() async {
    final rows = await _db.query('caballos',
        where: 'deleted = 0', orderBy: 'nombre ASC');
    return rows.map(Caballo.fromMap).toList();
  }

  Future<Caballo?> getById(String id) async {
    final rows = await _db
        .query('caballos', where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Caballo.fromMap(rows.first);
  }

  Future<Caballo> create({
    required String nombre,
    String estado = 'activo',
  }) async {
    final now = DateTime.now();
    final caballo = Caballo(
      id: _uuid.v4(),
      nombre: nombre,
      estado: estado,
      createdAt: now,
      updatedAt: now,
    );
    final map = caballo.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.insert('caballos', map);
    return caballo;
  }

  Future<void> update(Caballo caballo) async {
    final map = caballo.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.update('caballos', map,
        where: 'id = ?', whereArgs: [caballo.id]);
  }

  Future<void> delete(String id) async {
    await _db.update('caballos', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
