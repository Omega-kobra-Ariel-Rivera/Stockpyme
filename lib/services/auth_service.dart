import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/constants.dart';

/// Error de inicio de sesión con un mensaje listo para mostrar.
class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cuentas de usuario: email y contraseña, o cuenta de Google.
class AuthService extends ChangeNotifier {
  AuthService() {
    _sub = _auth.authStateChanges().listen(_onUser);
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _sub;

  User? _user;
  bool _ready = false;
  bool _isAdmin = false;

  /// Datos escritos al crear la cuenta; se guardan en el perfil en la nube.
  String? pendingBusinessName;

  User? get user => _user;
  bool get ready => _ready;
  bool get isSignedIn => _user != null;
  bool get isAdmin => _isAdmin;

  String get displayName {
    final name = _user?.displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = _user?.email ?? '';
    return email.contains('@') ? email.split('@').first : 'Usuario';
  }

  String get email => _user?.email ?? '';

  bool get usesGoogle =>
      _user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  Future<void> _onUser(User? user) async {
    _user = user;
    _isAdmin = false;
    _ready = true;
    notifyListeners();
    if (user != null) await refreshAdmin();
  }

  /// Un correo es administrador si existe el documento admins/{correo}.
  Future<void> refreshAdmin() async {
    final email = _user?.email?.toLowerCase();
    if (email == null || email.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(CloudPaths.admins)
          .doc(email)
          .get();
      final admin = doc.exists;
      if (admin != _isAdmin) {
        _isAdmin = admin;
        notifyListeners();
      }
    } catch (_) {
      // Sin conexión o sin permiso: no es administrador.
    }
  }

  // ---------------------------------------------------------------------------
  // Email y contraseña
  // ---------------------------------------------------------------------------

  Future<void> signInWithEmail(String email, String password) async {
    pendingBusinessName = null;
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    } catch (_) {
      throw AuthFailure('No se pudo iniciar sesión. Revisa tu conexión.');
    }
  }

  Future<void> register({
    required String name,
    required String businessName,
    required String email,
    required String password,
  }) async {
    pendingBusinessName = businessName.trim();
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await result.user?.updateDisplayName(name.trim());
      await result.user?.reload();
      _user = _auth.currentUser;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    } catch (_) {
      throw AuthFailure('No se pudo crear la cuenta. Revisa tu conexión.');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    } catch (_) {
      throw AuthFailure('No se pudo enviar el correo. Revisa tu conexión.');
    }
  }

  // ---------------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});
    pendingBusinessName = null;
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(provider);
      } else {
        await _auth.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    } catch (_) {
      throw AuthFailure('No se pudo entrar con Google. Inténtalo otra vez.');
    }
  }

  Future<void> signOut() async {
    pendingBusinessName = null;
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'user-disabled':
        return 'Esta cuenta está desactivada. Escríbenos para revisarla.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ese correo ya tiene una cuenta. Inicia sesión.';
      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      case 'account-exists-with-different-credential':
        return 'Ese correo ya está registrado con otro método. Entra con tu contraseña.';
      case 'popup-closed-by-user':
      case 'web-context-canceled':
      case 'canceled':
        return 'Cancelaste el inicio de sesión con Google.';
      case 'operation-not-allowed':
        return 'Este método de inicio de sesión no está activado en Firebase.';
      default:
        return 'No se pudo iniciar sesión (${e.code}).';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
