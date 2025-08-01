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

  /// Expose current nextPageToken
  String? get nextPageToken => _nextPageToken;

  /// Expose if more pages available
  bool get hasMore => _hasMore;

  /// Fetch YouTube Shorts videos for a query (category or search)
  /// Optionally with a pageToken for pagination.
  Future<List<VideoModel>> fetchShortVideos(
    String query, {
    String? pageToken,
  }) async {
    final tokenToUse = pageToken ?? _nextPageToken;

    if (pageToken == null && !_hasMore) return [];

    final url = Uri.parse(
      "https://www.googleapis.com/youtube/v3/search"
      "?part=snippet"
      "&maxResults=20"
      "&q=${Uri.encodeComponent(query)}"
      "&type=video"
      "&videoDuration=short"
      "&order=date"
      "${tokenToUse != null ? "&pageToken=$tokenToUse" : ""}"
      "&key=$YOUTUBE_API_KEY"
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        _nextPageToken = data['nextPageToken'];
        _hasMore = _nextPageToken != null;

        final List items = data['items'] ?? [];

        return items.map((item) => VideoModel.fromJson(item)).toList();
      } else if (response.statusCode == 403) {
        final Map<String, dynamic> data = json.decode(response.body);
        final errorReason = (data['error']['errors'] as List).first['reason'];
        if (errorReason == 'quotaExceeded') {
          throw QuotaExceededException('Quota exceeded - please try again later.');
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

  /// Reset pagination for next fresh query
  void resetPagination() {
    _nextPageToken = null;
    _hasMore = true;
  }
}
