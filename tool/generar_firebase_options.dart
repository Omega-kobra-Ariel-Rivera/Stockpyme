// Genera lib/firebase_options.dart a partir de la configuración de Firebase,
// sin copiar claves a mano (reemplaza a "flutterfire configure").
//
// Antes, en la carpeta del proyecto:
//   firebase apps:sdkconfig ANDROID <id-android> --project stockpyme --out android/app/google-services.json
//   firebase apps:sdkconfig WEB <id-web> --project stockpyme --out web/firebase-config.json
//
// Luego:
//   dart run tool/generar_firebase_options.dart

import 'dart:convert';
import 'dart:io';

const String androidPackage = 'cl.riverasystems.stock_pyme';
const String androidFile = 'android/app/google-services.json';
const String webFile = 'web/firebase-config.json';
const String outFile = 'lib/firebase_options.dart';

void main() {
  final android = _readAndroid();
  final web = _readWeb();

  if (android == null && web == null) {
    stderr.writeln('No encontré $androidFile ni $webFile.');
    stderr.writeln('Ejecuta primero los comandos "firebase apps:sdkconfig".');
    exit(1);
  }

  final out = StringBuffer()
    ..writeln('// Generado por tool/generar_firebase_options.dart.')
    ..writeln('// Para regenerarlo, vuelve a ejecutar ese comando.')
    ..writeln('// ignore_for_file: type=lint')
    ..writeln()
    ..writeln("import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;")
    ..writeln("import 'package:flutter/foundation.dart'")
    ..writeln('    show defaultTargetPlatform, kIsWeb, TargetPlatform;')
    ..writeln()
    ..writeln('class DefaultFirebaseOptions {')
    ..writeln('  DefaultFirebaseOptions._();')
    ..writeln()
    ..writeln('  static FirebaseOptions get currentPlatform {')
    ..writeln(web != null
        ? '    if (kIsWeb) return web;'
        : "    if (kIsWeb) throw UnsupportedError('Falta la app web de Firebase (web/firebase-config.json).');")
    ..writeln('    switch (defaultTargetPlatform) {')
    ..writeln('      case TargetPlatform.android:')
    ..writeln(android != null
        ? '        return android;'
        : "        throw UnsupportedError('Falta android/app/google-services.json.');")
    ..writeln('      case TargetPlatform.windows:')
    ..writeln(web != null
        ? '        return windows;'
        : "        throw UnsupportedError('Para Windows falta la app web de Firebase (web/firebase-config.json).');")
    ..writeln('      default:')
    ..writeln("        throw UnsupportedError('StockPyme no está configurado para esta plataforma.');")
    ..writeln('    }')
    ..writeln('  }');

  if (android != null) out.write(_options('android', android));
  if (web != null) {
    out.write(_options('web', web));
    out.write(_options('windows', web));
  }
  out.writeln('}');

  File(outFile).writeAsStringSync(out.toString());
  stdout.writeln('Listo: $outFile');
  stdout.writeln('  Android: ${android != null ? 'sí' : 'NO (falta $androidFile)'}');
  stdout.writeln('  Web y Windows: ${web != null ? 'sí' : 'NO (falta $webFile)'}');
}

String _options(String name, Map<String, String> v) {
  final b = StringBuffer()
    ..writeln()
    ..writeln('  static const FirebaseOptions $name = FirebaseOptions(');
  for (final key in [
    'apiKey',
    'appId',
    'messagingSenderId',
    'projectId',
    'authDomain',
    'storageBucket',
    'measurementId',
  ]) {
    final value = v[key];
    if (value != null && value.isNotEmpty) {
      b.writeln("    $key: '${value.replaceAll("'", r"\'")}',");
    }
  }
  b.writeln('  );');
  return b.toString();
}

Map<String, String>? _readAndroid() {
  final file = File(androidFile);
  if (!file.existsSync()) return null;
  final json = jsonDecode(_cleanJson(file.readAsStringSync())) as Map<String, dynamic>;
  final project = json['project_info'] as Map<String, dynamic>;
  final clients = (json['client'] as List).cast<Map<String, dynamic>>();
  final client = clients.firstWhere(
    (c) =>
        (c['client_info']?['android_client_info']?['package_name']) ==
        androidPackage,
    orElse: () => clients.first,
  );
  final keys = (client['api_key'] as List).cast<Map<String, dynamic>>();
  return {
    'apiKey': keys.first['current_key'] as String,
    'appId': client['client_info']['mobilesdk_app_id'] as String,
    'messagingSenderId': project['project_number'] as String,
    'projectId': project['project_id'] as String,
    'storageBucket': (project['storage_bucket'] ?? '') as String,
  };
}

Map<String, String>? _readWeb() {
  final file = File(webFile);
  if (!file.existsSync()) return null;
  final text = file.readAsStringSync();
  final result = <String, String>{};
  // Sirve tanto si el archivo es JSON como si es el fragmento de JavaScript.
  for (final key in [
    'apiKey',
    'appId',
    'messagingSenderId',
    'projectId',
    'authDomain',
    'storageBucket',
    'measurementId',
  ]) {
    final match =
        RegExp('["\']?$key["\']?\\s*:\\s*["\']([^"\']+)["\']').firstMatch(text);
    if (match != null) result[key] = match.group(1)!;
  }
  return result.containsKey('apiKey') && result.containsKey('appId')
      ? result
      : null;
}

/// Quita texto que no sea JSON antes y después de las llaves.
String _cleanJson(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  return start >= 0 && end > start ? text.substring(start, end + 1) : text;
}
