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

  // El administrador (quien gestiona usuarios) tiene acceso a los módulos
  // nuevos aunque aún no tenga una fila de permiso para ellos.
  bool get _esAdmin => _permisos['usuarios']?.puedeVer ?? false;

  // Sin fila de permiso, estos módulos quedan cerrados salvo para el admin.
  static const _modulosRestringidos = {'usuarios', 'reportes'};

  bool _sinFila(String modulo, {bool accionBasica = false}) {
    if (_esAdmin) return true;
    if (_modulosRestringidos.contains(modulo)) return false;
    // Los módulos de trabajo diario siempre se mostraban: se conserva ese
    // comportamiento cuando no hay una fila que diga lo contrario. Editar y
    // eliminar en actividades/solicitudes (aprobar, reasignar) es del admin.
    if (kModulosAbiertos.contains(modulo)) return accionBasica;
    return true;
  }

  bool puedeVer(String modulo) =>
      _permisos[modulo]?.puedeVer ?? _sinFila(modulo, accionBasica: true);
  bool puedeCrear(String modulo) =>
      _permisos[modulo]?.puedeCrear ?? _sinFila(modulo, accionBasica: true);
  bool puedeEditar(String modulo) =>
      _permisos[modulo]?.puedeEditar ?? _sinFila(modulo);
  bool puedeEliminar(String modulo) =>
      _permisos[modulo]?.puedeEliminar ?? _sinFila(modulo);
}
