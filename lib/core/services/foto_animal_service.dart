import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/local_db.dart';
import '../utils/auditoria.dart';

/// Tablas de animales que admiten foto, por tipo.
const _tablas = {
  'vaca': 'vacas',
  'toro': 'toros',
  'ternero': 'terneros',
  'caballo': 'caballos',
};

/// Guarda la foto en el teléfono y la deja pendiente de subir.
/// Se sube a Supabase Storage (bucket "animales") al sincronizar.
class FotoAnimalService {
  Future<void> _actualizar(String tipo, String id, Map<String, dynamic> datos) async {
    final tabla = _tablas[tipo]!;
    await LocalDb.instance.db.update(
      tabla,
      filaEditada({...datos, 'updated_at': DateTime.now().toIso8601String()}),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> guardar(String tipo, String id, String origen) async {
    final dir = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'animales'));
    await dir.create(recursive: true);
    final destino = p.join(
        dir.path, '$tipo-$id-${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(origen).copy(destino);
    await _actualizar(tipo, id, {'foto_local': destino, 'foto_url': null});
  }

  Future<void> quitar(String tipo, String id) =>
      _actualizar(tipo, id, {'foto_local': null, 'foto_url': null});

  /// Menú Cámara / Galería / Quitar. Devuelve true si cambió la foto.
  static Future<bool> elegir(BuildContext context,
      {required String tipo, required String id, required bool tieneFoto}) async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(ctx, 'camara'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(ctx, 'galeria'),
          ),
          if (tieneFoto)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Quitar foto'),
              onTap: () => Navigator.pop(ctx, 'quitar'),
            ),
        ]),
      ),
    );
    if (opcion == null) return false;
    final servicio = FotoAnimalService();
    if (opcion == 'quitar') {
      await servicio.quitar(tipo, id);
      return true;
    }
    try {
      final x = await ImagePicker().pickImage(
        source: opcion == 'camara' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (x == null) return false;
      await servicio.guardar(tipo, id, x.path);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir la cámara/galería: $e')));
      }
      return false;
    }
  }
}
