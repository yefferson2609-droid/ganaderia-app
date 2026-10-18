import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'animal_face.dart';

/// Franja verde con la marca, para las pantallas de entrada (iniciar
/// sesión, crear cuenta, Mis fincas).
class EncabezadoMarca extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final double logo;
  final Widget? arriba; // p. ej. botones (atrás, menú)
  /// Espacio sobre el logo (bajo una barra superior conviene menos).
  final double espacioArriba;
  const EncabezadoMarca({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.logo = 64,
    this.arriba,
    this.espacioArriba = 32,
  });

  @override
  Widget build(BuildContext context) {
    final fondo =
        Theme.of(context).appBarTheme.backgroundColor ?? AppColors.primaryDark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + espacioArriba, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (arriba != null) ...[arriba!, const SizedBox(height: 8)],
          MarcaLogo(size: logo),
          const SizedBox(height: 16),
          Text(titulo,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(subtitulo!,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
          ],
        ],
      ),
    );
  }
}
