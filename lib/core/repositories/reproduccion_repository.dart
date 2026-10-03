import '../database/local_db.dart';
import '../models/vaca.dart';
import 'evento_vaca_repository.dart';
import 'ternero_repository.dart';
import 'tipo_evento_repository.dart';
import 'vaca_repository.dart';

/// Partos y secados se guardan como eventos de la vaca (tipos "Parto" y
/// "Secado"), así funcionan también desde Evento masivo y no necesitan
/// tablas nuevas en el servidor.
const kTipoParto = 'Parto';
const kTipoSecado = 'Secado';

// Condiciones SQL sobre el nombre del tipo de evento (alias t).
const _esParto = "lower(t.nombre) LIKE 'parto%'";
const _esSecado = "lower(t.nombre) LIKE 'secad%'";
const _esVitamina = "lower(t.nombre) LIKE '%vitamin%'";

enum EstadoProduccion { enOrdeno, seca, sinPartos }

const kEstadoProduccionLabels = {
  EstadoProduccion.enOrdeno: 'En ordeño',
  EstadoProduccion.seca: 'Seca',
  EstadoProduccion.sinPartos: 'Sin partos',
};

class ResumenReproductivo {
  final List<DateTime> partos; // de más antiguo a más reciente
  final DateTime? ultimoSecado;
  final DateTime? ultimaVitamina;
  final String? ultimaVitaminaNombre;

  const ResumenReproductivo({
    required this.partos,
    this.ultimoSecado,
    this.ultimaVitamina,
    this.ultimaVitaminaNombre,
  });

  DateTime? get ultimoParto => partos.isEmpty ? null : partos.last;

  /// Días entre cada parto y el anterior.
  List<int> get intervalos => [
        for (var i = 1; i < partos.length; i++)
          partos[i].difference(partos[i - 1]).inDays
      ];

  int? get intervaloPromedio {
    final l = intervalos;
    if (l.isEmpty) return null;
    return (l.reduce((a, b) => a + b) / l.length).round();
  }

  EstadoProduccion get estado => estadoProduccion(ultimoParto, ultimoSecado);

  /// Días en leche (desde el último parto) si está en ordeño.
  int? get diasEnLeche => estado == EstadoProduccion.enOrdeno
      ? DateTime.now().difference(ultimoParto!).inDays
      : null;
}

EstadoProduccion estadoProduccion(DateTime? ultimoParto, DateTime? ultimoSecado) {
  if (ultimoParto == null) return EstadoProduccion.sinPartos;
  if (ultimoSecado != null && !ultimoSecado.isBefore(ultimoParto)) {
    return EstadoProduccion.seca;
  }
  return EstadoProduccion.enOrdeno;
}

class ReproduccionRepository {
  final _db = LocalDb.instance.db;

  /// Id del tipo de evento con ese nombre; lo crea si no existe.
  Future<String> _tipoId(String nombre) async {
    final rows = await _db.rawQuery(
        'SELECT id FROM tipos_evento WHERE deleted = 0 AND lower(nombre) = lower(?) LIMIT 1',
        [nombre]);
    if (rows.isNotEmpty) return rows.first['id'] as String;
    final tipo = await TipoEventoRepository().create(
        nombre: nombre, descripcion: 'Creado automáticamente');
    return tipo.id;
  }

  DateTime? _fecha(Object? v) => v == null ? null : DateTime.tryParse(v as String);

  Future<ResumenReproductivo> resumen(String vacaId) async {
    final partos = await _db.rawQuery('''
      SELECT e.fecha FROM eventos_vaca e
      JOIN tipos_evento t ON t.id = e.tipo_evento_id
      WHERE e.vaca_id = ? AND e.deleted = 0 AND $_esParto
      ORDER BY e.fecha ASC
    ''', [vacaId]);
    final secado = await _db.rawQuery('''
      SELECT MAX(e.fecha) AS f FROM eventos_vaca e
      JOIN tipos_evento t ON t.id = e.tipo_evento_id
      WHERE e.vaca_id = ? AND e.deleted = 0 AND $_esSecado
    ''', [vacaId]);
    final vitamina = await _db.rawQuery('''
      SELECT e.fecha, t.nombre FROM eventos_vaca e
      JOIN tipos_evento t ON t.id = e.tipo_evento_id
      WHERE e.vaca_id = ? AND e.deleted = 0 AND $_esVitamina
      ORDER BY e.fecha DESC LIMIT 1
    ''', [vacaId]);

    // Varios partos el mismo día (p. ej. gemelos) cuentan como uno.
    final fechas = <DateTime>[];
    for (final r in partos) {
      final f = _fecha(r['fecha'])!;
      if (fechas.isEmpty || fechas.last != f) fechas.add(f);
    }
    return ResumenReproductivo(
      partos: fechas,
      ultimoSecado: _fecha(secado.first['f']),
      ultimaVitamina: vitamina.isEmpty ? null : _fecha(vitamina.first['fecha']),
      ultimaVitaminaNombre:
          vitamina.isEmpty ? null : vitamina.first['nombre'] as String?,
    );
  }

  /// Cuántas vacas activas están en ordeño, secas y sin partos.
  Future<Map<EstadoProduccion, int>> conteoProduccion({String? ubicacionId}) async {
    final filtro = ubicacionId != null ? ' AND v.ubicacion_id = ?' : '';
    final rows = await _db.rawQuery('''
      SELECT v.id,
        (SELECT MAX(e.fecha) FROM eventos_vaca e
           JOIN tipos_evento t ON t.id = e.tipo_evento_id
           WHERE e.vaca_id = v.id AND e.deleted = 0 AND $_esParto) AS parto,
        (SELECT MAX(e.fecha) FROM eventos_vaca e
           JOIN tipos_evento t ON t.id = e.tipo_evento_id
           WHERE e.vaca_id = v.id AND e.deleted = 0 AND $_esSecado) AS secado
      FROM vacas v
      WHERE v.deleted = 0 AND v.estado = 'activa'$filtro
    ''', ubicacionId != null ? [ubicacionId] : null);
    final conteo = {for (final e in EstadoProduccion.values) e: 0};
    for (final r in rows) {
      final e = estadoProduccion(_fecha(r['parto']), _fecha(r['secado']));
      conteo[e] = conteo[e]! + 1;
    }
    return conteo;
  }

  /// Registra el parto, deja la vaca vacía y opcionalmente crea el ternero.
  /// Devuelve el id del ternero creado (o null).
  Future<String?> registrarParto({
    required Vaca vaca,
    required DateTime fecha,
    String? notas,
    String? numeroTernero,
    String? sexoTernero,
  }) async {
    await EventoVacaRepository().create(
      vacaId: vaca.id,
      tipoEventoId: await _tipoId(kTipoParto),
      fecha: fecha,
      notas: notas,
    );

    String? terneroId;
    if (numeroTernero != null && sexoTernero != null) {
      final t = await TerneroRepository().create(
        numero: numeroTernero,
        sexo: sexoTernero,
        fechaNacimiento: fecha,
        madreId: vaca.id,
        padreId: vaca.toroId,
        ubicacionId: vaca.ubicacionId,
      );
      terneroId = t.id;
    }

    await VacaRepository().update(vaca.copyWith(
      estadoReproductivo: 'vacia',
      clearFechaMonta: true,
      clearToroId: true,
      clearFechaParto: true,
    ));
    return terneroId;
  }

  Future<void> secar({
    required String vacaId,
    required DateTime fecha,
    String? notas,
  }) async {
    await EventoVacaRepository().create(
      vacaId: vacaId,
      tipoEventoId: await _tipoId(kTipoSecado),
      fecha: fecha,
      notas: notas,
    );
  }
}
