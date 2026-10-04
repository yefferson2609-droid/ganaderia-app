import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_db.dart';
import '../models/perfil_usuario.dart';

class PerfilUsuarioRepository {
  final _db = LocalDb.instance.db;

  /// Usuarios vigentes (sin los eliminados).
  Future<List<PerfilUsuario>> getAll() async {
    final rows = await _db.query('perfiles_usuario',
        where: 'deleted = 0 AND eliminado = 0', orderBy: 'nombre ASC');
    return rows.map(PerfilUsuario.fromMap).toList();
  }

  /// Incluye eliminados: se usa para mostrar nombres en el historial.
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

  /// Elimina un usuario: bloquea su acceso, cierra sus sesiones y quita sus
  /// permisos (función `eliminar_usuario` en Supabase). Necesita internet.
  /// Lanza una excepción con un mensaje para mostrar si no se pudo.
  Future<void> eliminar(String id) async {
    try {
      await Supabase.instance.client
          .rpc('eliminar_usuario', params: {'p_usuario': id});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception(
          'No se pudo eliminar. Revisa la conexión a internet e intenta de nuevo.');
    }
    await _db.update('perfiles_usuario',
        {'eliminado': 1, 'activo': 0, 'synced': 1},
        where: 'id = ?', whereArgs: [id]);
    await _db.delete('permisos_usuario', where: 'usuario_id = ?', whereArgs: [id]);
  }
}
