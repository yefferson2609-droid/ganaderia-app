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

  Future<String?> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error inesperado. Intenta de nuevo.';
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
