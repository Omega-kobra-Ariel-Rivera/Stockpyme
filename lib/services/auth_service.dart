import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../l10n/i18n.dart';
import '../utils/constants.dart';
import '../utils/google_desktop_config.dart';
import '../utils/platform.dart';
import 'google_desktop/google_desktop_sign_in.dart';

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
    return email.contains('@') ? email.split('@').first : tr('Usuario');
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
      throw AuthFailure(tr('No se pudo iniciar sesión. Revisa tu conexión.'));
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
      throw AuthFailure(tr('No se pudo crear la cuenta. Revisa tu conexión.'));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    } catch (_) {
      throw AuthFailure(tr('No se pudo enviar el correo. Revisa tu conexión.'));
    }
  }

  // ---------------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------------

  /// Se muestra el botón de Google (en el PC solo si está configurado).
  static bool get googleAvailable =>
      AppPlatform.hasGoogleSignIn ||
      (AppPlatform.isDesktop && GoogleDesktopConfig.isConfigured);

  Future<void> signInWithGoogle() async {
    if (!AppPlatform.hasGoogleSignIn && AppPlatform.isDesktop) {
      return _signInWithGoogleDesktop();
    }
    if (!AppPlatform.hasGoogleSignIn) {
      throw AuthFailure(tr('En el PC entra con tu correo y contraseña. Si creaste la cuenta con Google, usa "¿Olvidaste tu contraseña?" para crear una.'));
    }
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
      throw AuthFailure(tr('No se pudo entrar con Google. Inténtalo otra vez.'));
    }
  }

  /// Google en el PC: abre el navegador y entra con el token que devuelve.
  Future<void> _signInWithGoogleDesktop() async {
    if (!GoogleDesktopConfig.isConfigured) {
      throw AuthFailure(tr(
          'En el PC entra con tu correo y contraseña. Si creaste la cuenta con Google, usa "¿Olvidaste tu contraseña?" para crear una.'));
    }
    pendingBusinessName = null;
    final GoogleDesktopTokens? tokens;
    try {
      tokens = await googleDesktopSignIn(
        clientId: GoogleDesktopConfig.clientId,
        clientSecret: GoogleDesktopConfig.clientSecret,
        successHtml:
            '<!doctype html><meta charset="utf-8"><title>StockPyme</title>'
            '<body style="font-family:sans-serif;text-align:center;padding:60px">'
            '<h2>${tr('Listo, ya puedes volver a StockPyme.')}</h2>'
            '<p>${tr('Puedes cerrar esta pestaña.')}</p></body>',
      );
    } catch (_) {
      throw AuthFailure(tr('No se pudo entrar con Google. Inténtalo otra vez.'));
    }
    if (tokens == null) {
      throw AuthFailure(tr('Cancelaste el inicio de sesión con Google.'));
    }
    try {
      await _auth.signInWithCredential(GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      ));
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    } catch (_) {
      throw AuthFailure(tr('No se pudo entrar con Google. Inténtalo otra vez.'));
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
        return tr('El correo no es válido.');
      case 'user-disabled':
        return tr('Esta cuenta está desactivada. Escríbenos para revisarla.');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return tr('Correo o contraseña incorrectos.');
      case 'email-already-in-use':
        return tr('Ese correo ya tiene una cuenta. Inicia sesión.');
      case 'weak-password':
        return tr('La contraseña es muy débil. Usa al menos 6 caracteres.');
      case 'too-many-requests':
        return tr('Demasiados intentos. Espera unos minutos.');
      case 'network-request-failed':
        return tr('Sin conexión a internet.');
      case 'account-exists-with-different-credential':
        return tr('Ese correo ya está registrado con otro método. Entra con tu contraseña.');
      case 'popup-closed-by-user':
      case 'web-context-canceled':
      case 'canceled':
        return tr('Cancelaste el inicio de sesión con Google.');
      case 'operation-not-allowed':
        return tr('Este método de inicio de sesión no está activado en Firebase.');
      default:
        return tr('No se pudo iniciar sesión ({code}).', {'code': e.code});
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
