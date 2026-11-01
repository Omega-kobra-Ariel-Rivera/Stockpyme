import 'package:flutter/foundation.dart';

/// Qué puede hacer la app según dónde se ejecuta (teléfono, web o PC).
class AppPlatform {
  AppPlatform._();

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Programa de escritorio (Windows, macOS o Linux).
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Escáner con la cámara. En Windows se usa un lector USB de códigos
  /// de barras, que escribe el código como si fuera un teclado.
  static bool get hasCameraScanner =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Inicio de sesión con Google (Firebase no lo ofrece en Windows).
  static bool get hasGoogleSignIn =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}
