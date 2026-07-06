import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/evento_vaca.dart';

class EventoVacaRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<EventoVaca>> getByVaca(String vacaId) async {
    final rows = await _db.rawQuery('''
      SELECT ev.*, te.nombre AS tipo_evento_nombre
      FROM eventos_vaca ev
      LEFT JOIN tipos_evento te ON te.id = ev.tipo_evento_id
      WHERE ev.vaca_id = ? AND ev.deleted = 0
      ORDER BY ev.fecha DESC
    ''', [vacaId]);
    return rows.map(EventoVaca.fromMap).toList();
  }

  Future<EventoVaca> create({
    required String vacaId,
    required String tipoEventoId,
    required DateTime fecha,
    String? notas,
  }) async {
    final now = DateTime.now();
    final evento = EventoVaca(
      id: _uuid.v4(),
      vacaId: vacaId,
      tipoEventoId: tipoEventoId,
      fecha: fecha,
      notas: notas,
      createdAt: now,
      updatedAt: now,
    );
    final map = evento.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.insert('eventos_vaca', map);
    return evento;
  }

  Future<void> delete(String id) async {
    await _db.update('eventos_vaca', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
