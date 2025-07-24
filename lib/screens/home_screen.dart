import 'dart:async';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video_model.dart';
import '../services/youtube_service.dart';
import 'shorts_fullscreen_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final YouTubeService _service = YouTubeService();

  List<VideoModel> _videos = [];
  bool _isLoadingMore = false;
  int _currentlyPlaying = -1;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _service.resetPagination();
    _loadMoreVideos();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (!_isLoadingMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      _loadMoreVideos();
    }
    _cancelAutoPlay();
    _startAutoPlayAfterDelay();
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final newVideos = await _service.fetchShortVideos('youtube shorts');

    // Filter to avoid duplicates
    final currentIds = _videos.map((v) => v.videoId).toSet();
    final uniqueNew = newVideos.where((v) => !currentIds.contains(v.videoId));

    setState(() {
      _videos.addAll(uniqueNew);
      _isLoadingMore = false;
    });

    if (_currentlyPlaying == -1 && _videos.isNotEmpty) {
      _startAutoPlayAfterDelay();
    }
  }

  void _startAutoPlayAfterDelay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(const Duration(seconds: 2), _playFirstVisibleVideo);
  }

  void _cancelAutoPlay() {
    _autoPlayTimer?.cancel();
  }

  void _playFirstVisibleVideo() {
    for (int i = 0; i < _videos.length; i++) {
      if (_videos[i].isVisible) {
        setState(() => _currentlyPlaying = i);
        break;
      }
    }
  }

  void _playNext(int currentIndex) {
    for (int i = currentIndex + 1; i < _videos.length; i++) {
      if (_videos[i].isVisible) {
        setState(() => _currentlyPlaying = i);
        break;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty && _isLoadingMore) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ReelRush')),
      body: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: _videos.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 9 / 16,
        ),
        itemBuilder: (context, index) {
          final video = _videos[index];
          return GestureDetector(
            onTap: () {
              _cancelAutoPlay();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShortsFullScreenPage(
                    videos: _videos,
                    initialIndex: index,
                  ),
                ),
              ).then((_) => _startAutoPlayAfterDelay());
            },
            child: VisibilityDetector(
              key: Key('video_$index'),
              onVisibilityChanged: (info) {
                final visible = info.visibleFraction > 0.6;
                setState(() => _videos[index].isVisible = visible);

                if (!visible && _currentlyPlaying == index) {
                  _cancelAutoPlay();
                }
              },
              child: YoutubePlayerBuilder(
                key: ValueKey('yt_$index'),
                player: YoutubePlayer(
                  controller: YoutubePlayerController(
                    initialVideoId: video.videoId,
                    flags: YoutubePlayerFlags(
                      autoPlay: _currentlyPlaying == index,
                      mute: true,
                      hideControls: true,
                    ),
                  ),
                  showVideoProgressIndicator: true,
                  onEnded: (_) => _playNext(index),
                ),
                builder: (context, player) => Stack(
                  fit: StackFit.expand,
                  children: [
                    player,
                    Positioned(
                      bottom: 10,
                      left: 8,
                      right: 8,
                      child: Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
