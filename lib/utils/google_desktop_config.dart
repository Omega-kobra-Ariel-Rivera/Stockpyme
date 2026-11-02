/// Inicio de sesión con Google en el programa de PC (Windows).
///
/// Los datos NO se escriben aquí: GitHub bloquea los secretos dentro del
/// código. Se guardan en GitHub → Settings → Secrets and variables → Actions:
///   GOOGLE_DESKTOP_CLIENT_ID      (termina en .apps.googleusercontent.com)
///   GOOGLE_DESKTOP_CLIENT_SECRET  (empieza con GOCSPX-)
/// y el workflow "Generar programa Windows" los pone al compilar.
class GoogleDesktopConfig {
  GoogleDesktopConfig._();

  static const String clientId =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');

  static const String clientSecret =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

  static bool get isConfigured => clientId.isNotEmpty && clientSecret.isNotEmpty;
}