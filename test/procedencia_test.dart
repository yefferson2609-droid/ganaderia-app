import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ganaderia/core/database/local_db.dart';
import 'package:ganaderia/core/models/procedencia.dart';
import 'package:ganaderia/core/repositories/ternero_repository.dart';
import 'package:ganaderia/core/repositories/toro_repository.dart';
import 'package:ganaderia/core/repositories/vaca_repository.dart';

const importada = Procedencia(
  origen: 'importada',
  registro: 'ABC-123',
  padreNombre: 'JDH Karu Manso',
  padreRegistro: 'P-777',
  padreRaza: 'Brahman',
  madreNombre: 'Lucera',
  madreRaza: 'Brahman',
);

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final path = '${await getDatabasesPath()}/procedencia_test.db';
    await databaseFactory.deleteDatabase(path);
    await LocalDb.instance.init(path: path);
  });

  test('textos de origen y de padres de fuera', () {
    expect(Procedencia.origenTexto('importada', hembra: true), 'Importada');
    expect(Procedencia.origenTexto('comprada', hembra: false), 'Comprado');
    expect(Procedencia.origenTexto('finca', hembra: true), 'Nacida en la finca');
    expect(importada.padreExterno, isTrue);
    expect(importada.padreTexto, 'JDH Karu Manso · Reg. P-777 · Brahman');
    expect(importada.madreTexto, 'Lucera · Brahman');
    expect(const Procedencia().padreExterno, isFalse);
    expect(const Procedencia().padreTexto, isNull);
  });

  test('vaca importada: se guarda y se lee su procedencia', () async {
    final repo = VacaRepository();
    final v = await repo.create(numero: 'IMP-1', procedencia: importada);
    final leida = (await repo.getById(v.id))!;
    expect(leida.procedencia.origen, 'importada');
    expect(leida.procedencia.registro, 'ABC-123');
    expect(leida.procedencia.padreTexto, importada.padreTexto);
    expect(leida.procedencia.madreTexto, importada.madreTexto);
    expect(leida.padreId, isNull);
  });

  test('la fecha de nacimiento se puede quitar después de registrada', () async {
    final vacas = VacaRepository();
    final v = await vacas.create(numero: 'F-1', fechaNacimiento: DateTime(2020, 5, 1));
    await vacas.update(v.copyWith(fechaNacimiento: null));
    expect((await vacas.getById(v.id))!.fechaNacimiento, isNull);

    final toros = ToroRepository();
    final t = await toros.create(
        numero: 'T-1', nombre: 'Rey', fechaNacimiento: DateTime(2019, 1, 1));
    await toros.update(t.copyWith(fechaNacimiento: null));
    expect((await toros.getById(t.id))!.fechaNacimiento, isNull);

    // Cambiar otra cosa no borra la fecha.
    final v2 = await vacas.create(numero: 'F-2', fechaNacimiento: DateTime(2021, 2, 2));
    await vacas.update(v2.copyWith(raza: 'Gyr'));
    expect((await vacas.getById(v2.id))!.fechaNacimiento, DateTime(2021, 2, 2));
  });

  test('el padre de la finca se puede quitar al pasar a uno de fuera', () async {
    final toro = await ToroRepository().create(numero: 'T-9', nombre: 'Padre');
    final vacas = VacaRepository();
    final v = await vacas.create(numero: 'P-1', padreId: toro.id);
    await vacas.update(v.copyWith(
        padreId: null, procedencia: const Procedencia(padreNombre: 'Externo')));
    final leida = (await vacas.getById(v.id))!;
    expect(leida.padreId, isNull);
    expect(leida.procedencia.padreNombre, 'Externo');
  });

  test('al pasar de levante a vaca conserva la procedencia', () async {
    final repo = TerneroRepository();
    final t = await repo.create(
        numero: 'N-1',
        sexo: 'hembra',
        fechaNacimiento: DateTime(2023, 1, 1),
        procedencia: importada);
    final leida = (await repo.getById(t.id))!;
    expect(leida.procedencia.registro, 'ABC-123');

    final vacaId = await repo.promoverAVaca(leida);
    final vaca = (await VacaRepository().getById(vacaId))!;
    expect(vaca.procedencia.origen, 'importada');
    expect(vaca.procedencia.padreTexto, importada.padreTexto);
  });
}
