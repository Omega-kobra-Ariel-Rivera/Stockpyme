import 'dart:ui' show Locale, PlatformDispatcher;

import 'translations_en.dart';
import 'translations_pt.dart';

/// Idiomas de la app.
enum AppLanguage {
  es('es', 'Español'),
  en('en', 'English'),
  pt('pt', 'Português');

  const AppLanguage(this.code, this.nativeName);

  final String code;

  /// Nombre en su propio idioma (no se traduce).
  final String nativeName;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLanguage.es,
      );

  /// Idioma del teléfono o PC si es uno de los disponibles; si no, español.
  static AppLanguage fromDevice() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.es,
    );
  }
}

class I18n {
  I18n._();

  static AppLanguage current = AppLanguage.es;
}

/// Traduce un texto escrito en español al idioma elegido.
///
/// Los valores variables van entre llaves:
/// `tr('Quedan {n} días', {'n': 5})`.
String tr(String spanish, [Map<String, Object?> args = const {}]) {
  var text = spanish;
  switch (I18n.current) {
    case AppLanguage.es:
      break;
    case AppLanguage.en:
      text = translationsEn[spanish] ?? spanish;
    case AppLanguage.pt:
      text = translationsPt[spanish] ?? spanish;
  }
  if (args.isNotEmpty) {
    args.forEach((key, value) {
      text = text.replaceAll('{$key}', '${value ?? ''}');
    });
  }
  return text;
}
