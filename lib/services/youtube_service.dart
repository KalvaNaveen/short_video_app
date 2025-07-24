import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_model.dart';
import '../config/api_keys.dart';

class YouTubeService {
  String? _nextPageToken;
  bool _hasMore = true;

  Future<List<VideoModel>> fetchShortVideos(String query) async {
    if (!_hasMore) return [];
    final url = Uri.parse(
      "https://www.googleapis.com/youtube/v3/search"
      "?part=snippet"
      "&maxResults=10"
      "&q=$query"
      "&type=video"
      "&videoDuration=short"
      "&order=date"
      "${_nextPageToken != null ? "&pageToken=$_nextPageToken" : ""}"
      "&key=$YOUTUBE_API_KEY"
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _nextPageToken = data['nextPageToken'];
      _hasMore = _nextPageToken != null;

      final items = data['items'] as List;
      return items.map((item) => VideoModel.fromJson(item)).toList();
    } else {
      print('Error fetching videos: ${response.body}');
      return [];
    }
  }

  void resetPagination() {
    _nextPageToken = null;
    _hasMore = true;
  }
}
