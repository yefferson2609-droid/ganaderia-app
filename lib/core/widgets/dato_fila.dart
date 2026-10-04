import 'package:flutter/material.dart';

/// Fila "Etiqueta   Valor" para las fichas de los animales.
class DatoFila extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const DatoFila(this.label, this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontWeight: FontWeight.w500, color: color)),
          ),
        ],
      ),
    );
  }
}
