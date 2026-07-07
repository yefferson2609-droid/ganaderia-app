import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/permiso_usuario.dart';
import '../repositories/permiso_usuario_repository.dart';

class PermisosProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _repo = PermisoUsuarioRepository();
  Map<String, PermisoUsuario> _permisos = {};

  PermisosProvider() {
    cargar();
    _supabase.auth.onAuthStateChange.listen((data) {
      cargar();
    });
  }

  Future<void> cargar() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      _permisos = {};
      notifyListeners();
      return;
    }
    final lista = await _repo.getByUsuario(uid);
    _permisos = {for (final p in lista) p.modulo: p};
    notifyListeners();
  }

  bool puedeVer(String modulo) => _permisos[modulo]?.puedeVer ?? false;
  bool puedeCrear(String modulo) => _permisos[modulo]?.puedeCrear ?? false;
  bool puedeEditar(String modulo) => _permisos[modulo]?.puedeEditar ?? false;
  bool puedeEliminar(String modulo) => _permisos[modulo]?.puedeEliminar ?? false;
}
