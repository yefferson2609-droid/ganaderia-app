import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/ternero.dart';
import '../utils/auditoria.dart';
import 'toro_repository.dart';
import 'vaca_repository.dart';

class TerneroRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<Ternero>> getAll({
    String? etapa,
    bool soloActivos = false,
    String? ubicacionId,
  }) async {
    String where = 'deleted = 0';
    final args = <dynamic>[];
    if (soloActivos) where += " AND estado = 'activo'";
    if (etapa != null) {
      where += ' AND etapa = ?';
      args.add(etapa);
    }
    if (ubicacionId != null) {
      where += ' AND ubicacion_id = ?';
      args.add(ubicacionId);
    }
    final rows = await _db.query('terneros',
        where: where,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'numero ASC');
    return rows.map(Ternero.fromMap).toList();
  }

  Future<Ternero?> getById(String id) async {
    final rows = await _db
        .query('terneros', where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Ternero.fromMap(rows.first);
  }

  Future<bool> existeNumero(String numero, {String? excludeId}) async {
    final where = excludeId != null
        ? 'numero = ? AND id != ? AND deleted = 0'
        : 'numero = ? AND deleted = 0';
    final args = excludeId != null ? [numero, excludeId] : [numero];
    final rows = await _db.query('terneros', where: where, whereArgs: args);
    return rows.isNotEmpty;
  }

  Future<Ternero> create({
    required String numero,
    required String sexo,
    DateTime? fechaNacimiento,
    String etapa = 'lactancia',
    String? padreId,
    String? madreId,
    String? ubicacionId,
    String? color,
    String? nota,
  }) async {
    final now = DateTime.now();
    final ternero = Ternero(
      id: _uuid.v4(),
      numero: numero,
      sexo: sexo,
      fechaNacimiento: fechaNacimiento,
      etapa: etapa,
      padreId: padreId,
      madreId: madreId,
      ubicacionId: ubicacionId,
      color: color,
      nota: nota,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('terneros', filaNueva(ternero.toMap()));
    return ternero;
  }

  Future<void> update(Ternero ternero) async {
    await _db.update('terneros', filaEditada(ternero.toMap()),
        where: 'id = ?', whereArgs: [ternero.id]);
  }

  Future<void> delete(String id) async {
    await _db.update('terneros', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> avanzarEtapa(Ternero ternero, String nuevaEtapa) =>
      update(ternero.copyWith(etapa: nuevaEtapa));

  Future<void> marcarCapado(Ternero ternero) =>
      update(ternero.copyWith(capado: true));

  // Pesadas
  Future<List<PesadaTernero>> getPesadas(String terneroId) async {
    final rows = await _db.query('pesadas_ternero',
        where: 'ternero_id = ? AND deleted = 0',
        whereArgs: [terneroId],
        orderBy: 'fecha DESC, created_at DESC');
    return rows.map(PesadaTernero.fromMap).toList();
  }

  Future<void> registrarPesada({
    required String terneroId,
    required DateTime fecha,
    required double peso,
    String? notas,
  }) async {
    final pesada = PesadaTernero(
      id: _uuid.v4(),
      terneroId: terneroId,
      fecha: fecha,
      peso: peso,
      notas: notas,
      createdAt: DateTime.now(),
    );
    await _db.insert(
        'pesadas_ternero', filaNueva(pesada.toMap(), conAuditoria: false));
  }

  Future<void> deletePesada(String id) async {
    await _db.update('pesadas_ternero', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // Traslados
  Future<List<TrasladoTernero>> getTraslados(String terneroId) async {
    final rows = await _db.query('traslados_ternero',
        where: 'ternero_id = ? AND deleted = 0',
        whereArgs: [terneroId],
        orderBy: 'fecha DESC, created_at DESC');
    return rows.map(TrasladoTernero.fromMap).toList();
  }

  /// Registra el traslado y cambia la ubicación actual del ternero.
  Future<void> registrarTraslado({
    required Ternero ternero,
    required String destinoId,
    required DateTime fecha,
    String? notas,
  }) async {
    final traslado = TrasladoTernero(
      id: _uuid.v4(),
      terneroId: ternero.id,
      fecha: fecha,
      ubicacionOrigenId: ternero.ubicacionId,
      ubicacionDestinoId: destinoId,
      notas: notas,
      createdAt: DateTime.now(),
    );
    await _db.insert(
        'traslados_ternero', filaNueva(traslado.toMap(), conAuditoria: false));
    await update(ternero.copyWith(ubicacionId: destinoId));
  }

  /// Convierte una ternera en vaca. Devuelve el id de la vaca creada.
  Future<String> promoverAVaca(Ternero t) async {
    if (t.esMacho) {
      throw StateError('Solo una hembra puede promoverse a Vaca');
    }
    final vaca = await VacaRepository().create(
      numero: t.numero,
      fechaNacimiento: t.fechaNacimiento,
      padreId: t.padreId,
      madreId: t.madreId,
      ubicacionId: t.ubicacionId,
      color: t.color,
      nota: t.nota,
    );
    await delete(t.id);
    return vaca.id;
  }

  /// Convierte un macho (no capado) en toro. Devuelve el id del toro creado.
  Future<String> promoverAToro(Ternero t, {required String nombre}) async {
    if (!t.esMacho) {
      throw StateError('Solo un macho puede promoverse a Toro');
    }
    if (t.capado) {
      throw StateError('Un macho capado no puede promoverse a Toro');
    }
    final toro = await ToroRepository().create(
      numero: t.numero,
      nombre: nombre,
      fechaNacimiento: t.fechaNacimiento,
      padreId: t.padreId,
      madreId: t.madreId,
      ubicacionId: t.ubicacionId,
      color: t.color,
      nota: t.nota,
    );
    await delete(t.id);
    return toro.id;
  }
}
