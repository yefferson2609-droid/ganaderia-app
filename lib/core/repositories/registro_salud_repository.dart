import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/salud.dart';
import '../utils/auditoria.dart';

class RegistroSaludRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  String _hoy() => DateTime.now().toIso8601String().split('T')[0];

  Future<List<RegistroSalud>> getByAnimal(
      String animalTipo, String animalId) async {
    final rows = await _db.query('registros_salud',
        where: 'animal_tipo = ? AND animal_id = ? AND deleted = 0',
        whereArgs: [animalTipo, animalId],
        orderBy: 'fecha_inicio DESC');
    return rows.map(RegistroSalud.fromMap).toList();
  }

  Future<RegistroSalud?> getActivo(String animalTipo, String animalId) async {
    final rows = await _db.query('registros_salud',
        where:
            "animal_tipo = ? AND animal_id = ? AND estado = 'activo' AND deleted = 0",
        whereArgs: [animalTipo, animalId],
        orderBy: 'fecha_inicio DESC',
        limit: 1);
    if (rows.isEmpty) return null;
    return RegistroSalud.fromMap(rows.first);
  }

  /// Registros activos de todos los animales (animales en tratamiento).
  Future<List<RegistroSalud>> getEnTratamiento() async {
    final rows = await _db.query('registros_salud',
        where: "deleted = 0 AND estado = 'activo'",
        orderBy: 'fecha_inicio DESC');
    return rows.map(RegistroSalud.fromMap).toList();
  }

  Future<int> contarEnTratamiento() async {
    final r = await _db.rawQuery(
        "SELECT COUNT(*) as c FROM registros_salud WHERE deleted = 0 AND estado = 'activo'");
    return (r.first['c'] as int?) ?? 0;
  }

  Future<RegistroSalud> create({
    required String animalTipo,
    required String animalId,
    required DateTime fechaInicio,
    required String diagnostico,
  }) async {
    final now = DateTime.now();
    final registro = RegistroSalud(
      id: _uuid.v4(),
      animalTipo: animalTipo,
      animalId: animalId,
      fechaInicio: fechaInicio,
      diagnostico: diagnostico,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('registros_salud', filaNueva(registro.toMap()));
    return registro;
  }

  Future<void> marcarRecuperado(String registroId) async {
    await _db.update(
        'registros_salud',
        filaEditada({
          'estado': 'recuperado',
          'fecha_fin': _hoy(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        where: 'id = ?',
        whereArgs: [registroId]);
  }

  Future<void> delete(String registroId) async {
    await _db.update('registros_salud', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [registroId]);
    await _db.update('tratamientos_salud', {'deleted': 1, 'synced': 0},
        where: 'registro_salud_id = ?', whereArgs: [registroId]);
  }

  // Tratamientos
  Future<List<TratamientoSalud>> getTratamientos(String registroId) async {
    final rows = await _db.query('tratamientos_salud',
        where: 'registro_salud_id = ? AND deleted = 0',
        whereArgs: [registroId],
        orderBy: 'fecha DESC');
    return rows.map(TratamientoSalud.fromMap).toList();
  }

  /// Una fecha futura queda como dosis programada.
  Future<void> registrarTratamiento({
    required String registroId,
    required DateTime fecha,
    required String medicamento,
    String? dosis,
    String? notas,
  }) async {
    final hoy = DateTime.now();
    final esFutura =
        fecha.isAfter(DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59));
    final tratamiento = TratamientoSalud(
      id: _uuid.v4(),
      registroSaludId: registroId,
      fecha: fecha,
      medicamento: medicamento,
      dosis: dosis,
      notas: notas,
      estado: esFutura ? 'programado' : 'aplicado',
      createdBy: usuarioActualId(),
      createdAt: DateTime.now(),
    );
    await _db.insert('tratamientos_salud',
        filaNueva(tratamiento.toMap(), conAuditoria: false));
  }

  Future<void> marcarTratamientoAplicado(String tratamientoId) async {
    await _db.update('tratamientos_salud',
        {'estado': 'aplicado', 'fecha': _hoy(), 'synced': 0},
        where: 'id = ?', whereArgs: [tratamientoId]);
  }

  Future<void> deleteTratamiento(String id) async {
    await _db.update('tratamientos_salud', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Dosis programadas (pendientes de aplicar), con el animal al que van.
  Future<List<TratamientoSalud>> getDosisProgramadas() async {
    final rows = await _db.rawQuery('''
      SELECT t.*, r.animal_tipo, r.animal_id
      FROM tratamientos_salud t
      JOIN registros_salud r ON r.id = t.registro_salud_id
      WHERE t.deleted = 0 AND r.deleted = 0 AND t.estado = 'programado'
      ORDER BY t.fecha ASC
    ''');
    return rows.map(TratamientoSalud.fromMap).toList();
  }

  /// Dosis programadas cuya fecha ya llegó (hoy o antes).
  Future<int> contarDosisPendientes() async {
    final r = await _db.rawQuery(
        "SELECT COUNT(*) as c FROM tratamientos_salud WHERE deleted = 0 AND estado = 'programado' AND fecha <= ?",
        [_hoy()]);
    return (r.first['c'] as int?) ?? 0;
  }

  /// Tratamientos aplicados en un rango (para reportes).
  Future<List<TratamientoSalud>> getAplicados(
      {DateTime? desde, DateTime? hasta}) async {
    String where = "t.deleted = 0 AND t.estado = 'aplicado'";
    final args = <dynamic>[];
    if (desde != null) {
      where += ' AND t.fecha >= ?';
      args.add(desde.toIso8601String().split('T')[0]);
    }
    if (hasta != null) {
      where += ' AND t.fecha <= ?';
      args.add(hasta.toIso8601String().split('T')[0]);
    }
    final rows = await _db.rawQuery('''
      SELECT t.*, r.animal_tipo, r.animal_id
      FROM tratamientos_salud t
      JOIN registros_salud r ON r.id = t.registro_salud_id
      WHERE $where
      ORDER BY t.fecha DESC
    ''', args);
    return rows.map(TratamientoSalud.fromMap).toList();
  }
}
