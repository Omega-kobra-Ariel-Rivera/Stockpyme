import 'package:flutter/foundation.dart';

import '../l10n/i18n.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

/// Idioma elegido en este teléfono o PC (es igual para todas las cuentas).
class LanguageService extends ChangeNotifier {
  LanguageService(this._storage) {
    final saved = _storage.getString(StorageKeys.language);
    _language = (saved == null || saved.isEmpty)
        ? AppLanguage.fromDevice()
        : AppLanguage.fromCode(saved);
    I18n.current = _language;
  }

  final StorageService _storage;
  late AppLanguage _language;

  AppLanguage get language => _language;

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    I18n.current = language;
    await _storage.setString(StorageKeys.language, language.code);
    notifyListeners();
  }
}
