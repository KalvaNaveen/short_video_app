import 'package:shared_preferences/shared_preferences.dart';

class FavoritesManager {
static const _favoritesKey = 'favorite_video_ids';

  Future<List<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  Future<void> saveFavorites(List<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favorites);
  }
  
  Future<void> addFavorite(String videoId) async {
    final favs = await loadFavorites();
    if (!favs.contains(videoId)) {
      favs.add(videoId);
      await saveFavorites(favs);
    }
  }

  Future<void> removeFavorite(String videoId) async {
    final favs = await loadFavorites();
    favs.remove(videoId);
    await saveFavorites(favs);
  }

  Future<bool> isFavorite(String videoId) async {
    final favs = await loadFavorites();
    return favs.contains(videoId);
  }
}
