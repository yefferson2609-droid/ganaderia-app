import '../database/local_db.dart';
import '../models/perfil_usuario.dart';

class PerfilUsuarioRepository {
  final _db = LocalDb.instance.db;

  Future<List<PerfilUsuario>> getAll() async {
    final rows = await _db.query('perfiles_usuario',
        where: 'deleted = 0', orderBy: 'nombre ASC');
    return rows.map(PerfilUsuario.fromMap).toList();
  }

  Future<PerfilUsuario?> getById(String id) async {
    final rows = await _db.query('perfiles_usuario',
        where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PerfilUsuario.fromMap(rows.first);
  }

  Future<void> update(PerfilUsuario perfil) async {
    final map = perfil.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.update('perfiles_usuario', map,
        where: 'id = ?', whereArgs: [perfil.id]);
  }
}
