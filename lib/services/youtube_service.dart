import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_model.dart';
import '../config/api_keys.dart';

class QuotaExceededException implements Exception {
  final String message;
  QuotaExceededException(this.message);
}

class YouTubeService {
  String? _nextPageToken;
  bool _hasMore = true;

  Future<List<VideoModel>> fetchShortVideos(String query) async {
    if (!_hasMore) return [];
    final url = Uri.parse(
      "https://www.googleapis.com/youtube/v3/search"
      "?part=snippet"
      "&maxResults=20"
      "&q=${Uri.encodeComponent(query)}"
      "&type=video"
      "&videoDuration=short"
      "&order=date"
      "${_nextPageToken != null ? "&pageToken=$_nextPageToken" : ""}"
      "&key=$YOUTUBE_API_KEY"
    );

   try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Save the next page token for pagination
        _nextPageToken = data['nextPageToken'];
        _hasMore = _nextPageToken != null;

        final List<dynamic> items = data['items'] ?? [];

        // Map API results to your VideoModel instances
        return items.map((item) => VideoModel.fromJson(item)).toList();
      } else if (response.statusCode == 403) {
      final data = json.decode(response.body);
      final errorReason = (data['error']['errors'] as List<dynamic>).first['reason'];
      if (errorReason == 'quotaExceeded') {
        throw QuotaExceededException('Quota exceeded: please wait and try later.');
      }
      throw Exception('API Error: ${response.body}');
    } else {
      throw Exception('API Error: ${response.body}');
    }
    } catch (e) {
      print('Exception fetching videos: $e');
      return [];
    }
  }

  void resetPagination() {
    _nextPageToken = null;
    _hasMore = true;
  }
   /// Returns whether there are more pages available to fetch.
  bool get hasMore => _hasMore;

  /// Returns the current pagination token.
  String? get nextPageToken => _nextPageToken;

}
