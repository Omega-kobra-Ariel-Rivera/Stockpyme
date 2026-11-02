/// Tokens de Google para entrar a Firebase.
class GoogleDesktopTokens {
  GoogleDesktopTokens(this.idToken, this.accessToken);
  final String idToken;
  final String? accessToken;
}

/// En la web no se usa (allí Firebase abre Google directamente).
Future<GoogleDesktopTokens?> googleDesktopSignIn({
  required String clientId,
  required String clientSecret,
  required String successHtml,
}) async =>
    null;
