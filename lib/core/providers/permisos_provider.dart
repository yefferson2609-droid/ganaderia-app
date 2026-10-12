import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_db.dart';
import '../models/permiso_usuario.dart';
import '../repositories/permiso_usuario_repository.dart';
import 'finca_provider.dart';

class PermisosProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  Map<String, PermisoUsuario> _permisos = {};

  PermisosProvider() {
    cargar();
    _supabase.auth.onAuthStateChange.listen((data) {
      cargar();
    });
    // Los permisos son de cada finca.
    LocalDb.instance.fincaAbierta.addListener(cargar);
    FincaProvider.modoSoporte.addListener(notifyListeners);
  }

  /// El súper administrador en modo soporte puede todo.
  bool get _soporte => FincaProvider.modoSoporte.value;

  Future<void> cargar() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || !LocalDb.instance.abierta) {
      _permisos = {};
      notifyListeners();
      return;
    }
    final lista = await PermisoUsuarioRepository().getByUsuario(uid);
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
      _soporte ||
      (_permisos[modulo]?.puedeVer ?? _sinFila(modulo, accionBasica: true));
  bool puedeCrear(String modulo) =>
      _soporte ||
      (_permisos[modulo]?.puedeCrear ?? _sinFila(modulo, accionBasica: true));
  bool puedeEditar(String modulo) =>
      _soporte || (_permisos[modulo]?.puedeEditar ?? _sinFila(modulo));
  bool puedeEliminar(String modulo) =>
      _soporte || (_permisos[modulo]?.puedeEliminar ?? _sinFila(modulo));
}
