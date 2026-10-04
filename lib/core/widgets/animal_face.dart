import 'dart:io';

import 'package:flutter/material.dart';
import '../services/foto_animal_service.dart';

/// Imagen de cada especie, en assets/images.
const _imagenes = {
  'vaca': 'assets/images/vaca_face.jpg',
  'toro': 'assets/images/toro_face.jpg',
  'ternero': 'assets/images/becerro_face.jpg',
  'caballo': 'assets/images/caballo_face.jpg',
  'cerdo': 'assets/images/cerdo_face.jpg',
  'ovejo': 'assets/images/ovejo_face.jpg',
};

/// Cara circular del animal: su foto si tiene, o el dibujo de la especie.
/// [estadoColor] dibuja un borde según su estado.
class AnimalFace extends StatelessWidget {
  final String tipo;
  final double size;
  final Color? estadoColor;
  final String? fotoLocal;
  final String? fotoUrl;

  const AnimalFace({
    super.key,
    required this.tipo,
    this.size = 44,
    this.estadoColor,
    this.fotoLocal,
    this.fotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final path = _imagenes[tipo];
    final dibujo = path == null
        ? Icon(Icons.pets, size: size * 0.6)
        : Image.asset(path, fit: BoxFit.cover);
    Widget imagen = dibujo;
    if (fotoLocal != null && File(fotoLocal!).existsSync()) {
      imagen = Image.file(File(fotoLocal!),
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => dibujo);
    } else if (fotoUrl != null) {
      imagen = Image.network(fotoUrl!,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => dibujo);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: estadoColor != null
            ? Border.all(color: estadoColor!, width: 2)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: imagen,
    );
  }
}

/// Foto grande de la ficha con un botón de cámara para cambiarla.
class AnimalFaceEditable extends StatelessWidget {
  final String tipo;
  final String id;
  final String? fotoLocal;
  final String? fotoUrl;
  final Color? estadoColor;
  final VoidCallback onCambio;

  const AnimalFaceEditable({
    super.key,
    required this.tipo,
    required this.id,
    this.fotoLocal,
    this.fotoUrl,
    this.estadoColor,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> cambiar() async {
      final cambio = await FotoAnimalService.elegir(context,
          tipo: tipo,
          id: id,
          tieneFoto: fotoLocal != null || fotoUrl != null);
      if (cambio) onCambio();
    }

    return GestureDetector(
      onTap: cambiar,
      child: Stack(children: [
        AnimalFace(
            tipo: tipo,
            size: 72,
            estadoColor: estadoColor,
            fotoLocal: fotoLocal,
            fotoUrl: fotoUrl),
        Positioned(
          right: 0,
          bottom: 0,
          child: CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.photo_camera, size: 14, color: Colors.white),
          ),
        ),
      ]),
    );
  }
}

/// Logo del hierro de la finca.
class HierroLogo extends StatelessWidget {
  final double size;
  const HierroLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.asset('assets/images/hierro_logo.jpeg',
          width: size, height: size, fit: BoxFit.cover),
    );
  }
}
