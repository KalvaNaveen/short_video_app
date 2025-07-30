import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video_model.dart';

class ShortsFullscreen extends StatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;
  final Set<String> favoriteIds;
  final Function(String) onToggleFavorite;

  const ShortsFullscreen({
    required this.videos,
    required this.initialIndex,
    required this.favoriteIds,
    required this.onToggleFavorite,
    Key? key,
  }) : super(key: key);

  @override
  State<ShortsFullscreen> createState() => _ShortsFullscreenState();
}

class _ShortsFullscreenState extends State<ShortsFullscreen> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, YoutubePlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  YoutubePlayerController _getController(int index) {
    return _controllers.putIfAbsent(
      index,
      () => YoutubePlayerController(
          initialVideoId: widget.videos[index].videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
            hideControls: true,
          )),
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Play current video, pause all others
    _controllers.forEach((key, controller) {
      if (key == index) {
        controller.play();
      } else {
        controller.pause();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentVideo = widget.videos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        itemCount: widget.videos.length,
        scrollDirection: Axis.vertical,
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final video = widget.videos[index];
          final controller = _getController(index);

          return YoutubePlayerBuilder(
            player: YoutubePlayer(
              key: ValueKey(video.videoId),
              controller: controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.redAccent,
              onEnded: (_) {
                if (index + 1 < widget.videos.length) {
                  _pageController.animateToPage(index + 1,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeIn);
                }
              },
            ),
            builder: (context, player) => Stack(
              fit: StackFit.expand,
              children: [
                player,
                Positioned(
                  bottom: 60,
                  left: 16,
                  right: 86,
                  child: Text(
                    video.title,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                ),
                // No action buttons as per instruction
              ],
            ),
          );
        },
      ),
    );
  }
}
