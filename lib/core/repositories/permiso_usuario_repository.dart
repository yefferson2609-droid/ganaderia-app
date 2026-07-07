import '../database/local_db.dart';
import '../models/permiso_usuario.dart';

class PermisoUsuarioRepository {
  final _db = LocalDb.instance.db;

  Future<List<PermisoUsuario>> getByUsuario(String usuarioId) async {
    final rows = await _db.query('permisos_usuario',
        where: 'usuario_id = ? AND deleted = 0', whereArgs: [usuarioId]);
    return rows.map(PermisoUsuario.fromMap).toList();
  }

  Future<void> update(PermisoUsuario permiso) async {
    final map = permiso.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.update('permisos_usuario', map,
        where: 'id = ?', whereArgs: [permiso.id]);
  }
}
