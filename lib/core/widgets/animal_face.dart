import 'package:flutter/material.dart';

/// Imagen de cada especie, en assets/images.
const _imagenes = {
  'vaca': 'assets/images/vaca_face.jpg',
  'toro': 'assets/images/toro_face.jpg',
  'ternero': 'assets/images/becerro_face.jpg',
  'caballo': 'assets/images/caballo_face.jpg',
  'cerdo': 'assets/images/cerdo_face.jpg',
  'ovejo': 'assets/images/ovejo_face.jpg',
};

/// Cara circular del animal. [estadoColor] dibuja un borde según su estado.
class AnimalFace extends StatelessWidget {
  final String tipo;
  final double size;
  final Color? estadoColor;

  const AnimalFace({
    super.key,
    required this.tipo,
    this.size = 44,
    this.estadoColor,
  });

  @override
  Widget build(BuildContext context) {
    final path = _imagenes[tipo];
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
      child: path == null
          ? Icon(Icons.pets, size: size * 0.6)
          : Image.asset(path, fit: BoxFit.cover),
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
