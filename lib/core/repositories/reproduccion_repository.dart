import '../config/ajustes.dart';
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
const kTipoPalpacion = 'Palpación';

// Condiciones SQL sobre el nombre del tipo de evento (alias t).
const _esParto = "lower(t.nombre) LIKE 'parto%'";
const _esSecado = "lower(t.nombre) LIKE 'secad%'";
const _esVitamina = "lower(t.nombre) LIKE '%vitamin%'";

const _toroDeLaMonta = Object();

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

class PromediosCiclo {
  final int? diasLactancia; // días en ordeño (parto → secado)
  final int? diasSeco; // días de descanso (secado → parto)
  final int? intervalo; // días entre partos
  final int casosLactancia;
  final int casosSeco;
  final int casosIntervalo;

  const PromediosCiclo({
    this.diasLactancia,
    this.diasSeco,
    this.intervalo,
    this.casosLactancia = 0,
    this.casosSeco = 0,
    this.casosIntervalo = 0,
  });
}

class _Acumulado {
  final lactancias = <int>[];
  final secos = <int>[];
  final intervalos = <int>[];

  int? _prom(List<int> l) =>
      l.isEmpty ? null : (l.reduce((a, b) => a + b) / l.length).round();

  PromediosCiclo promedios() => PromediosCiclo(
        diasLactancia: _prom(lactancias),
        diasSeco: _prom(secos),
        intervalo: _prom(intervalos),
        casosLactancia: lactancias.length,
        casosSeco: secos.length,
        casosIntervalo: intervalos.length,
      );
}

class SugerenciaSecado {
  final DateTime fecha;
  final int diasDescanso;
  final String fuente;
  const SugerenciaSecado(
      {required this.fecha, required this.diasDescanso, required this.fuente});
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

  /// Estado de producción de cada vaca activa (id → estado).
  Future<Map<String, EstadoProduccion>> estadosProduccion() async {
    final rows = await _db.rawQuery('''
      SELECT v.id,
        (SELECT MAX(e.fecha) FROM eventos_vaca e
           JOIN tipos_evento t ON t.id = e.tipo_evento_id
           WHERE e.vaca_id = v.id AND e.deleted = 0 AND $_esParto) AS parto,
        (SELECT MAX(e.fecha) FROM eventos_vaca e
           JOIN tipos_evento t ON t.id = e.tipo_evento_id
           WHERE e.vaca_id = v.id AND e.deleted = 0 AND $_esSecado) AS secado
      FROM vacas v
      WHERE v.deleted = 0 AND v.estado = 'activa'
    ''');
    return {
      for (final r in rows)
        r['id'] as String:
            estadoProduccion(_fecha(r['parto']), _fecha(r['secado'])),
    };
  }

  /// Promedios de días en ordeño, días secas e intervalo entre partos,
  /// calculados con el historial de las vacas, por raza y en total ('Todas').
  Future<Map<String, PromediosCiclo>> promediosPorRaza() async {
    final rows = await _db.rawQuery('''
      SELECT e.vaca_id, e.fecha, v.raza,
        CASE WHEN $_esParto THEN 'P' ELSE 'S' END AS tipo
      FROM eventos_vaca e
      JOIN tipos_evento t ON t.id = e.tipo_evento_id
      JOIN vacas v ON v.id = e.vaca_id
      WHERE e.deleted = 0 AND v.deleted = 0 AND ($_esParto OR $_esSecado)
      ORDER BY e.vaca_id, e.fecha
    ''');
    final porVaca = <String, List<(DateTime, String)>>{};
    final razaDe = <String, String>{};
    for (final r in rows) {
      final id = r['vaca_id'] as String;
      porVaca.putIfAbsent(id, () => []).add((_fecha(r['fecha'])!, r['tipo'] as String));
      final raza = (r['raza'] as String?)?.trim();
      razaDe[id] = (raza == null || raza.isEmpty) ? 'Sin raza' : raza;
    }

    final acum = <String, _Acumulado>{};
    void sumar(String clave, void Function(_Acumulado a) f) =>
        f(acum.putIfAbsent(clave, () => _Acumulado()));

    porVaca.forEach((id, eventos) {
      for (var i = 0; i < eventos.length - 1; i++) {
        final (f1, t1) = eventos[i];
        final (f2, t2) = eventos[i + 1];
        final dias = f2.difference(f1).inDays;
        if (dias <= 0) continue;
        for (final clave in [razaDe[id]!, 'Todas']) {
          if (t1 == 'P' && t2 == 'S') sumar(clave, (a) => a.lactancias.add(dias));
          if (t1 == 'S' && t2 == 'P') sumar(clave, (a) => a.secos.add(dias));
        }
      }
      final partos = eventos.where((e) => e.$2 == 'P').map((e) => e.$1).toList();
      for (var i = 1; i < partos.length; i++) {
        final dias = partos[i].difference(partos[i - 1]).inDays;
        if (dias <= 0) continue;
        for (final clave in [razaDe[id]!, 'Todas']) {
          sumar(clave, (a) => a.intervalos.add(dias));
        }
      }
    });
    return acum.map((k, v) => MapEntry(k, v.promedios()));
  }

  /// Fecha sugerida para secar una vaca preñada y días de descanso.
  /// Usa el promedio de su raza (o de todas) si hay suficientes casos;
  /// si no, el valor por defecto de la finca.
  Future<SugerenciaSecado?> sugerenciaSecado(Vaca vaca) async {
    if (vaca.estadoReproductivo != 'prenada' || vaca.fechaEstimadaParto == null) {
      return null;
    }
    final promedios = await promediosPorRaza();
    final raza = (vaca.raza == null || vaca.raza!.trim().isEmpty)
        ? 'Sin raza'
        : vaca.raza!.trim();
    int dias = kDiasSecadoPorDefecto;
    String fuente = 'valor por defecto de la finca';
    final deRaza = promedios[raza];
    final todas = promedios['Todas'];
    if (deRaza != null && deRaza.casosSeco >= kMinimoCasosPromedio) {
      dias = deRaza.diasSeco!;
      fuente = 'promedio de tus vacas ${raza.toLowerCase()} (${deRaza.casosSeco} casos)';
    } else if (todas != null && todas.casosSeco >= kMinimoCasosPromedio) {
      dias = todas.diasSeco!;
      fuente = 'promedio de todas tus vacas (${todas.casosSeco} casos)';
    }
    return SugerenciaSecado(
      fecha: vaca.fechaEstimadaParto!.subtract(Duration(days: dias)),
      diasDescanso: dias,
      fuente: fuente,
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
    /// Padre del ternero; si no se indica, el toro de la monta.
    Object? padreId = _toroDeLaMonta,
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
        categoria: sexoTernero == 'macho' ? 'ternero' : 'ternera',
        fechaNacimiento: fecha,
        madreId: vaca.id,
        padreId: identical(padreId, _toroDeLaMonta)
            ? vaca.toroId
            : padreId as String?,
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

  /// Resultado de la palpación del veterinario. Si está preñada, se estima
  /// la fecha de monta con los meses de preñez y de ahí la de parto.
  Future<void> registrarPalpacion({
    required Vaca vaca,
    required DateTime fecha,
    required bool prenada,
    int? meses,
    String? notas,
  }) async {
    final resultado = prenada
        ? 'Preñada${meses != null ? ' de $meses ${meses == 1 ? 'mes' : 'meses'}' : ''}'
        : 'Vacía';
    await EventoVacaRepository().create(
      vacaId: vaca.id,
      tipoEventoId: await _tipoId(kTipoPalpacion),
      fecha: fecha,
      notas: notas != null && notas.isNotEmpty ? '$resultado · $notas' : resultado,
    );

    if (prenada) {
      final monta = meses != null
          ? fecha.subtract(Duration(days: (meses * 30.4).round()))
          : vaca.fechaMonta;
      await VacaRepository().update(vaca.copyWith(
        estadoReproductivo: 'prenada',
        fechaMonta: monta,
        fechaEstimadaParto:
            monta?.add(const Duration(days: kDiasGestacion)),
        clearFechaMonta: monta == null,
        clearFechaParto: monta == null,
      ));
    } else {
      await VacaRepository().update(vaca.copyWith(
        estadoReproductivo: 'vacia',
        clearFechaMonta: true,
        clearToroId: true,
        clearFechaParto: true,
      ));
    }
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
