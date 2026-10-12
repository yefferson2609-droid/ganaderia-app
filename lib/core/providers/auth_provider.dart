import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_db.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  AuthProvider() {
    _supabase.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return _traducir(e);
    } catch (e) {
      return 'Error inesperado. Intenta de nuevo.';
    }
  }

  /// Crea la cuenta. Devuelve (error, debeConfirmarCorreo).
  Future<(String?, bool)> signUp(
      String nombre, String email, String password) async {
    try {
      final r = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'nombre': nombre},
      );
      // Sin sesión: Supabase pide confirmar el correo antes de entrar.
      return (null, r.session == null);
    } on AuthException catch (e) {
      return (_traducir(e), false);
    } catch (e) {
      return ('No se pudo crear la cuenta. Revisa el internet.', false);
    }
  }

  /// Nombre que el usuario escribió al registrarse.
  String get nombreRegistrado =>
      (currentUser?.userMetadata?['nombre'] as String?)?.trim() ?? '';

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } finally {
      await LocalDb.instance.cerrar();
    }
  }

  String _traducir(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Correo o contraseña incorrectos';
    if (m.contains('email not confirmed')) {
      return 'Falta confirmar tu correo: abre el enlace que te enviamos';
    }
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'Ese correo ya tiene cuenta. Ingresa con tu contraseña';
    }
    if (m.contains('password should be') || m.contains('weak')) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (m.contains('rate limit')) {
      return 'Demasiados intentos. Espera unos minutos';
    }
    return e.message;
  }
}
