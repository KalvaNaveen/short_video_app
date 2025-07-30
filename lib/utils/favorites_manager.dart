import 'package:shared_preferences/shared_preferences.dart';

class FavoritesManager {
  static const String _favoritesKey = 'favorite_video_ids';

  Future<List<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  Future<void> addFavorite(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_favoritesKey) ?? [];
    if (!favs.contains(videoId)) {
      favs.add(videoId);
      await prefs.setStringList(_favoritesKey, favs);
    }
  }

  Future<void> removeFavorite(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_favoritesKey) ?? [];
    favs.remove(videoId);
    await prefs.setStringList(_favoritesKey, favs);
  }
}
