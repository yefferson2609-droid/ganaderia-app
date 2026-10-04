import 'package:intl/intl.dart';
import '../database/local_db.dart';
import '../models/ternero.dart';
import '../repositories/caballo_repository.dart';
import '../repositories/registro_salud_repository.dart';
import '../repositories/reproduccion_repository.dart';
import '../repositories/ternero_repository.dart';
import '../repositories/toro_repository.dart';
import '../repositories/ubicacion_repository.dart';
import '../repositories/vaca_repository.dart';

final _fmt = DateFormat('dd/MM/yyyy');

/// Ficha de un animal para el inventario detallado.
class FichaAnimal {
  final String tipo; // 'vaca' | 'toro' | 'ternero' | 'caballo'
  final String id;
  final String titulo; // 'Vaca #12'
  final String resumen; // una línea con lo principal
  final bool enTratamiento;
  final List<(String, String)> datos;
  final List<String> salud; // historial de salud, del más reciente
  final List<String> eventos; // historial de eventos, del más reciente
  final String? fotoLocal;
  final String? fotoUrl;

  const FichaAnimal({
    required this.tipo,
    required this.id,
    required this.titulo,
    required this.resumen,
    this.fotoLocal,
    this.fotoUrl,
    this.enTratamiento = false,
    this.datos = const [],
    this.salud = const [],
    this.eventos = const [],
  });
}

class GrupoInventario {
  final String? ubicacionId;
  final String nombre;
  final List<FichaAnimal> animales;
  final int cerdos;
  final int ovejos;

  const GrupoInventario({
    required this.ubicacionId,
    required this.nombre,
    required this.animales,
    this.cerdos = 0,
    this.ovejos = 0,
  });

  int get total => animales.length + cerdos + ovejos;
}

String _edad(DateTime? nacimiento) {
  if (nacimiento == null) return 'Edad desconocida';
  final d = DateTime.now().difference(nacimiento).inDays;
  final anios = d ~/ 365;
  final meses = (d % 365) ~/ 30;
  if (anios > 0) return '$anios a ${meses} m';
  if (meses > 0) return '$meses meses';
  return '$d días';
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class InventarioService {
  final _db = LocalDb.instance.db;
  final _salud = RegistroSaludRepository();
  final _repro = ReproduccionRepository();

  /// Inventario de animales activos agrupado por ubicación.
  Future<List<GrupoInventario>> generar() async {
    final ubicaciones = await UbicacionRepository().getAll(soloActivas: true);
    final grupos = <GrupoInventario>[];
    for (final u in ubicaciones) {
      grupos.add(await _grupo(u.id, u.nombre));
    }
    final sin = await _grupo(null, 'Sin ubicación');
    if (sin.total > 0) grupos.add(sin);
    return grupos;
  }

  Future<GrupoInventario> _grupo(String? ubicacionId, String nombre) async {
    final animales = <FichaAnimal>[];

    bool enUbic(String? id) => id == ubicacionId;

    final vacas = (await VacaRepository().getAll(soloActivas: true))
        .where((v) => enUbic(v.ubicacionId));
    for (final v in vacas) {
      final r = await _repro.resumen(v.id);
      final salud = await _historialSalud('vaca', v.id);
      final prenada = v.estadoReproductivo == 'prenada';
      animales.add(FichaAnimal(
        tipo: 'vaca',
        id: v.id,
        fotoLocal: v.fotoLocal,
        fotoUrl: v.fotoUrl,
        titulo: 'Vaca #${v.numero}',
        resumen: [
          kEstadoProduccionLabels[r.estado]!,
          prenada ? 'Preñada' : 'Vacía',
          '${r.partos.length} parto${r.partos.length == 1 ? '' : 's'}',
          _edad(v.fechaNacimiento),
        ].join(' · '),
        enTratamiento: salud.$1,
        datos: [
          ('Edad', _edad(v.fechaNacimiento)),
          if (v.raza != null) ('Raza', v.raza!),
          if (v.color != null) ('Color', v.color!),
          ('Producción', kEstadoProduccionLabels[r.estado]! +
              (r.diasEnLeche != null ? ' (${r.diasEnLeche} días en leche)' : '')),
          ('Reproductivo', prenada
              ? 'Preñada${v.fechaEstimadaParto != null ? ' · parto estimado ${_fmt.format(v.fechaEstimadaParto!)}' : ''}'
              : 'Vacía'),
          ('Partos', '${r.partos.length}'),
          if (r.ultimoParto != null) ('Último parto', _fmt.format(r.ultimoParto!)),
          if (r.intervaloPromedio != null)
            ('Intervalo entre partos',
                '${r.intervaloPromedio} días promedio (${r.intervalos.join(', ')})'),
          ('Última vitamina', r.ultimaVitamina != null
              ? '${_fmt.format(r.ultimaVitamina!)} · ${r.ultimaVitaminaNombre}'
              : 'Sin registro'),
          if (v.nota != null) ('Nota', v.nota!),
        ],
        salud: salud.$2,
        eventos: await _eventosVaca(v.id),
      ));
    }

    final toros = (await ToroRepository().getAll(soloActivos: true))
        .where((t) => enUbic(t.ubicacionId));
    for (final t in toros) {
      final salud = await _historialSalud('toro', t.id);
      animales.add(FichaAnimal(
        tipo: 'toro',
        id: t.id,
        fotoLocal: t.fotoLocal,
        fotoUrl: t.fotoUrl,
        titulo: 'Toro ${t.displayName}',
        resumen: _edad(t.fechaNacimiento),
        enTratamiento: salud.$1,
        datos: [
          ('Edad', _edad(t.fechaNacimiento)),
          if (t.raza != null) ('Raza', t.raza!),
          if (t.color != null) ('Color', t.color!),
          if (t.nota != null) ('Nota', t.nota!),
        ],
        salud: salud.$2,
      ));
    }

    final terneros = (await TerneroRepository().getAll(soloActivos: true))
        .where((t) => enUbic(t.ubicacionId));
    for (final t in terneros) {
      final salud = await _historialSalud('ternero', t.id);
      final pesadas = await TerneroRepository().getPesadas(t.id);
      final madre = t.madreId != null
          ? await VacaRepository().getById(t.madreId!)
          : null;
      animales.add(FichaAnimal(
        tipo: 'ternero',
        id: t.id,
        fotoLocal: t.fotoLocal,
        fotoUrl: t.fotoUrl,
        titulo: 'Ternero #${t.numero}',
        resumen: [
          t.esMacho ? 'Macho' : 'Hembra',
          if (t.capado) 'Capado',
          kEtapaLabels[t.etapa] ?? t.etapa,
          _edad(t.fechaNacimiento),
        ].join(' · '),
        enTratamiento: salud.$1,
        datos: [
          ('Sexo', t.esMacho ? (t.capado ? 'Macho capado' : 'Macho') : 'Hembra'),
          ('Etapa', kEtapaLabels[t.etapa] ?? t.etapa),
          if (t.raza != null) ('Raza', t.raza!),
          ('Edad', _edad(t.fechaNacimiento)),
          if (madre != null) ('Madre', 'Vaca #${madre.numero}'),
          if (pesadas.isNotEmpty)
            ('Último peso',
                '${pesadas.first.peso.toStringAsFixed(1)} kg (${_fmt.format(pesadas.first.fecha)})'),
          if (t.color != null) ('Color', t.color!),
          if (t.nota != null) ('Nota', t.nota!),
        ],
        salud: salud.$2,
      ));
    }

    final caballos = (await CaballoRepository().getAll())
        .where((c) => c.estado == 'activo' && enUbic(c.ubicacionId));
    for (final c in caballos) {
      final salud = await _historialSalud('caballo', c.id);
      animales.add(FichaAnimal(
        tipo: 'caballo',
        id: c.id,
        fotoLocal: c.fotoLocal,
        fotoUrl: c.fotoUrl,
        titulo: 'Caballo ${c.nombre}',
        resumen: c.color ?? 'Activo',
        enTratamiento: salud.$1,
        datos: [
          if (c.fechaNacimiento != null) ('Edad', _edad(c.fechaNacimiento)),
          if (c.raza != null) ('Raza', c.raza!),
          if (c.color != null) ('Color', c.color!),
          if (c.nota != null) ('Nota', c.nota!),
        ],
        salud: salud.$2,
      ));
    }

    final filtro = ubicacionId == null ? 'ubicacion_id IS NULL' : 'ubicacion_id = ?';
    final args = ubicacionId == null ? null : [ubicacionId];
    Future<int> lote(String tipo) async {
      final r = await _db.rawQuery(
          "SELECT COALESCE(SUM(hembras+machos),0) as c FROM lotes WHERE deleted=0 AND tipo='$tipo' AND $filtro",
          args);
      return (r.first['c'] as int?) ?? 0;
    }

    return GrupoInventario(
      ubicacionId: ubicacionId,
      nombre: nombre,
      animales: animales,
      cerdos: await lote('cerdo'),
      ovejos: await lote('ovejo'),
    );
  }

  /// (¿tiene un problema activo?, historial en texto).
  Future<(bool, List<String>)> _historialSalud(String tipo, String id) async {
    final registros = await _salud.getByAnimal(tipo, id);
    final lineas = <String>[];
    for (final r in registros) {
      final trat = await _salud.getTratamientos(r.id);
      final periodo = r.activo
          ? 'desde ${_fmt.format(r.fechaInicio)} (en tratamiento)'
          : '${_fmt.format(r.fechaInicio)} – ${r.fechaFin != null ? _fmt.format(r.fechaFin!) : '?'}';
      final meds = trat
          .map((t) =>
              '${t.medicamento}${t.dosis != null ? ' ${t.dosis}' : ''}${t.programado ? ' (programado)' : ''}')
          .join(', ');
      lineas.add('${r.diagnostico}: $periodo${meds.isNotEmpty ? ' · $meds' : ''}');
    }
    return (registros.any((r) => r.activo), lineas);
  }

  Future<List<String>> _eventosVaca(String vacaId) async {
    final rows = await _db.rawQuery('''
      SELECT e.fecha, e.notas, t.nombre FROM eventos_vaca e
      LEFT JOIN tipos_evento t ON t.id = e.tipo_evento_id
      WHERE e.vaca_id = ? AND e.deleted = 0
      ORDER BY e.fecha DESC
    ''', [vacaId]);
    return rows.map((r) {
      final f = _fmt.format(DateTime.parse(r['fecha'] as String));
      final notas = r['notas'] as String?;
      return '$f · ${_cap((r['nombre'] as String?) ?? 'Evento')}'
          '${notas != null && notas.isNotEmpty ? ' — $notas' : ''}';
    }).toList();
  }
}
