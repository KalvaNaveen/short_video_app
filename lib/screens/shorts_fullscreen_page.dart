import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video_model.dart';

class ShortsFullScreenPage extends StatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;
  final Set<String> favoriteVideoIds;
  final Function(String videoId) onToggleFavorite;

  const ShortsFullScreenPage({
    Key? key,
    required this.videos,
    required this.initialIndex,
    required this.favoriteVideoIds,
    required this.onToggleFavorite,
  }) : super(key: key);

  @override
  State<ShortsFullScreenPage> createState() => _ShortsFullScreenPageState();
}

class _ShortsFullScreenPageState extends State<ShortsFullScreenPage> {
  late PageController _pageController;
  late int _currentIndex;

  // We keep a map of controllers to avoid recreating controllers unnecessarily
  final Map<int, YoutubePlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
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
        onPageChanged: (newIndex) {
          setState(() {
            _currentIndex = newIndex;
          });
        },
        itemBuilder: (context, index) {
          final video = widget.videos[index];

          // Reuse controller if exists, else create and store it
          final controller = _controllers.putIfAbsent(
            index,
            () => _buildController(video.videoId),
          );

          return YoutubePlayerBuilder(
            player: YoutubePlayer(controller: controller),
            builder: (context, player) => Stack(
              fit: StackFit.expand,
              children: [
                player,
                // Video title at bottom
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

                // FAVORITES HEART ICON at top-right
                Positioned(
                  top: 40,
                  right: 20,
                  child: GestureDetector(
                    onTap: () {
                      widget.onToggleFavorite(video.videoId);
                      // Force rebuild to update heart icon state
                      setState(() {});
                    },
                    child: Icon(
                      widget.favoriteVideoIds.contains(video.videoId)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: Colors.redAccent,
                      size: 36,
                      shadows: const [
                        Shadow(
                          blurRadius: 5,
                          color: Colors.black,
                          offset: Offset(0, 0),
                        ),
                      ],
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
