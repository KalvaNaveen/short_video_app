import 'package:shared_preferences/shared_preferences.dart';

class UserDataPersistence {
  static Future<Set<String>> loadLikes(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('${userId}_likedVideos')?.toSet() ?? {};
  }

  static Future<Set<String>> loadSubs(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('${userId}_subscribedChannels')?.toSet() ?? {};
  }

  static Future<void> saveLikes(String userId, Set<String> videoIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('${userId}_likedVideos', videoIds.toList());
  }

  static Future<void> saveSubs(String userId, Set<String> channelNames) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('${userId}_subscribedChannels', channelNames.toList());
  }
}
