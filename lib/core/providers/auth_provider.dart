import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  AuthProvider() {
    _supabase.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  static const _desactivada =
      'Tu cuenta ha sido desactivada. Contacta al administrador.';

  Future<String?> signIn(String email, String password) async {
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // Un administrador pudo haber desactivado o eliminado este usuario.
      final uid = res.user?.id;
      if (uid != null) {
        final perfil = await _supabase
            .from('perfiles_usuario')
            .select('activo, eliminado')
            .eq('id', uid)
            .maybeSingle();
        if (perfil != null &&
            (perfil['activo'] == false || perfil['eliminado'] == true)) {
          await _supabase.auth.signOut();
          return _desactivada;
        }
      }
      return null;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('banned')) return _desactivada;
      if (e.message.toLowerCase().contains('invalid login')) {
        return 'Correo o contraseña incorrectos.';
      }
      return e.message;
    } catch (e) {
      return 'Error inesperado. Intenta de nuevo.';
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
