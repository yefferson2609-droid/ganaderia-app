import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../utils/auditoria.dart';

class PesajeAnimal {
  final String id;
  final DateTime fecha;
  final double peso;
  final String? notas;
  const PesajeAnimal(this.id, this.fecha, this.peso, this.notas);
}

/// Pesajes de animales adultos (vacas, toros, caballos).
class PesajeRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<PesajeAnimal>> getByAnimal(String tipo, String id) async {
    final rows = await _db.query('pesajes_animal',
        where: 'animal_tipo = ? AND animal_id = ? AND deleted = 0',
        whereArgs: [tipo, id],
        orderBy: 'fecha DESC, created_at DESC');
    return rows
        .map((r) => PesajeAnimal(
              r['id'] as String,
              DateTime.parse(r['fecha'] as String),
              (r['peso'] as num).toDouble(),
              r['notas'] as String?,
            ))
        .toList();
  }

  Future<void> registrar({
    required String tipo,
    required String animalId,
    required DateTime fecha,
    required double peso,
    String? notas,
  }) async {
    await _db.insert(
        'pesajes_animal',
        filaNueva({
          'id': _uuid.v4(),
          'animal_tipo': tipo,
          'animal_id': animalId,
          'fecha': fecha.toIso8601String().split('T')[0],
          'peso': peso,
          'notas': notas,
          'created_by': usuarioActualId(),
          'created_at': DateTime.now().toIso8601String(),
        }, conAuditoria: false));
  }

  Future<void> delete(String id) async {
    await _db.update('pesajes_animal', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
