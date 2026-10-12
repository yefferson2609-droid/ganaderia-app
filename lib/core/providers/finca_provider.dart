import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_db.dart';
import '../models/mi_finca.dart';

/// Fincas del usuario y la finca abierta.
///
/// La lista se guarda en el teléfono para poder entrar sin internet; cuando
/// hay conexión se actualiza desde Supabase. Si la finca abierta deja de
/// estar disponible (suspendida, acceso quitado), se cierra.
///
/// El súper administrador (vendedor) además puede abrir cualquier finca en
/// "modo soporte" desde su panel.
class FincaProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  /// true mientras la finca abierta lo está en modo soporte. Lo usa
  /// [PermisosProvider] para dar acceso completo.
  static final modoSoporte = ValueNotifier<bool>(false);

  List<MiFinca> _fincas = [];
  MiFinca? _soporte;
  bool _esSuperAdmin = false;
  bool _cargando = false;
  String? _error;

  List<MiFinca> get fincas => _fincas;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get esSuperAdmin => _esSuperAdmin;

  MiFinca? get actual {
    final id = LocalDb.instance.fincaId;
    if (id == null) return null;
    if (_soporte?.fincaId == id) return _soporte;
    for (final f in _fincas) {
      if (f.fincaId == id) return f;
    }
    return null;
  }

  static String _kLista(String uid) => 'mis_fincas:$uid';
  static String _kActual(String uid) => 'finca_actual:$uid';
  static String _kSoporte(String uid) => 'finca_soporte:$uid';
  static String _kSuper(String uid) => 'super_admin:$uid';

  FincaProvider() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _cargarGuardadas().then((_) => cargar());
      }
      if (data.event == AuthChangeEvent.signedOut) {
        _fincas = [];
        _soporte = null;
        _esSuperAdmin = false;
        modoSoporte.value = false;
        notifyListeners();
      }
    });
    LocalDb.instance.fincaAbierta.addListener(_alCambiarFinca);
    _cargarGuardadas().then((_) => cargar());
  }

  void _alCambiarFinca() {
    final id = LocalDb.instance.fincaId;
    modoSoporte.value = id != null && _soporte?.fincaId == id;
    notifyListeners();
  }

  /// Al iniciar la app: abre la última finca usada, sin esperar internet.
  static Future<void> abrirUltima() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_kActual(uid));
      if (id != null) await LocalDb.instance.abrirFinca(id);
    } catch (_) {}
  }

  Future<void> _cargarGuardadas() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_kLista(uid));
      if (s != null) {
        _fincas = (jsonDecode(s) as List)
            .map((e) => MiFinca.fromServidor((e as Map).cast<String, dynamic>()))
            .toList();
      }
      final sop = prefs.getString(_kSoporte(uid));
      _soporte = sop == null
          ? null
          : MiFinca.fromServidor((jsonDecode(sop) as Map).cast<String, dynamic>());
      _esSuperAdmin = prefs.getBool(_kSuper(uid)) ?? false;
      _alCambiarFinca();
    } catch (_) {}
  }

  /// Trae las fincas del usuario desde Supabase.
  Future<void> cargar() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || _cargando) return;
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _supabase
          .from('miembros_finca')
          .select('id, rol, estado, fincas(id, nombre, codigo, estado, prueba_hasta)')
          .eq('usuario_id', uid);
      _fincas = rows.map(MiFinca.fromServidor).toList()
        ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      _esSuperAdmin = await _supabase.rpc('es_super_admin') == true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kLista(uid), jsonEncode(_fincas.map((f) => f.toJson()).toList()));
      await prefs.setBool(_kSuper(uid), _esSuperAdmin);
      if (!_esSuperAdmin && _soporte != null) {
        _soporte = null;
        await prefs.remove(_kSoporte(uid));
      }

      // La finca abierta ya no está disponible: se cierra.
      final abierta = LocalDb.instance.fincaId;
      if (abierta != null && !(actual?.usable ?? false)) {
        await LocalDb.instance.cerrar();
        await prefs.remove(_kActual(uid));
      }
    } catch (e) {
      _error = 'No se pudo actualizar la lista de fincas. Revisa el internet.';
    }
    _cargando = false;
    _alCambiarFinca();
  }

  Future<void> abrir(MiFinca finca) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || !finca.usable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (finca.soporte) {
        _soporte = finca;
        await prefs.setString(_kSoporte(uid), jsonEncode(finca.toJson()));
      }
      await prefs.setString(_kActual(uid), finca.fincaId);
    } catch (_) {}
    await LocalDb.instance.abrirFinca(finca.fincaId);
    _alCambiarFinca();
  }

  /// Vuelve a la lista de fincas (para cambiar de finca).
  Future<void> salirDeFinca() async {
    final uid = _supabase.auth.currentUser?.id;
    await LocalDb.instance.cerrar();
    if (uid != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kActual(uid));
      } catch (_) {}
    }
    _alCambiarFinca();
  }

  /// Registra una finca nueva (queda en revisión). Devuelve un error o null.
  Future<String?> crearFinca(String nombreFinca, String tuNombre) async {
    try {
      await _supabase.rpc('crear_finca', params: {
        'p_nombre_finca': nombreFinca,
        'p_nombre_usuario': tuNombre,
      });
      await cargar();
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'No se pudo registrar la finca. Revisa el internet.';
    }
  }

  /// Pide entrar a una finca con su código. Devuelve un error o null.
  Future<String?> unirse(String codigo, String tuNombre) async {
    try {
      await _supabase.rpc('unirse_con_codigo', params: {
        'p_codigo': codigo,
        'p_nombre_usuario': tuNombre,
      });
      await cargar();
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'No se pudo enviar la solicitud. Revisa el internet.';
    }
  }
}
