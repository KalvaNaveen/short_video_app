import 'dart:async';
import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../services/youtube_service.dart';
import 'shorts_fullscreen_page.dart';
import '../utils/favorites_manager.dart';
import '../widgets/short_video_tile.dart';

// New: Favorites Screen implementation (added below)
class FavoritesScreen extends StatefulWidget {
  final List<VideoModel> allVideos;

  const FavoritesScreen({required this.allVideos, Key? key}) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesManager _favoritesManager = FavoritesManager();
  Set<String> _favoriteVideoIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await _favoritesManager.loadFavorites();
    setState(() {
      _favoriteVideoIds = favs.toSet();
    });
  }

  void _removeFavorite(String videoId) async {
    await _favoritesManager.removeFavorite(videoId);
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final favoriteVideos = widget.allVideos
        .where((v) => _favoriteVideoIds.contains(v.videoId))
        .toList();

    if (favoriteVideos.isEmpty) {
      return const Center(child: Text('No favorite videos yet'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: favoriteVideos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemBuilder: (_, index) {
        final video = favoriteVideos[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShortsFullScreenPage(
                  videos: favoriteVideos,
                  initialIndex: index,
                  favoriteVideoIds: _favoriteVideoIds,
                  onToggleFavorite: (videoId) async {
                    if (_favoriteVideoIds.contains(videoId)) {
                      await _favoritesManager.removeFavorite(videoId);
                    } else {
                      await _favoritesManager.addFavorite(videoId);
                    }
                    await _loadFavorites();
                  },
                ),
              ),
            );
          },
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  video.getThumbnailUrl(highQuality: true),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.error)),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _removeFavorite(video.videoId),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.redAccent,
                    size: 28,
                    shadows: [
                      Shadow(blurRadius: 5, color: Colors.black, offset: Offset(0, 0))
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 8,
                right: 8,
                child: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white, backgroundColor: Colors.black54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final YouTubeService _service = YouTubeService();
  final FavoritesManager _favoritesManager = FavoritesManager();

  List<String> _favoriteVideoIds = [];
  List<VideoModel> _videos = [];
  bool _isLoadingMore = false;
  int _currentlyPlaying = -1;
  Timer? _autoPlayTimer;

  // NEW: bottom navigation state
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _service.resetPagination();
    _loadMoreVideos();
    _loadFavorites();
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

  Future<void> _loadFavorites() async {
    final favs = await _favoritesManager.loadFavorites();
    setState(() {
      _favoriteVideoIds = favs;
    });
  }

  bool _isFavorite(String videoId) {
    return _favoriteVideoIds.contains(videoId);
  }

  void _toggleFavorite(String videoId) async {
    if (_isFavorite(videoId)) {
      await _favoritesManager.removeFavorite(videoId);
    } else {
      await _favoritesManager.addFavorite(videoId);
    }
    _loadFavorites(); // Refresh UI
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

  // NEW: BottomNavigationBar tap handler
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Existing video feed with favorites overlay
  Widget _buildHomeFeed() {
    if (_videos.isEmpty && _isLoadingMore) {
      return const Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
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

  return ShortVideoTile(
    video: video,
    isPlaying: _currentlyPlaying == index,
    isFavorite: _isFavorite(video.videoId),
    onTap: () {
      _cancelAutoPlay();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShortsFullScreenPage(
            videos: _videos,
            initialIndex: index,
             favoriteVideoIds: _favoriteVideoIds.toSet(),
              onToggleFavorite: _toggleFavorite,
          ),
        ),
      ).then((_) => _startAutoPlayAfterDelay());
    },
    onToggleFavorite: () => _toggleFavorite(video.videoId),
    onEnded: () => _playNext(index),
    onVisibilityChanged: (visible) {
      if (visible != video.isVisible) {
        setState(() => video.isVisible = visible);
        if (!visible && _currentlyPlaying == index) {
          _cancelAutoPlay();
        }
      }
    },
  );
}
 );
  }

  @override
  Widget build(BuildContext context) {
    // Two tabs: Home feed and Favorites
    final List<Widget> _screens = [
      _buildHomeFeed(),
      FavoritesScreen(allVideos: _videos),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('ReelRush')),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}
