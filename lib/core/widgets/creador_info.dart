import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/perfil_usuario_repository.dart';

/// Nombre visible de un usuario a partir de su id (o null si no se conoce).
Future<String?> nombreUsuario(String? id) async {
  if (id == null) return null;
  final p = await PerfilUsuarioRepository().getById(id);
  if (p == null) return null;
  return p.nombre.isNotEmpty ? p.nombre : p.correo;
}

String haceCuanto(DateTime fecha) {
  final d = DateTime.now().difference(fecha);
  if (d.inMinutes < 1) return 'justo ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  if (d.inDays < 30) return 'hace ${d.inDays} día${d.inDays == 1 ? '' : 's'}';
  return 'el ${DateFormat('dd/MM/yyyy').format(fecha)}';
}

/// Línea pequeña con quién creó y quién actualizó un registro.
class CreadorInfo extends StatelessWidget {
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreadorInfo({
    super.key,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String?>>(
      future: Future.wait([nombreUsuario(createdBy), nombreUsuario(updatedBy)]),
      builder: (context, snap) {
        final creador = snap.data?[0];
        final editor = snap.data?[1];
        final style = Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.grey[600]);
        final editado = updatedAt.difference(createdAt).inMinutes > 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creado por ${creador ?? 'usuario desconocido'} · '
              '${DateFormat('dd/MM/yyyy').format(createdAt)}',
              style: style,
            ),
            if (editado)
              Text(
                updatedAt.difference(DateTime.now()).inMinutes.abs() < 1
                    ? 'Actualizado justo ahora'
                    : 'Actualizado ${haceCuanto(updatedAt)}'
                        '${editor != null ? ' por $editor' : ''}',
                style: style,
              ),
          ],
        );
      },
    );
  }
}
