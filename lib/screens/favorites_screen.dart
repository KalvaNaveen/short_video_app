import 'package:shared_preferences/shared_preferences.dart';

class FavoritesManager {
  static const _favoritesKey = 'favorite_video_ids';

  Future<List<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? <String>[];
  }

  Future<void> addFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_favoritesKey) ?? <String>[];
    if (!favs.contains(id)) {
      favs.add(id);
      await prefs.setStringList(_favoritesKey, favs);
    }
  }

  Future<void> removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_favoritesKey) ?? <String>[];
    favs.remove(id);
    await prefs.setStringList(_favoritesKey, favs);
  }
}
