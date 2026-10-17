// Vista previa del diseño (no es una prueba de lógica): genera imágenes PNG
// con el tema real para mostrarlas antes de compilar.
// PowerShell: $env:VISTA_PREVIA="1"; flutter test test/vista_previa_test.dart --update-goldens
// Las imágenes quedan en test/vista_previa/ (fuera de git).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia/core/theme/app_theme.dart';
import 'package:ganaderia/core/widgets/animal_face.dart';

Future<void> _fuente(String familia, List<String> archivos) async {
  final f = FontLoader(familia);
  for (final a in archivos) {
    final bytes = File(a).readAsBytesSync();
    f.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await f.load();
}

Widget _seccion(BuildContext c, String t) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(t, style: Theme.of(c).textTheme.titleLarge),
    );

Widget _animal(String label, String tipo, int n, Color color) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimalFace(tipo: tipo, size: 48),
          const SizedBox(height: 6),
          Text('$n',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 13)),
        ]),
      ),
    );

Widget _panel() => Builder(
      builder: (c) => Scaffold(
        appBar: AppBar(
          leading: const Icon(Icons.menu),
          titleSpacing: 0,
          title: const Row(children: [
            MarcaLogo(size: 34),
            SizedBox(width: 10),
            Text('La Esperanza'),
          ]),
          actions: const [
            Padding(padding: EdgeInsets.all(14), child: Icon(Icons.cloud_done)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _seccion(c, 'Avisos'),
            const Card(
              child: ListTile(
                leading: Icon(Icons.child_friendly, color: AppColors.info),
                title: Text('2 partos próximos',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
            const Card(
              child: ListTile(
                leading:
                    Icon(Icons.water_drop_outlined, color: AppColors.warning),
                title: Text('1 vaca para secar',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
            _seccion(c, 'Total general'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.9,
              children: [
                _animal('Vacas', 'vaca', 48, AppColors.primary),
                _animal('Toros', 'toro', 3, AppColors.info),
                _animal('Levante', 'ternero', 21, AppColors.secondary),
              ],
            ),
            _seccion(c, 'Producción'),
            const Card(
              child: ListTile(
                leading: Icon(Icons.water_drop, color: AppColors.info),
                title: Text('Leche hoy: 312 L',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Mañana 180 L · Tarde 132 L'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
            onPressed: () {}, child: const Icon(Icons.add)),
      ),
    );

Widget _formulario() => Builder(
      builder: (c) => Scaffold(
        appBar: AppBar(
            leading: const Icon(Icons.arrow_back), title: const Text('Nueva vaca')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Número *', prefixIcon: Icon(Icons.tag))),
            const SizedBox(height: 14),
            TextField(
                controller: TextEditingController(text: 'Brahman'),
                decoration: const InputDecoration(
                    labelText: 'Raza', prefixIcon: Icon(Icons.pets))),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              ChoiceChip(
                  label: const Text('Vacía'), selected: true, onSelected: (_) {}),
              ChoiceChip(
                  label: const Text('Preñada'), selected: false, onSelected: (_) {}),
              ChoiceChip(
                  label: const Text('En ordeño'), selected: false, onSelected: (_) {}),
            ]),
            const SizedBox(height: 14),
            Card(
              child: SwitchListTile(
                  value: true,
                  onChanged: (_) {},
                  title: const Text('Activa en el hato')),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () {}, child: const Text('Guardar')),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () {}, child: const Text('Cancelar')),
            const SizedBox(height: 20),
            const Card(
              child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.agriculture, color: AppColors.primary)),
                title: Text('Finca La Esperanza',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Dueño'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  setUpAll(() async {
    const r = 'C:/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', [
      '$r/roboto-regular.ttf',
      '$r/roboto-medium.ttf',
      '$r/roboto-bold.ttf',
      '$r/roboto-black.ttf',
    ]);
    // Los textos sin fuente propia usan "FlutterTest" en las pruebas (dibuja
    // rectángulos); en el teléfono usan Roboto. Se reemplaza para que la
    // vista previa se vea igual que en el teléfono.
    AppTheme.fuente = 'Roboto';
    await _fuente('MaterialIcons', ['$r/materialicons-regular.otf']);
  });

  for (final (nombre, pantalla) in [('panel', _panel), ('formulario', _formulario)]) {
    // Solo corre si se pide (VISTA_PREVIA=1); no es una prueba de lógica.
    testWidgets('vista $nombre',
        skip: Platform.environment['VISTA_PREVIA'] != '1', (tester) async {
      tester.view.physicalSize = const Size(412 * 2.0, 860 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      // Sombras reales (en pruebas se dibujan como un borde negro).
      debugDisableShadows = false;
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: pantalla(),
      ));
      // Cargar las imágenes de los animales antes de la foto.
      await tester.runAsync(() async {
        for (final e in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(e.image, tester.element(find.byWidget(e)));
        }
      });
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('vista_previa/$nombre.png'));
      debugDisableShadows = true; // la prueba exige dejarlo como estaba

    });
  }
}
