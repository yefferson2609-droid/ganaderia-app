import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../utils/auditoria.dart';
import '../models/lote.dart';
import '../models/movimiento_lote.dart';

class LoteRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<Lote>> getAll({String? tipo}) async {
    final where = tipo != null ? 'deleted = 0 AND tipo = ?' : 'deleted = 0';
    final rows = await _db.query('lotes',
        where: where,
        whereArgs: tipo != null ? [tipo] : null,
        orderBy: 'tipo ASC, nombre ASC');
    return rows.map(Lote.fromMap).toList();
  }

  Future<Lote?> getById(String id) async {
    final rows = await _db
        .query('lotes', where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Lote.fromMap(rows.first);
  }

  Future<Lote> create({
    required String tipo,
    required String nombre,
    required int hembras,
    required int machos,
  }) async {
    final now = DateTime.now();
    final lote = Lote(
      id: _uuid.v4(),
      tipo: tipo,
      nombre: nombre,
      hembras: hembras,
      machos: machos,
      createdAt: now,
      updatedAt: now,
    );
    final map = filaNueva(lote.toMap());
    await _db.insert('lotes', map);
    return lote;
  }

  Future<void> update(Lote lote) async {
    final map = filaEditada(lote.toMap());
    await _db.update('lotes', map, where: 'id = ?', whereArgs: [lote.id]);
  }

  Future<void> delete(String id) async {
    await _db.update('lotes', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // Movimientos
  Future<List<MovimientoLote>> getMovimientos(String loteId) async {
    final rows = await _db.query(
      'movimientos_lote',
      where: 'lote_id = ? AND deleted = 0',
      whereArgs: [loteId],
      orderBy: 'fecha DESC',
    );
    return rows.map(MovimientoLote.fromMap).toList();
  }

  Future<MovimientoLote> registrarBaja({
    required String loteId,
    required String tipoMovimiento,
    required int cantidad,
    required String sexo,
    required DateTime fecha,
    String? notas,
  }) async {
    // Actualizar conteo en el lote
    final lote = await getById(loteId);
    if (lote == null) throw Exception('Lote no encontrado');

    final nuevoHembras =
        sexo == 'hembra' ? (lote.hembras - cantidad).clamp(0, 9999) : lote.hembras;
    final nuevoMachos =
        sexo == 'macho' ? (lote.machos - cantidad).clamp(0, 9999) : lote.machos;

    await update(lote.copyWith(hembras: nuevoHembras, machos: nuevoMachos));

    final now = DateTime.now();
    final movimiento = MovimientoLote(
      id: _uuid.v4(),
      loteId: loteId,
      tipoMovimiento: tipoMovimiento,
      cantidad: cantidad,
      sexo: sexo,
      fecha: fecha,
      notas: notas,
      createdAt: now,
    );
    final map = filaNueva(movimiento.toMap(), conAuditoria: false);
    await _db.insert('movimientos_lote', map);
    return movimiento;
  }
}
