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
class FincaProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<MiFinca> _fincas = [];
  bool _cargando = false;
  String? _error;

  List<MiFinca> get fincas => _fincas;
  bool get cargando => _cargando;
  String? get error => _error;

  MiFinca? get actual {
    final id = LocalDb.instance.fincaId;
    for (final f in _fincas) {
      if (f.fincaId == id) return f;
    }
    return null;
  }

  static String _kLista(String uid) => 'mis_fincas:$uid';
  static String _kActual(String uid) => 'finca_actual:$uid';

  FincaProvider() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) cargar();
      if (data.event == AuthChangeEvent.signedOut) {
        _fincas = [];
        notifyListeners();
      }
    });
    LocalDb.instance.fincaAbierta.addListener(notifyListeners);
    _cargarGuardadas().then((_) => cargar());
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
      if (s == null) return;
      _fincas = (jsonDecode(s) as List)
          .map((e) => MiFinca.fromServidor((e as Map).cast<String, dynamic>()))
          .toList();
      notifyListeners();
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kLista(uid), jsonEncode(_fincas.map((f) => f.toJson()).toList()));

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
    notifyListeners();
  }

  Future<void> abrir(MiFinca finca) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || !finca.usable) return;
    await LocalDb.instance.abrirFinca(finca.fincaId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActual(uid), finca.fincaId);
    } catch (_) {}
    notifyListeners();
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
    notifyListeners();
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
