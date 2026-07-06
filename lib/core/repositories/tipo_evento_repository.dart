import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/tipo_evento.dart';

class TipoEventoRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<TipoEvento>> getAll({bool soloActivos = false}) async {
    final where =
        soloActivos ? 'deleted = 0 AND activo = 1' : 'deleted = 0';
    final rows = await _db.query('tipos_evento',
        where: where, orderBy: 'nombre ASC');
    return rows.map(TipoEvento.fromMap).toList();
  }

  Future<TipoEvento?> getById(String id) async {
    final rows = await _db.query('tipos_evento',
        where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TipoEvento.fromMap(rows.first);
  }

  Future<TipoEvento> create({
    required String nombre,
    String? descripcion,
  }) async {
    final now = DateTime.now();
    final tipo = TipoEvento(
      id: _uuid.v4(),
      nombre: nombre,
      descripcion: descripcion,
      activo: true,
      createdAt: now,
      updatedAt: now,
    );
    final map = tipo.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.insert('tipos_evento', map);
    return tipo;
  }

  Future<void> update(TipoEvento tipo) async {
    final map = tipo.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.update('tipos_evento', map,
        where: 'id = ?', whereArgs: [tipo.id]);
  }

  Future<void> delete(String id) async {
    await _db.update('tipos_evento', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
