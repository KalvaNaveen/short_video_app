import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:share_plus/share_plus.dart';  // Optional: if you want sharing
import '../models/video_model.dart';

class ShortsScreen extends StatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;
  final Set<String> favoriteIds;
  final Function(String) onToggleFavorite;
  final Future<void> Function() loadMoreCallback;
  final bool isLoading;

  const ShortsScreen({
    Key? key,
    required this.videos,
    required this.initialIndex,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.loadMoreCallback,
    required this.isLoading,
  }) : super(key: key);

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
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

  YoutubePlayerController _controllerForIndex(int index) {
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

    // Play current, pause all others
    for (final entry in _controllers.entries) {
      if (entry.key == index) {
        entry.value.play();
      } else {
        entry.value.pause();
      }
    }

    // Preload when close to end (+5 to avoid stall)
    if (widget.videos.length - index <= 5 && !widget.isLoading) {
      widget.loadMoreCallback();
    }
  }

  void _onShare() {
    final video = widget.videos[_currentIndex];
    Share.share('https://www.youtube.com/watch?v=${video.videoId}', subject: video.title);
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.videos[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final vid = widget.videos[index];
          final controller = _controllerForIndex(index);
          return YoutubePlayerBuilder(
            player: YoutubePlayer(
              key: ValueKey(vid.videoId),
              controller: controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.redAccent,
              onEnded: (_) {
                // Auto-forward to next video if any
                if (index + 1 < widget.videos.length) {
                  _pageController.animateToPage(index + 1,
                      duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
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
                  right: 70,
                  child: Text(
                    vid.title,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 60,
                  right: 20,
                  child: GestureDetector(
                    onTap: _onShare,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.share, color: Colors.white, size: 32),
                        SizedBox(height: 6),
                        Text('Share', style: TextStyle(color: Colors.white)),
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
