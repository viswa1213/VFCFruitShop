import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStorage {
  static const _kFavoritesKey = 'favorites_v1';

  /// Saves the favorites list (by product name or id).
  static Future<void> save(List<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavoritesKey, favorites);
  }

  /// Loads the favorites. Returns an empty set if none stored.
  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kFavoritesKey) ?? const <String>[];
    return list.toSet();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFavoritesKey);
  }
}
