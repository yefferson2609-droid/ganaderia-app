import 'package:flutter/material.dart';
import '../config/ajustes.dart';

/// Campo de raza (opcional): se escribe libre o se elige de la lista.
class RazaField extends StatelessWidget {
  final TextEditingController controller;
  const RazaField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Raza (opcional)',
        prefixIcon: const Icon(Icons.category_outlined),
        suffixIcon: PopupMenuButton<String>(
          tooltip: 'Elegir raza',
          icon: const Icon(Icons.arrow_drop_down),
          onSelected: (r) => controller.text = r,
          itemBuilder: (_) => kRazasSugeridas
              .map((r) => PopupMenuItem(value: r, child: Text(r)))
              .toList(),
        ),
      ),
    );
  }
}
