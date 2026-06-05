import 'package:shared_preferences/shared_preferences.dart';

enum StorageKey {
  token(value: 'token'),
  viewMode(value: 'view_mode'),
  ;

  final String value;

  const StorageKey({required this.value});
}

class StorageService {
  static Future<String?> get(StorageKey key) async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(key.value);
  }

  static void save(StorageKey key, String value) async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setString(key.value, value);
  }

  static void remove(StorageKey key) async {
    final prefs = await SharedPreferences.getInstance();

    prefs.remove(key.value);
  }
}
