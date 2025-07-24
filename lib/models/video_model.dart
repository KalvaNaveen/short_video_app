class VideoModel {
  final String videoId;
  final String title;
  final Map<String, String> thumbnails;
  bool isVisible = false;   // to track visibility for autoplay

  VideoModel({
    required this.videoId,
    required this.title,
    required this.thumbnails,
  });

  factory VideoModel.fromJson(Map<String, dynamic> item) {
    final snippet = item['snippet'];
    final id = item['id'];
    if (id == null || id['videoId'] == null || snippet == null) {
      throw Exception('Invalid video data');
    }
    final thumbs = snippet['thumbnails'] ?? {};

    return VideoModel(
      videoId: id['videoId'],
      title: snippet['title'] ?? 'Untitled',
      thumbnails: {
        if (thumbs['default'] != null) 'default': thumbs['default']['url'],
        if (thumbs['medium'] != null) 'medium': thumbs['medium']['url'],
        if (thumbs['high'] != null) 'high': thumbs['high']['url'],
        if (thumbs['standard'] != null) 'standard': thumbs['standard']['url'],
        if (thumbs['maxres'] != null) 'maxres': thumbs['maxres']['url'],
      },
    );
  }

  String getThumbnailUrl({bool highQuality = false}) {
    if (highQuality) {
      return thumbnails['maxres'] ??
             thumbnails['standard'] ??
             thumbnails['high'] ??
             thumbnails['medium'] ??
             thumbnails['default'] ??
             '';
    } else {
      return thumbnails['medium'] ?? thumbnails['default'] ?? '';
    }
  }
}
