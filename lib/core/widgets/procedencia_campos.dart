import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/procedencia.dart';
import '../services/foto_animal_service.dart';
import '../theme/app_theme.dart';
import '../utils/auditoria.dart';
import 'animal_face.dart';

/// Estado de los campos de procedencia en los formularios de vacas, toros
/// y levante: origen, registro y padres de fuera de la finca.
class ProcedenciaControl {
  String? origen;
  bool padreExterno = false;
  bool madreExterna = false;
  final registro = TextEditingController();
  final padreNombre = TextEditingController();
  final padreRegistro = TextEditingController();
  final padreRaza = TextEditingController();
  final madreNombre = TextEditingController();
  final madreRegistro = TextEditingController();
  final madreRaza = TextEditingController();

  void cargar(Procedencia p) {
    origen = p.origen;
    registro.text = p.registro ?? '';
    padreExterno = p.padreExterno;
    padreNombre.text = p.padreNombre ?? '';
    padreRegistro.text = p.padreRegistro ?? '';
    padreRaza.text = p.padreRaza ?? '';
    madreExterna = p.madreExterna;
    madreNombre.text = p.madreNombre ?? '';
    madreRegistro.text = p.madreRegistro ?? '';
    madreRaza.text = p.madreRaza ?? '';
  }

  /// Lo que se guarda. Si el padre/madre no es de fuera, sus datos de
  /// fuera se borran.
  Procedencia get valor => Procedencia(
        origen: origen,
        registro: textoONull(registro.text),
        padreNombre: padreExterno ? textoONull(padreNombre.text) : null,
        padreRegistro: padreExterno ? textoONull(padreRegistro.text) : null,
        padreRaza: padreExterno ? textoONull(padreRaza.text) : null,
        madreNombre: madreExterna ? textoONull(madreNombre.text) : null,
        madreRegistro: madreExterna ? textoONull(madreRegistro.text) : null,
        madreRaza: madreExterna ? textoONull(madreRaza.text) : null,
      );

  void dispose() {
    for (final c in [
      registro,
      padreNombre,
      padreRegistro,
      padreRaza,
      madreNombre,
      madreRegistro,
      madreRaza,
    ]) {
      c.dispose();
    }
  }
}

/// Origen (nacido aquí / comprado / importado) y número de registro.
class OrigenCampos extends StatelessWidget {
  final ProcedenciaControl control;
  final bool hembra;
  final VoidCallback onCambio;
  const OrigenCampos({
    super.key,
    required this.control,
    required this.hembra,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Origen', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final o in Procedencia.origenes)
            ChoiceChip(
              label: Text(Procedencia.origenTexto(o, hembra: hembra)),
              selected: control.origen == o,
              onSelected: (sel) {
                control.origen = sel ? o : null;
                onCambio();
              },
            ),
        ]),
        const SizedBox(height: 16),
        TextFormField(
          controller: control.registro,
          decoration: const InputDecoration(
            labelText: 'Número de registro (opcional)',
            helperText: 'Registro genealógico de la asociación de la raza',
            prefixIcon: Icon(Icons.verified_outlined),
          ),
        ),
      ],
    );
  }
}

/// Padre o madre: de la finca (desplegable) o de fuera (nombre, registro y
/// raza), con un interruptor para cambiar.
class PadreCampo extends StatelessWidget {
  final bool esPadre;
  final bool externo;
  final ValueChanged<bool> onExterno;
  final Widget selectorFinca;
  final TextEditingController nombre;
  final TextEditingController registro;
  final TextEditingController raza;

  const PadreCampo({
    super.key,
    required this.esPadre,
    required this.externo,
    required this.onExterno,
    required this.selectorFinca,
    required this.nombre,
    required this.registro,
    required this.raza,
  });

  @override
  Widget build(BuildContext context) {
    final quien = esPadre ? 'Padre' : 'Madre';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: Icon(esPadre ? Icons.male : Icons.female,
                  color: AppColors.primary),
              title: Text(quien,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(externo
                  ? 'De fuera de la finca (comprado, importado o semen)'
                  : 'De la finca · activa para uno de fuera'),
              value: externo,
              onChanged: onExterno,
            ),
            if (!externo)
              selectorFinca
            else ...[
              TextFormField(
                controller: nombre,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                    labelText: 'Nombre del ${esPadre ? 'padre' : 'la madre'}',
                    prefixIcon: const Icon(Icons.badge_outlined)),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: registro,
                decoration: const InputDecoration(
                    labelText: 'Número de registro',
                    prefixIcon: Icon(Icons.verified_outlined)),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: raza,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Raza', prefixIcon: Icon(Icons.pets)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Foto al registrar un animal nuevo: muestra la elegida o la cara de la
/// especie, con un botón de cámara.
class FotoAlRegistrar extends StatelessWidget {
  final String tipo;
  final String? ruta;
  final ValueChanged<String?> onCambio;
  const FotoAlRegistrar({
    super.key,
    required this.tipo,
    required this.ruta,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> elegir() async {
      final r = await FotoAnimalService.elegirArchivo(context);
      if (r != null) onCambio(r);
    }

    final cara = ruta == null
        ? AnimalFace(tipo: tipo, size: 96)
        : Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: Image.file(File(ruta!), fit: BoxFit.cover),
          );
    return Column(children: [
      GestureDetector(
        onTap: elegir,
        child: Stack(children: [
          cara,
          const Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.photo_camera, size: 18, color: Colors.white),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextButton(
            onPressed: elegir,
            child: Text(ruta == null ? 'Agregar foto' : 'Cambiar foto')),
        if (ruta != null)
          TextButton(
            onPressed: () => onCambio(null),
            child:
                const Text('Quitar', style: TextStyle(color: AppColors.danger)),
          ),
      ]),
    ]);
  }
}

/// Campo de fecha de nacimiento con botón para borrarla.
class FechaNacimientoCampo extends StatelessWidget {
  final DateTime? fecha;
  final VoidCallback onElegir;
  final VoidCallback onBorrar;
  const FechaNacimientoCampo({
    super.key,
    required this.fecha,
    required this.onElegir,
    required this.onBorrar,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onElegir,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Fecha de nacimiento',
          prefixIcon: const Icon(Icons.calendar_today),
          suffixIcon: fecha == null
              ? null
              : IconButton(
                  tooltip: 'Dejar sin fecha',
                  icon: const Icon(Icons.close),
                  onPressed: onBorrar,
                ),
        ),
        child: Text(
          fecha != null
              ? DateFormat('dd/MM/yyyy').format(fecha!)
              : 'Sin fecha · toca para elegir',
          style: TextStyle(color: fecha != null ? null : AppColors.textoSuave),
        ),
      ),
    );
  }
}
