import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ganaderia/core/database/local_db.dart';
import 'package:ganaderia/core/models/mi_finca.dart';
import 'package:ganaderia/core/repositories/vaca_repository.dart';

MiFinca finca({
  String estadoFinca = 'activa',
  String estadoMiembro = 'aprobado',
  String rol = 'empleado',
  String? pruebaHasta,
}) =>
    MiFinca.fromServidor({
      'id': 'm1',
      'rol': rol,
      'estado': estadoMiembro,
      'fincas': {
        'id': 'f1',
        'nombre': 'La Esperanza',
        'codigo': 'K7M2QX',
        'estado': estadoFinca,
        'prueba_hasta': pruebaHasta,
      },
    });

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('cada finca tiene su propia base: los datos no se mezclan', () async {
    for (final f in ['prueba_a', 'prueba_b']) {
      await databaseFactory
          .deleteDatabase('${await getDatabasesPath()}/finca_$f.db');
    }
    final db = LocalDb.instance;

    await db.abrirFinca('prueba_a');
    expect(db.fincaId, 'prueba_a');
    await VacaRepository().create(numero: 'A-1');
    await VacaRepository().create(numero: 'A-2');

    await db.abrirFinca('prueba_b');
    expect(db.fincaId, 'prueba_b');
    expect(await VacaRepository().getAll(), isEmpty);
    await VacaRepository().create(numero: 'B-1');

    await db.abrirFinca('prueba_a');
    final enA = (await VacaRepository().getAll()).map((v) => v.numero).toSet();
    expect(enA, {'A-1', 'A-2'});

    await db.cerrar();
    expect(db.abierta, isFalse);
    expect(db.fincaId, isNull);
  });

  test('qué fincas se pueden abrir', () {
    expect(finca().usable, isTrue);
    expect(finca(estadoFinca: 'pendiente').usable, isFalse);
    expect(finca(estadoFinca: 'pendiente').motivoBloqueo, contains('revisión'));
    expect(finca(estadoFinca: 'suspendida').usable, isFalse);
    expect(finca(estadoMiembro: 'pendiente').usable, isFalse);
    expect(finca(estadoMiembro: 'pendiente').motivoBloqueo, contains('apruebe'));
    expect(finca(estadoMiembro: 'inactivo').usable, isFalse);

    final manana = DateTime.now().add(const Duration(days: 1));
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    String f(DateTime x) => x.toIso8601String().substring(0, 10);
    expect(finca(estadoFinca: 'prueba', pruebaHasta: f(manana)).usable, isTrue);
    expect(finca(estadoFinca: 'prueba', pruebaHasta: f(ayer)).usable, isFalse);
    expect(finca(estadoFinca: 'prueba').usable, isTrue); // prueba sin fecha

    expect(finca(rol: 'dueno').esAdmin, isTrue);
    expect(finca(rol: 'admin').esAdmin, isTrue);
    expect(finca().esAdmin, isFalse);
  });

  test('la finca guardada en el teléfono se lee igual', () {
    final original = finca(estadoFinca: 'prueba', pruebaHasta: '2030-01-31');
    final copia = MiFinca.fromServidor(original.toJson());
    expect(copia.fincaId, original.fincaId);
    expect(copia.nombre, 'La Esperanza');
    expect(copia.codigo, 'K7M2QX');
    expect(copia.estadoFinca, 'prueba');
    expect(copia.pruebaHasta, DateTime(2030, 1, 31));
    expect(copia.miembroId, 'm1');
  });
}
