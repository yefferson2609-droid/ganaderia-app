import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/ternero.dart';
import '../utils/auditoria.dart';
import '../config/ajustes.dart';
import 'reproduccion_repository.dart';
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
    String? categoria,
    DateTime? fechaDestete,
    bool capado = false,
    String? padreId,
    String? madreId,
    String? ubicacionId,
    String? color,
    String? raza,
    String? nota,
  }) async {
    final now = DateTime.now();
    final ternero = Ternero(
      id: _uuid.v4(),
      numero: numero,
      sexo: sexo,
      fechaNacimiento: fechaNacimiento,
      etapa: categoria != null ? etapaDeCategoria(categoria) : etapa,
      categoria: categoria,
      fechaDestete: fechaDestete,
      capado: capado,
      padreId: padreId,
      madreId: madreId,
      ubicacionId: ubicacionId,
      color: color,
      raza: raza,
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

  Future<void> cambiarCategoria(Ternero t, String categoria) =>
      update(t.copyWith(categoria: categoria));

  /// Capar: un macho ya destetado pasa a novillo de ceba.
  Future<void> marcarCapado(Ternero t) {
    final cat = t.categoriaActual;
    return update(t.copyWith(
      capado: true,
      categoria: (cat == 'torete' || cat == 'torete_venta') ? 'novillo_ceba' : cat,
    ));
  }

  /// Destete: la ternera pasa a novilla de levante (o de vientre si ya
  /// tiene la edad); el macho a torete, o novillo de ceba si está capado.
  Future<void> registrarDestete(Ternero t, DateTime fecha) {
    final String categoria;
    if (!t.esMacho) {
      categoria = (t.meses ?? 0) >= kMesesNovillaVientre
          ? 'novilla_vientre'
          : 'novilla_levante';
    } else {
      categoria = t.capado ? 'novillo_ceba' : 'torete';
    }
    return update(t.copyWith(fechaDestete: fecha, categoria: categoria));
  }

  /// Clasifica de una vez los animales sin categoría con la sugerida.
  Future<int> clasificarPendientes() async {
    var n = 0;
    for (final t in await getAll(soloActivos: true)) {
      if (t.categoria == null) {
        await update(t.copyWith(categoria: t.categoriaSugerida));
        n++;
      }
    }
    return n;
  }

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
  /// Pasa una novilla a Vacas. Si se indica [prenadaMeses] (o [prenada]),
  /// queda registrada como preñada con su fecha estimada de parto, igual
  /// que en una palpación.
  Future<String> promoverAVaca(
    Ternero t, {
    bool prenada = false,
    int? prenadaMeses,
    DateTime? fechaChequeo,
    String? notas,
  }) async {
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
      raza: t.raza,
      nota: t.nota,
    );
    // La foto la acompaña.
    if (t.fotoLocal != null || t.fotoUrl != null) {
      await _db.update(
          'vacas', {'foto_local': t.fotoLocal, 'foto_url': t.fotoUrl},
          where: 'id = ?', whereArgs: [vaca.id]);
    }
    if (prenada || prenadaMeses != null) {
      await ReproduccionRepository().registrarPalpacion(
        vaca: (await VacaRepository().getById(vaca.id))!,
        fecha: fechaChequeo ?? DateTime.now(),
        prenada: true,
        meses: prenadaMeses,
        notas: notas,
      );
    }
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
      raza: t.raza,
      nota: t.nota,
    );
    await delete(t.id);
    return toro.id;
  }
}
