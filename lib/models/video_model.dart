class VideoModel {
  final String videoId;
  final String title;
  final String thumbnailUrl;

  VideoModel({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
  });

  factory VideoModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      // Return empty or default values if json is null
      return VideoModel(videoId: '', title: '', thumbnailUrl: '');
    }

    final id = json['id'];
    final snippet = json['snippet'];
    final thumbnails = snippet != null ? snippet['thumbnails'] : null;
    final mediumThumbnail = thumbnails != null ? thumbnails['medium'] : null;

    return VideoModel(
      videoId: (id != null && id['videoId'] != null) ? id['videoId'] as String : '',
      title: (snippet != null && snippet['title'] != null) ? snippet['title'] as String : '',
      thumbnailUrl: (mediumThumbnail != null && mediumThumbnail['url'] != null)
          ? mediumThumbnail['url'] as String
          : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  String getThumbnailUrl() => thumbnailUrl;
}
