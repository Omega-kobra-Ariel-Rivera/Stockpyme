/// Inicio de sesión con Google en el programa de PC (Windows).
///
/// Firebase no trae Google para Windows, así que el programa abre el
/// navegador, Google devuelve un código a la app y con eso se entra a la
/// misma cuenta de Firebase (la misma que usas en el celular).
///
/// Los datos NO se escriben aquí: GitHub bloquea los secretos dentro del
/// código. Se guardan en GitHub → Settings → Secrets and variables → Actions:
///   GOOGLE_DESKTOP_CLIENT_ID      (termina en .apps.googleusercontent.com)
///   GOOGLE_DESKTOP_CLIENT_SECRET  (empieza con GOCSPX-)
/// y el workflow "Generar programa Windows" los pone al compilar.
///
/// Para probar en tu PC con `flutter run -d windows`, agrega:
///   --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...
class GoogleDesktopConfig {
  GoogleDesktopConfig._();

  static const String clientId =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');

  static const String clientSecret =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

  static bool get isConfigured => clientId.isNotEmpty && clientSecret.isNotEmpty;
}
