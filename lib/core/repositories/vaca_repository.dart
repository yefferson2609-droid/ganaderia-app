import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/vaca.dart';

class VacaRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<Vaca>> getAll({bool soloActivas = false, String? ubicacionId}) async {
    String where = 'deleted = 0';
    List<dynamic> args = [];
    if (soloActivas) { where += ' AND estado = "activa"'; }
    if (ubicacionId != null) { where += ' AND ubicacion_id = ?'; args.add(ubicacionId); }
    final rows = await _db.query('vacas', where: where, whereArgs: args.isEmpty ? null : args, orderBy: 'numero ASC');
    return rows.map(Vaca.fromMap).toList();
  }

  Future<Vaca?> getById(String id) async {
    final rows = await _db.query('vacas', where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Vaca.fromMap(rows.first);
  }

  Future<Vaca> create({
    required String numero,
    DateTime? fechaNacimiento,
    String estado = 'activa',
    String? padreId,
    String? madreId,
    String estadoReproductivo = 'vacia',
    DateTime? fechaMonta,
    String? toroId,
    DateTime? fechaEstimadaParto,
    String? ubicacionId,
  }) async {
    final now = DateTime.now();
    final vaca = Vaca(
      id: _uuid.v4(),
      numero: numero,
      fechaNacimiento: fechaNacimiento,
      estado: estado,
      padreId: padreId,
      madreId: madreId,
      estadoReproductivo: estadoReproductivo,
      fechaMonta: fechaMonta,
      toroId: toroId,
      fechaEstimadaParto: fechaEstimadaParto,
      ubicacionId: ubicacionId,
      createdAt: now,
      updatedAt: now,
    );
    final map = vaca.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.insert('vacas', map);
    return vaca;
  }

  Future<void> update(Vaca vaca) async {
    final map = vaca.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.update('vacas', map, where: 'id = ?', whereArgs: [vaca.id]);
  }

  Future<void> delete(String id) async {
    await _db.update('vacas', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> existeNumero(String numero, {String? excludeId}) async {
    final where = excludeId != null
        ? 'numero = ? AND id != ? AND deleted = 0'
        : 'numero = ? AND deleted = 0';
    final args = excludeId != null ? [numero, excludeId] : [numero];
    final rows = await _db.query('vacas', where: where, whereArgs: args);
    return rows.isNotEmpty;
  }
}
