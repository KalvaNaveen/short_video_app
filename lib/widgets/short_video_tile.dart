import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video_model.dart';

class ShortVideoTile extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;

  const ShortVideoTile({required this.video, required this.onTap, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = YoutubePlayerController(
      initialVideoId: video.videoId,
      flags: const YoutubePlayerFlags(
        mute: true,
        autoPlay: false,
        hideControls: true,
        disableDragSeek: true,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: YoutubePlayer(
          controller: controller,
          showVideoProgressIndicator: false,
        ),
      ),
    );
  }
}
