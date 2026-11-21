import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../utils/auditoria.dart';

/// Evento del historial de un toro, animal de levante y ceba o caballo
/// (las vacas usan eventos_vaca).
class EventoAnimal {
  final String id;
  final String animalTipo; // 'toro' | 'ternero' | 'caballo'
  final String animalId;
  final String tipoEventoId;
  final String? tipoEventoNombre; // join local
  final DateTime fecha;
  final String? notas;

  const EventoAnimal({
    required this.id,
    required this.animalTipo,
    required this.animalId,
    required this.tipoEventoId,
    this.tipoEventoNombre,
    required this.fecha,
    this.notas,
  });

  factory EventoAnimal.fromMap(Map<String, dynamic> m) => EventoAnimal(
        id: m['id'] as String,
        animalTipo: m['animal_tipo'] as String,
        animalId: m['animal_id'] as String,
        tipoEventoId: m['tipo_evento_id'] as String,
        tipoEventoNombre: m['tipo_evento_nombre'] as String?,
        fecha: DateTime.parse(m['fecha'] as String),
        notas: m['notas'] as String?,
      );
}

class EventoAnimalRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<EventoAnimal>> getByAnimal(String tipo, String id) async {
    final rows = await _db.rawQuery('''
      SELECT ea.*, te.nombre AS tipo_evento_nombre
      FROM eventos_animal ea
      LEFT JOIN tipos_evento te ON te.id = ea.tipo_evento_id
      WHERE ea.animal_tipo = ? AND ea.animal_id = ? AND ea.deleted = 0
      ORDER BY ea.fecha DESC, ea.created_at DESC
    ''', [tipo, id]);
    return rows.map(EventoAnimal.fromMap).toList();
  }

  Future<void> create({
    required String animalTipo,
    required String animalId,
    required String tipoEventoId,
    required DateTime fecha,
    String? notas,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.insert('eventos_animal', {
      'id': _uuid.v4(),
      'animal_tipo': animalTipo,
      'animal_id': animalId,
      'tipo_evento_id': tipoEventoId,
      'fecha': fecha.toIso8601String().split('T')[0],
      'notas': notas,
      'created_by': usuarioActualId(),
      'created_at': now,
      'updated_at': now,
      'synced': 0,
      'deleted': 0,
    });
  }

  Future<void> delete(String id) async {
    await _db.update('eventos_animal', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
