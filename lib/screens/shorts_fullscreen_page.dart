import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video_model.dart';

class ShortsFullScreenPage extends StatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;

  const ShortsFullScreenPage({
    Key? key,
    required this.videos,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<ShortsFullScreenPage> createState() => _ShortsFullScreenPageState();
}

class _ShortsFullScreenPageState extends State<ShortsFullScreenPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  YoutubePlayerController _buildController(String videoId) {
    return YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          final video = widget.videos[index];
          final controller = _buildController(video.videoId);

          return YoutubePlayerBuilder(
            player: YoutubePlayer(controller: controller),
            builder: (context, player) => Stack(
              fit: StackFit.expand,
              children: [
                player,
                Positioned(
                  bottom: 40,
                  left: 16,
                  right: 16,
                  child: Text(
                    video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
