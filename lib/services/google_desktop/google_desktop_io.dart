import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Tokens de Google para entrar a Firebase.
class GoogleDesktopTokens {
  GoogleDesktopTokens(this.idToken, this.accessToken);
  final String idToken;
  final String? accessToken;
}

String _random(int length) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  final rnd = Random.secure();
  return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
}

/// Abre Google en el navegador y espera la respuesta en 127.0.0.1
/// (flujo OAuth para apps de escritorio, con PKCE).
/// Devuelve null si la persona cancela o no responde a tiempo.
Future<GoogleDesktopTokens?> googleDesktopSignIn({
  required String clientId,
  required String clientSecret,
  required String successHtml,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final redirectUri = 'http://127.0.0.1:${server.port}';
  final verifier = _random(64);
  final challenge = base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');
  final state = _random(24);

  try {
    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'prompt': 'select_account',
    });
    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir el navegador.');
    }

    // Espera a que Google vuelva con el código (ignora otras peticiones,
    // por ejemplo /favicon.ico).
    String? code;
    String? error;
    await for (final request in server.timeout(const Duration(minutes: 5))) {
      final params = request.uri.queryParameters;
      if (!params.containsKey('code') && !params.containsKey('error')) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      if (params['state'] != state) {
        error = 'state';
      } else {
        code = params['code'];
        error = params['error'];
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(successHtml);
      await request.response.close();
      break;
    }
    if (code == null || error != null) return null;

    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'code': code,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': verifier,
      },
    ).timeout(const Duration(seconds: 20));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final idToken = data['id_token'] as String?;
    if (response.statusCode != 200 || idToken == null) {
      throw Exception(data['error_description'] ?? data['error'] ?? 'Google no respondió.');
    }
    return GoogleDesktopTokens(idToken, data['access_token'] as String?);
  } on TimeoutException {
    return null;
  } finally {
    await server.close(force: true);
  }
}
