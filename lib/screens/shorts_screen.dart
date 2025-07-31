import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/video_model.dart';

class ShortsScreen extends StatefulWidget {
  final List<VideoModel> videos; // Must be a reference to mutable list
  final int initialIndex;
  final Set<String> favoriteIds;
  final Function(String) onToggle;
  final Future<void> Function() loadMore;
  final bool isLoading;

  const ShortsScreen({
    required this.videos,
    required this.initialIndex,
    required this.favoriteIds,
    required this.onToggle,
    required this.loadMore,
    required this.isLoading,
    Key? key,
  }) : super(key: key);

  @override
  _ShortsScreenState createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  late PageController _pageController;
  final Map<int, YoutubePlayerController> _controllers = {};
  int _currentIndex = 0;
  late Set<String> favoriteIds;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;
    favoriteIds = Set<String>.from(widget.favoriteIds);
    _pageController = PageController(initialPage: _currentIndex);

    _initControllersAround(_currentIndex);
  }

  void _initControllersAround(int index) {
    final indexes = [
      if (index - 1 >= 0) index - 1,
      index,
      if (index + 1 < widget.videos.length) index + 1,
    ];

    // Dispose controllers out of the current window
    final toDispose = _controllers.keys.where((key) => !indexes.contains(key)).toList();
    for (var key in toDispose) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }

    // Initialize missing controllers & manage play/pause
    for (var i in indexes) {
      if (!_controllers.containsKey(i)) {
        _controllers[i] = YoutubePlayerController(
          initialVideoId: widget.videos[i].videoId,
          flags: YoutubePlayerFlags(
            autoPlay: i == index,
            mute: false,
            disableDragSeek: true,
            loop: false,
            forceHD: false,
            enableCaption: false,
          ),
        );
      } else {
        if (i == index) {
          _controllers[i]!.play();
        } else {
          _controllers[i]!.pause();
        }
      }
    }
  }

  @override
  void dispose() {
    for (var ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controllers[_currentIndex];
    if (controller == null) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  void _handleFavoriteToggle(String id) {
    widget.onToggle(id);
    setState(() {
      if (favoriteIds.contains(id)) {
        favoriteIds.remove(id);
      } else {
        favoriteIds.add(id);
      }
    });
  }

  void _onShare() {
    final video = widget.videos[_currentIndex];
    final url = "https://www.youtube.com/watch?v=${video.videoId}";
    Share.share('Check out this video on ReelRush: $url');
  }

  void _onPageChanged(int index) {
    if (index >= widget.videos.length) return;
    setState(() {
      _currentIndex = index;
    });
    _initControllersAround(_currentIndex);

    // Trigger loading more videos near end
    if (_currentIndex >= widget.videos.length - 5 && !widget.isLoading) {
      widget.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            'No videos available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final video = widget.videos[_currentIndex];
    final isFav = favoriteIds.contains(video.videoId);
    final controller = _controllers[_currentIndex];

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.redAccent,
        progressColors: const ProgressBarColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.redAccent,
        ),
        onEnded: (_) {
          if (_currentIndex < widget.videos.length - 1) {
            _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          }
        },
        bottomActions: const [],
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              GestureDetector(
                onTap: _togglePlayPause,
                child: SizedBox.expand(child: player),
              ),
              Positioned(
                bottom: 80,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.redAccent : Colors.white,
                        size: 36,
                      ),
                      onPressed: () => _handleFavoriteToggle(video.videoId),
                      tooltip: 'Favorite',
                    ),
                    const SizedBox(height: 16),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white, size: 28),
                      onPressed: _onShare,
                      tooltip: 'Share',
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 40,
                left: 16,
                right: 16,
                child: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: widget.videos.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
