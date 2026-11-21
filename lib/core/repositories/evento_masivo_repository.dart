import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import 'evento_animal_repository.dart';

class EventoMasivoRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  /// Registra un evento para varias vacas ([vacaIds]) y para otros animales
  /// ([otros]: toros, levante y ceba, caballos, como (tipo, id)). Cada uno
  /// queda en el historial de su ficha.
  Future<void> registrar({
    required String tipoEventoId,
    required List<String> vacaIds,
    List<(String, String)> otros = const [],
    required DateTime fecha,
    String? notas,
  }) async {
    for (final (tipo, id) in otros) {
      await EventoAnimalRepository().create(
          animalTipo: tipo,
          animalId: id,
          tipoEventoId: tipoEventoId,
          fecha: fecha,
          notas: notas);
    }
    if (vacaIds.isEmpty) return;
    final now = DateTime.now();
    final eventoId = _uuid.v4();

    // Insertar evento masivo
    await _db.insert('eventos_masivos', {
      'id': eventoId,
      'tipo_evento_id': tipoEventoId,
      'fecha': fecha.toIso8601String().split('T')[0],
      'notas': notas,
      'created_at': now.toIso8601String(),
      'synced': 0,
      'deleted': 0,
    });

    // Insertar relación con cada vaca + crear evento individual en historial
    for (final vacaId in vacaIds) {
      await _db.insert('eventos_masivos_vacas', {
        'id': _uuid.v4(),
        'evento_masivo_id': eventoId,
        'vaca_id': vacaId,
        'created_at': now.toIso8601String(),
        'synced': 0,
        'deleted': 0,
      });

      // También registrar en historial individual de la vaca
      await _db.insert('eventos_vaca', {
        'id': _uuid.v4(),
        'vaca_id': vacaId,
        'tipo_evento_id': tipoEventoId,
        'fecha': fecha.toIso8601String().split('T')[0],
        'notas': notas,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'synced': 0,
        'deleted': 0,
      });
    }
  }
}
