import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Etiqueta pequeña de color (estado, preñez, avisos...).
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData? icono;

  /// Para fondos oscuros (portada verde de las fichas).
  final bool sobreOscuro;

  const Etiqueta(this.texto, this.color,
      {super.key, this.icono, this.sobreOscuro = false});

  @override
  Widget build(BuildContext context) {
    // Sobre la portada verde: etiqueta blanca con el texto en su color.
    final fondo = sobreOscuro ? Colors.white : color.withValues(alpha: 0.13);
    final tinta = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icono != null) ...[
          Icon(icono, size: 13, color: tinta),
          const SizedBox(width: 4),
        ],
        Text(texto,
            style: TextStyle(
                color: tinta, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Animal en una lista: cara o foto, título grande, etiquetas de color y
/// una línea de detalle.
class AnimalTile extends StatelessWidget {
  final Widget cara;
  final String titulo;
  final String? subtitulo; // al lado del título, p. ej. "#123"
  final List<Widget> etiquetas;
  final String? detalle;
  final Widget? trailing;
  final VoidCallback onTap;
  /// Mantener presionado (p. ej. para seleccionar varios y venderlos).
  final VoidCallback? onLongPress;
  /// null = sin selección; true/false = modo selección (muestra la casilla).
  final bool? seleccionado;

  const AnimalTile({
    super.key,
    required this.cara,
    required this.titulo,
    this.subtitulo,
    this.etiquetas = const [],
    this.detalle,
    this.trailing,
    required this.onTap,
    this.onLongPress,
    this.seleccionado,
  });

  @override
  Widget build(BuildContext context) {
    final sel = seleccionado;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: sel == true ? AppColors.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(children: [
            cara,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: titulo,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      if (subtitulo != null)
                        TextSpan(
                            text: '  $subtitulo',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textoSuave,
                                fontWeight: FontWeight.w600)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (etiquetas.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: etiquetas),
                  ],
                  if (detalle != null && detalle!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(detalle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            if (sel != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                    sel ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: sel ? AppColors.primary : AppColors.textoSuave),
              )
            else
              trailing ??
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child:
                        Icon(Icons.chevron_right, color: AppColors.textoSuave),
                  ),
          ]),
        ),
      ),
    );
  }
}

/// Portada verde (tarjeta redondeada) de la ficha de un animal: cara o foto
/// grande, título, detalle y etiquetas. Va como primer elemento de la lista.
class PortadaAnimal extends StatelessWidget {
  final Widget cara;
  final String titulo;
  final String? detalle;
  final List<Widget> etiquetas;

  const PortadaAnimal({
    super.key,
    required this.cara,
    required this.titulo,
    this.detalle,
    this.etiquetas = const [],
  });

  @override
  Widget build(BuildContext context) {
    final fondo =
        Theme.of(context).appBarTheme.backgroundColor ?? AppColors.primaryDark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
              color: Colors.white24, shape: BoxShape.circle),
          child: cara,
        ),
        const SizedBox(height: 10),
        Text(titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        if (detalle != null && detalle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(detalle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
        if (etiquetas.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: etiquetas),
        ],
      ]),
    );
  }
}
