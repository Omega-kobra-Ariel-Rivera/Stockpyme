import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Persistencia local (Android: SharedPreferences, Web: localStorage).
///
/// Cada cuenta guarda sus datos con su propio prefijo, así dos personas
/// pueden usar el mismo teléfono sin mezclar inventarios.
class StorageService {
  StorageService._(this._prefs, [this._prefix = '']);

  final SharedPreferences _prefs;
  final String _prefix;

  static Future<StorageService> create() async =>
      StorageService._(await SharedPreferences.getInstance());

  /// Almacenamiento de una cuenta concreta.
  StorageService forAccount(String uid) =>
      StorageService._(_prefs, 'u_${uid}_');

  String _k(String key) => '$_prefix$key';

  /// Pasa a esta cuenta los datos que había antes de existir el inicio de
  /// sesión (versión 1.2 y anteriores). Solo se hace una vez.
  Future<bool> migrateLegacyData() async {
    if (_prefix.isEmpty) return false;
    var moved = false;
    for (final key in StorageKeys.accountKeys) {
      final legacy = _prefs.get(key);
      if (legacy == null || _prefs.containsKey(_k(key))) continue;
      if (legacy is String) {
        await _prefs.setString(_k(key), legacy);
      } else if (legacy is bool) {
        await _prefs.setBool(_k(key), legacy);
      } else {
        continue;
      }
      await _prefs.remove(key);
      moved = true;
    }
    return moved;
  }

  List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(_k(key));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> list) async {
    await _prefs.setString(_k(key), jsonEncode(list));
  }

  String? getString(String key) => _prefs.getString(_k(key));

  Future<void> setString(String key, String value) async {
    await _prefs.setString(_k(key), value);
  }

  bool? getBool(String key) => _prefs.getBool(_k(key));

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(_k(key), value);
  }

  /// Borra productos, ventas y movimientos (no la suscripción).
  Future<void> clearBusinessData() async {
    for (final key in StorageKeys.dataKeys) {
      await _prefs.remove(_k(key));
    }
  }
}
