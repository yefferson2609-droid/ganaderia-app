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
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Buenos días, Yefferson',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const Text('viernes 17 de octubre',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(children: [
                    for (final (v, e, i, r) in [
                      ('72', 'animales', Icons.pets, false),
                      ('312 L', 'leche hoy', Icons.water_drop, false),
                      ('2', 'avisos', Icons.notifications_active, true),
                    ]) ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(i,
                                  size: 18,
                                  color: r
                                      ? const Color(0xFFFFC56B)
                                      : Colors.white70),
                              const SizedBox(height: 6),
                              Text(v,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800)),
                              Text(e,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      if (e != 'avisos') const SizedBox(width: 10),
                    ],
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            _seccion(c, 'Accesos rápidos'),
            Row(children: [
              for (final (t, i, col) in [
                ('Leche', Icons.water_drop, AppColors.info),
                ('Actividades', Icons.task_alt, AppColors.primary),
                ('Solicitudes', Icons.mark_email_unread_outlined, AppColors.secondary),
                ('Alertas', Icons.notifications_active, AppColors.warning),
              ])
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(children: [
                        CircleAvatar(
                            radius: 22,
                            backgroundColor: col.withValues(alpha: 0.13),
                            child: Icon(i, color: col, size: 24)),
                        const SizedBox(height: 8),
                        Text(t,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
            ]),
            _seccion(c, 'Avisos'),
            for (final (t, i, col) in [
              ('2 partos próximos', Icons.child_friendly, AppColors.info),
              ('1 vaca para secar', Icons.water_drop_outlined, AppColors.warning),
            ])
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: col.withValues(alpha: 0.13),
                      child: Icon(i, color: col, size: 22)),
                  title: Text(t,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right),
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

  // Ícono de la app (512 px): hoja de pasto blanca sobre verde, esquinas
  // redondeadas y fondo transparente. Se reduce luego a los tamaños de
  // android/app/src/main/res/mipmap-*.
  testWidgets('icono app',
      skip: Platform.environment['VISTA_PREVIA'] != '1', (tester) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: const ValueKey('icono'),
          child: Container(
            width: 512,
            height: 512,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(112),
            ),
            child: const Icon(Icons.grass_rounded,
                size: 330, color: Colors.white),
          ),
        ),
      ),
    ));
    await expectLater(find.byKey(const ValueKey('icono')),
        matchesGoldenFile('vista_previa/icono.png'));
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
