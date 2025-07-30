import 'dart:async';
import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../services/youtube_service.dart';
import '../utils/favorites_manager.dart';
import 'shorts_fullscreen.dart';

class HomeScreen extends StatefulWidget {
  final List<VideoModel>? videos;  // Optional initial videos

  const HomeScreen({this.videos, Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final YouTubeService _service = YouTubeService();
  final FavoritesManager _favoritesManager = FavoritesManager();

  late List<VideoModel> _videos;
  bool _isLoadingMore = false;
  int _currentlyPlaying = -1;
  Timer? _autoPlayTimer;
  List<String> _favoriteVideoIds = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _videos = widget.videos ?? [];
    if (_videos.isEmpty) {
      _loadMoreVideos();
    }
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
    _startAutoPlayImmediately();
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    final newVideos = await _service.fetchShortVideos('youtube shorts');

    final currentIds = _videos.map((v) => v.videoId).toSet();
    final uniqueNew = newVideos.where((v) => !currentIds.contains(v.videoId)).toList();

    setState(() {
      _videos.addAll(uniqueNew);
      _isLoadingMore = false;
    });

    if (_currentlyPlaying == -1 && _videos.isNotEmpty) {
      _startAutoPlayImmediately();
    }
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
    _loadFavorites();
  }

  void _startAutoPlayImmediately() {
    _autoPlayTimer?.cancel();
    _playFirstVisible();
  }

  void _cancelAutoPlay() {
    _autoPlayTimer?.cancel();
  }

  void _playFirstVisible() {
    for (int i = 0; i < _videos.length; i++) {
      if (_videos[i].isVisible) {
        setState(() {
          _currentlyPlaying = i;
        });
        break;
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildGrid() {
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
        return GestureDetector(
          onTap: () {
            _cancelAutoPlay();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShortsFullscreen(
                  videos: _videos,
                  initialIndex: index,
                  favoriteIds: _favoriteVideoIds.toSet(),
                  onToggleFavorite: _toggleFavorite,
                ),
              ),
            ).then((_) => _startAutoPlayImmediately());
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              video.getThumbnailUrl(),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const Icon(Icons.error),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildGrid(),
      // You can add FavoritesScreen here if you have that implemented
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('RushReels'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
           BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}
