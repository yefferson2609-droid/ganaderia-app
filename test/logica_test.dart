import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ganaderia/core/database/local_db.dart';
import 'package:ganaderia/core/models/vaca.dart';
import 'package:ganaderia/core/repositories/leche_repository.dart';
import 'package:ganaderia/core/models/nomina.dart';
import 'package:ganaderia/core/repositories/movimiento_financiero_repository.dart';
import 'package:ganaderia/core/repositories/nomina_repository.dart';
import 'package:ganaderia/core/repositories/perfil_usuario_repository.dart';
import 'package:ganaderia/core/repositories/pesaje_repository.dart';
import 'package:ganaderia/core/repositories/reproduccion_repository.dart';
import 'package:ganaderia/core/repositories/ternero_repository.dart';
import 'package:ganaderia/core/repositories/tipo_evento_repository.dart';
import 'package:ganaderia/core/repositories/evento_vaca_repository.dart';
import 'package:ganaderia/core/repositories/vaca_repository.dart';
import 'package:ganaderia/core/services/alertas_service.dart';
import 'package:ganaderia/core/services/inventario_service.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);
DateTime hoy() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

Future<void> borrarTodo() async {
  final db = LocalDb.instance.db;
  for (final t in [
    'vacas', 'eventos_vaca', 'tipos_evento', 'terneros', 'produccion_leche',
    'pesajes_animal', 'ubicaciones'
  ]) {
    await db.delete(t);
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.deleteDatabase(
        '${await getDatabasesPath()}/ganaderia_v2.db');
    await LocalDb.instance.init();
  });

  setUp(borrarTodo);

  test('la base nueva tiene todas las columnas y tablas', () async {
    final db = LocalDb.instance;
    expect(await db.columnas('caballos'),
        containsAll(['fecha_nacimiento', 'raza', 'foto_url', 'foto_local']));
    for (final t in ['vacas', 'toros', 'terneros']) {
      expect(await db.columnas(t), containsAll(['raza', 'foto_url', 'foto_local']));
    }
    expect(await db.columnas('solicitudes'), containsAll(['foto_url', 'foto_local']));
    expect(await db.columnas('produccion_leche'),
        containsAll(['fecha', 'turno', 'litros', 'vaca_id']));
    expect(await db.columnas('pesajes_animal'),
        containsAll(['animal_tipo', 'animal_id', 'peso']));
  });

  test('parto: pasa a ordeño, crea ternero y calcula intervalos', () async {
    final vacas = VacaRepository();
    final repro = ReproduccionRepository();
    final v = await vacas.create(
        numero: '12',
        raza: 'Mestiza',
        estadoReproductivo: 'prenada',
        fechaMonta: d(2025, 1, 1),
        fechaEstimadaParto: d(2025, 10, 11));

    expect((await repro.resumen(v.id)).estado, EstadoProduccion.sinPartos);

    final terneroId = await repro.registrarParto(
        vaca: v, fecha: d(2024, 1, 10), numeroTernero: 'T1', sexoTernero: 'hembra');
    expect(terneroId, isNotNull);
    final ternero = await TerneroRepository().getById(terneroId!);
    expect(ternero!.madreId, v.id);
    expect(ternero.fechaNacimiento, d(2024, 1, 10));

    final tras = await vacas.getById(v.id);
    expect(tras!.estadoReproductivo, 'vacia');
    expect(tras.fechaEstimadaParto, isNull);

    await repro.registrarParto(vaca: tras, fecha: d(2025, 1, 4));
    final r = await repro.resumen(v.id);
    expect(r.partos.length, 2);
    expect(r.intervalos, [360]);
    expect(r.estado, EstadoProduccion.enOrdeno);

    await repro.secar(vacaId: v.id, fecha: d(2025, 9, 1));
    expect((await repro.resumen(v.id)).estado, EstadoProduccion.seca);

    final conteo = await repro.conteoProduccion();
    expect(conteo[EstadoProduccion.seca], 1);
    final estados = await repro.estadosProduccion();
    expect(estados[v.id], EstadoProduccion.seca);
  });

  test('vitamina: toma el último evento cuyo tipo dice "vitamina"', () async {
    final v = await VacaRepository().create(numero: '5');
    final tipo = await TipoEventoRepository().create(nombre: 'Vitamina AD3E');
    await EventoVacaRepository()
        .create(vacaId: v.id, tipoEventoId: tipo.id, fecha: d(2025, 3, 1));
    await EventoVacaRepository()
        .create(vacaId: v.id, tipoEventoId: tipo.id, fecha: d(2025, 6, 1));
    final r = await ReproduccionRepository().resumen(v.id);
    expect(r.ultimaVitamina, d(2025, 6, 1));
    expect(r.ultimaVitaminaNombre, 'Vitamina AD3E');
  });

  test('sugerencia de secado: 60 días por defecto y luego promedio de la raza',
      () async {
    final repro = ReproduccionRepository();
    final vacas = VacaRepository();
    final parto = hoy().add(const Duration(days: 100));
    final v = await vacas.create(
        numero: '1',
        raza: 'Mestiza',
        estadoReproductivo: 'prenada',
        fechaMonta: parto.subtract(const Duration(days: 283)),
        fechaEstimadaParto: parto);

    var s = await repro.sugerenciaSecado(v);
    expect(s!.diasDescanso, 60);
    expect(s.fecha, parto.subtract(const Duration(days: 60)));

    // Historial de 3 vacas mestizas con 45 días secas antes de parir.
    for (var i = 0; i < 3; i++) {
      final otra = await vacas.create(numero: 'H$i', raza: 'Mestiza');
      await repro.secar(vacaId: otra.id, fecha: d(2024, 1, 1));
      await repro.registrarParto(
          vaca: (await vacas.getById(otra.id))!, fecha: d(2024, 2, 15));
    }
    final prom = await repro.promediosPorRaza();
    expect(prom['Mestiza']!.diasSeco, 45);
    expect(prom['Mestiza']!.casosSeco, 3);

    s = await repro.sugerenciaSecado(v);
    expect(s!.diasDescanso, 45);
    expect(s.fuente, contains('mestiza'));
  });

  test('palpación: preñada de 3 meses calcula monta y parto', () async {
    final repro = ReproduccionRepository();
    final v = await VacaRepository().create(numero: '9');
    final visita = d(2025, 6, 1);
    await repro.registrarPalpacion(
        vaca: v, fecha: visita, prenada: true, meses: 3, notas: 'Dr. Pérez');
    final tras = (await VacaRepository().getById(v.id))!;
    expect(tras.estadoReproductivo, 'prenada');
    expect(tras.fechaMonta, visita.subtract(const Duration(days: 91)));
    expect(tras.fechaEstimadaParto,
        tras.fechaMonta!.add(const Duration(days: 283)));

    await repro.registrarPalpacion(vaca: tras, fecha: visita, prenada: false);
    final vacia = (await VacaRepository().getById(v.id))!;
    expect(vacia.estadoReproductivo, 'vacia');
    expect(vacia.fechaEstimadaParto, isNull);
  });

  test('leche: mañana + tarde por día, sin duplicar al editar', () async {
    final repo = LecheRepository();
    final dia = hoy();
    await repo.guardarFinca(fecha: dia, turno: 'manana', litros: 120);
    await repo.guardarFinca(fecha: dia, turno: 'tarde', litros: 80.5);
    await repo.guardarFinca(fecha: dia, turno: 'tarde', litros: 85); // corrige
    final dias = await repo.diasFinca(dia.subtract(const Duration(days: 2)), dia);
    expect(dias.length, 3);
    expect(dias.last.manana, 120);
    expect(dias.last.tarde, 85);
    expect(dias.last.total, 205);
    expect(dias.first.total, 0);

    final v = await VacaRepository().create(numero: '3');
    await repo.guardarVaca(vacaId: v.id, fecha: dia, turno: 'manana', litros: 8);
    await repo.guardarVaca(vacaId: v.id, fecha: dia, turno: 'tarde', litros: 6);
    final prom = await repo.promedioPorVaca();
    expect(prom[v.id], 14);
    // La leche por vaca no se suma al total de la finca.
    expect((await repo.diasFinca(dia, dia)).single.total, 205);
  });

  test('alertas: parto próximo, vacía mucho tiempo y vitamina vencida', () async {
    final vacas = VacaRepository();
    final repro = ReproduccionRepository();
    final h = hoy();

    // Preñada, en ordeño, pare en 20 días → parto próximo y "secar".
    final a = await vacas.create(
        numero: 'A',
        estadoReproductivo: 'prenada',
        fechaMonta: h.subtract(const Duration(days: 263)),
        fechaEstimadaParto: h.add(const Duration(days: 20)));
    await repro.registrarParto(vaca: a, fecha: h.subtract(const Duration(days: 300)));
    // registrarParto la deja vacía: se vuelve a marcar preñada.
    final a2 = (await vacas.getById(a.id))!;
    await vacas.update(a2.copyWith(
        estadoReproductivo: 'prenada',
        fechaMonta: h.subtract(const Duration(days: 263)),
        fechaEstimadaParto: h.add(const Duration(days: 20))));

    // Vacía hace 120 días desde el parto.
    final b = await vacas.create(numero: 'B');
    await repro.registrarParto(vaca: b, fecha: h.subtract(const Duration(days: 120)));

    final alertas = await AlertasService().generar();
    expect(alertas[TipoAlerta.partos]!.map((x) => x.titulo), ['Vaca #A']);
    expect(alertas[TipoAlerta.secar]!.map((x) => x.titulo), ['Vaca #A']);
    expect(alertas[TipoAlerta.vacias]!.map((x) => x.titulo), ['Vaca #B']);
    expect(alertas[TipoAlerta.vitamina]!.length, 2); // ninguna tiene vitamina
  });

  test('inventario y pesajes funcionan con raza y foto', () async {
    final v = await VacaRepository().create(numero: '77', raza: 'Gyr');
    await PesajeRepository().registrar(
        tipo: 'vaca', animalId: v.id, fecha: hoy(), peso: 450);
    expect((await PesajeRepository().getByAnimal('vaca', v.id)).single.peso, 450);

    final grupos = await InventarioService().generar();
    final ficha = grupos.expand((g) => g.animales).firstWhere((a) => a.id == v.id);
    expect(ficha.datos.any((d) => d.$1 == 'Raza' && d.$2 == 'Gyr'), isTrue);
  });

  test('editar una vaca conserva raza y foto', () async {
    final repo = VacaRepository();
    final v = await repo.create(numero: '50', raza: 'Holstein', color: 'Pinta');
    await LocalDb.instance.db.update('vacas',
        {'foto_local': '/x/foto.jpg'}, where: 'id = ?', whereArgs: [v.id]);
    final cargada = (await repo.getById(v.id))!;
    await repo.update(cargada.copyWith(nota: 'Mansa'));
    final final_ = (await repo.getById(v.id))!;
    expect(final_.raza, 'Holstein');
    expect(final_.fotoLocal, '/x/foto.jpg');
    expect(final_.nota, 'Mansa');
    expect(final_.color, 'Pinta');
    expect(final_, isA<Vaca>());
  });

  test('levante y ceba: categoría sugerida, destete, capado y venta', () async {
    final repo = TerneroRepository();
    final h = hoy();
    DateTime haceMeses(int m) => h.subtract(Duration(days: (m * 30.44).ceil() + 1));

    final ternera = await repo.create(numero: '1', sexo: 'hembra', fechaNacimiento: haceMeses(3));
    expect(ternera.categoriaSugerida, 'ternera');
    expect(ternera.debeDestetarse, isFalse);

    final grande = await repo.create(numero: '2', sexo: 'hembra', fechaNacimiento: haceMeses(10));
    expect(grande.debeDestetarse, isTrue); // 9 meses sin destetar

    await repo.registrarDestete(grande, h);
    final destetada = (await repo.getById(grande.id))!;
    expect(destetada.categoria, 'novilla_levante');
    expect(destetada.etapa, 'destete');
    expect(destetada.debeDestetarse, isFalse);

    final vieja = await repo.create(
        numero: '3', sexo: 'hembra', fechaNacimiento: haceMeses(26),
        categoria: 'novilla_levante', fechaDestete: haceMeses(17));
    expect(vieja.cambioSugerido, 'novilla_vientre');

    final macho = await repo.create(numero: '4', sexo: 'macho', fechaNacimiento: haceMeses(12));
    expect(macho.categoriaSugerida, 'torete'); // 12 meses: se asume destetado
    await repo.registrarDestete(macho, h);
    var m = (await repo.getById(macho.id))!;
    expect(m.categoria, 'torete');
    await repo.cambiarCategoria(m, 'torete_venta');
    m = (await repo.getById(macho.id))!;
    expect(m.categoriaActual, 'torete_venta');
    expect(m.cambioSugerido, isNull);
    await repo.marcarCapado(m);
    m = (await repo.getById(macho.id))!;
    expect(m.capado, isTrue);
    expect(m.categoria, 'novillo_ceba');
    expect(m.etapa, 'ceba');

    final alertas = await AlertasService().generar();
    expect(alertas[TipoAlerta.destete]!.length, 0);
    expect(alertas[TipoAlerta.categoria]!.map((a) => a.titulo),
        contains('Novilla de levante #3'));
  });

  test('novilla preñada pasa a Vacas con fecha de parto', () async {
    final repo = TerneroRepository();
    final n = await repo.create(
        numero: 'N7', sexo: 'hembra', raza: 'Gyr',
        fechaNacimiento: d(2023, 1, 1), categoria: 'novilla_vientre');
    final vacaId = await repo.promoverAVaca(n,
        prenadaMeses: 2, fechaChequeo: d(2025, 6, 1));
    expect(await repo.getById(n.id), isNull); // ya no está en levante
    final v = (await VacaRepository().getById(vacaId))!;
    expect(v.numero, 'N7');
    expect(v.raza, 'Gyr');
    expect(v.estadoReproductivo, 'prenada');
    expect(v.fechaEstimadaParto, isNotNull);
  });

  test('parto crea ternera o ternero ya clasificado', () async {
    final v = await VacaRepository().create(numero: '20');
    final id = await ReproduccionRepository().registrarParto(
        vaca: v, fecha: hoy(), numeroTernero: 'C1', sexoTernero: 'macho');
    final t = (await TerneroRepository().getById(id!))!;
    expect(t.categoria, 'ternero');
  });

  test('usuarios eliminados no salen en la lista pero sí su nombre', () async {
    final db = LocalDb.instance.db;
    await db.delete('perfiles_usuario');
    final ahora = DateTime.now().toIso8601String();
    for (final (id, nombre, elim) in [('u1', 'Ana', 0), ('u2', 'Beto', 1)]) {
      await db.insert('perfiles_usuario', {
        'id': id, 'nombre': nombre, 'correo': '$id@x.com', 'activo': 1,
        'eliminado': elim, 'created_at': ahora, 'updated_at': ahora,
      });
    }
    final repo = PerfilUsuarioRepository();
    expect((await repo.getAll()).map((p) => p.nombre), ['Ana']);
    expect((await repo.getById('u2'))!.nombre, 'Beto');
    expect((await repo.getById('u2'))!.eliminado, isTrue);
  });

  test('nómina: domingo de la semana, bonos, anticipos y préstamos', () async {
    final db = LocalDb.instance.db;
    for (final t in ['trabajadores', 'nomina_novedades', 'prestamos_trabajador',
      'nomina_semanas', 'prestamo_cuotas', 'movimientos_financieros']) {
      await db.delete(t);
    }
    expect(semanaFin(d(2026, 10, 1)), d(2026, 10, 4)); // jueves → domingo
    expect(semanaFin(d(2026, 10, 4)), d(2026, 10, 4)); // domingo → mismo día
    expect(semanaFin(d(2026, 10, 5)), d(2026, 10, 11)); // lunes → siguiente

    final repo = NominaRepository();
    await repo.guardarTrabajador(nombre: 'Luis', salarioSemanal: 100);
    await repo.guardarTrabajador(nombre: 'Ana', salarioSemanal: 80, activo: false);
    final luis = (await repo.getTrabajadores(soloActivos: true)).single;

    final semana = d(2026, 10, 11);
    await repo.agregarNovedad(trabajador: luis, tipo: 'bono', monto: 20, fecha: d(2026, 10, 7));
    await repo.agregarNovedad(trabajador: luis, tipo: 'anticipo', monto: 30, fecha: d(2026, 10, 8));
    await repo.agregarPrestamo(trabajador: luis, monto: 50, cuotaSemanal: 15, fecha: d(2026, 10, 6));

    final filas = await repo.calcular(semana);
    expect(filas.length, 1); // Ana está inactiva
    final f = filas.single;
    expect(f.salario, 100);
    expect(f.bonos, 20);
    expect(f.anticipos, 30);
    expect(f.cuotas, 15);
    expect(f.neto, 75); // 100 + 20 − 30 − 15

    // El anticipo y el préstamo ya salieron como gasto, con concepto Nómina.
    final gastos = await MovimientoFinancieroRepository().getAll(tipo: 'gasto');
    expect(gastos.map((g) => g.monto).toSet(), {30.0, 50.0});
    expect(gastos.every((g) => g.conceptoId == gastos.first.conceptoId), isTrue);

    // Si la semana ya está pagada, un bono nuevo pasa a la semana siguiente.
    final ahora = DateTime.now().toIso8601String();
    await db.insert('nomina_semanas', {
      'id': 's1', 'semana_fin': '2026-10-11', 'estado': 'pagada', 'total': 75,
      'trabajadores': 1, 'automatica': 1, 'created_at': ahora, 'updated_at': ahora,
    });
    await repo.agregarNovedad(trabajador: luis, tipo: 'bono', monto: 5, fecha: d(2026, 10, 10));
    expect((await repo.getNovedades(d(2026, 10, 18))).single.monto, 5);
  });

  // Va al final: cambia la base abierta por LocalDb.
  test('migración real desde la versión 6 (la que tiene el teléfono)', () async {
    final path = '${await getDatabasesPath()}/migracion_test.db';
    await databaseFactory.deleteDatabase(path);
    // Tablas que cambian, con sus columnas de la versión 6.
    final v6 = await openDatabase(path, version: 6, onCreate: (db, _) async {
      await db.execute(
          'CREATE TABLE vacas (id TEXT PRIMARY KEY, numero TEXT, color TEXT)');
      await db.execute('CREATE TABLE toros (id TEXT PRIMARY KEY, color TEXT)');
      await db.execute('CREATE TABLE terneros (id TEXT PRIMARY KEY, color TEXT, etapa TEXT)');
      await db.execute(
          'CREATE TABLE perfiles_usuario (id TEXT PRIMARY KEY, nombre TEXT, activo INTEGER)');
      await db.execute(
          'CREATE TABLE caballos (id TEXT PRIMARY KEY, nombre TEXT, color TEXT)');
      await db.insert('vacas', {'id': 'v1', 'numero': '12', 'color': 'Roja'});
    });
    await v6.close();

    await LocalDb.instance.init(path: path); // corre _onUpgrade 6 → 11
    final db = LocalDb.instance.db;
    expect(await db.getVersion(), 11);
    expect(await LocalDb.instance.columnas('trabajadores'), contains('salario_semanal'));
    expect(await LocalDb.instance.columnas('perfiles_usuario'), contains('eliminado'));
    expect(await LocalDb.instance.columnas('terneros'),
        containsAll(['categoria', 'fecha_destete']));
    expect(await LocalDb.instance.columnas('caballos'),
        containsAll(['fecha_nacimiento', 'raza', 'foto_url', 'foto_local']));
    expect(await LocalDb.instance.columnas('vacas'),
        containsAll(['raza', 'foto_url', 'foto_local']));
    expect(await LocalDb.instance.columnas('produccion_leche'), contains('litros'));
    expect(await LocalDb.instance.columnas('pesajes_animal'), contains('peso'));
    // Los datos existentes se conservan.
    final v = await db.query('vacas');
    expect(v.single['numero'], '12');
    expect(v.single['color'], 'Roja');
  });
}
