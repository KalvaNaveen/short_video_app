import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/video_model.dart';
import '../widgets/ad_manager.dart';

class ShortsScreen extends StatefulWidget {
  final List<VideoModel> videos;
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
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  late final PageController _pageController;
  final Map<int, YoutubePlayerController> _controllers = {};
  late Set<String> favoriteIds;
  int _currentIndex = 0;
  int _videosViewed = 0;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;
    favoriteIds = Set<String>.from(widget.favoriteIds);
    _pageController = PageController(initialPage: _currentIndex);

    _initControllersAround(_currentIndex);
  }

  void _initControllersAround(int idx) {
    final indexes = [
      if (idx - 1 >= 0) idx - 1,
      idx,
      if (idx + 1 < widget.videos.length) idx + 1,
    ];

    for (final i in _controllers.keys.toList()) {
      if (!indexes.contains(i)) {
        _controllers[i]?.dispose();
        _controllers.remove(i);
      }
    }

    for (final i in indexes) {
      if (!_controllers.containsKey(i) &&
          i >= 0 &&
          i < widget.videos.length) {
        final ctrl = YoutubePlayerController(
          initialVideoId: widget.videos[i].videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            disableDragSeek: true,
            loop: false,
            isLive: false,
            enableCaption: false,
          ),
        );
        _controllers[i] = ctrl;
        if (i != idx) ctrl.pause();
      } else if (_controllers.containsKey(i)) {
        if (i == idx)
          _controllers[i]!.play();
        else
          _controllers[i]!.pause();
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int idx) async {
    if (idx < 0 || idx >= widget.videos.length) return;

    setState(() {
      _currentIndex = idx;
      _videosViewed++;
    });

    _initControllersAround(idx);

    // Show rewarded interstitial every 7 videos
    if (_videosViewed % 7 == 0) {
      final rewardedAd = AdManager.of(context);
      if (rewardedAd != null) {
        await rewardedAd.showRewardedInterstitialAd(context);
      }
    }

    // Load more near the end
    if (idx >= widget.videos.length - 5 && !widget.isLoading) {
      await widget.loadMore();
      setState(() {});
    }
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
    final url = 'https://www.youtube.com/watch?v=${video.videoId}';
    Share.share('Check out this video on ReelRush: $url');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text('No videos available',
              style: TextStyle(color: Colors.white)),
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
        onEnded: (_) async {
          if (_currentIndex < widget.videos.length - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
            _pageController.nextPage(
                duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
          }
        },
        bottomActions: const [],
      ),
      builder: (context, player) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
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
                        color: isFav ? Colors.redAccent : Colors.white, size: 36),
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
      ),
    );
  }
}
