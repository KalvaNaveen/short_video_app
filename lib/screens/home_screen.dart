import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/video_model.dart';
import '../services/youtube_service.dart';
import '../utils/favorites_manager.dart';
import 'shorts_screen.dart';

class QuotaExceededException implements Exception {
  final String message;
  QuotaExceededException(this.message);
}

class Category {
  final String name;
  final IconData icon;

  const Category(this.name, this.icon);
}

class FavoritesScreen extends StatefulWidget {
  final List<VideoModel> allVideos;
  const FavoritesScreen({required this.allVideos, Key? key}) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesManager _favoritesManager = FavoritesManager();
  Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await _favoritesManager.loadFavorites();
    setState(() {
      _favoriteIds = favs.toSet();
    });
  }

  Future<void> _removeFavorite(String id) async {
    await _favoritesManager.removeFavorite(id);
    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final favVideos = widget.allVideos.where((v) => _favoriteIds.contains(v.videoId)).toList();

    if (favVideos.isEmpty) {
      return const Center(
          child: Text('No favorites yet', style: TextStyle(color: Colors.white)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 9 / 16),
      itemCount: favVideos.length,
      itemBuilder: (context, index) {
        final video = favVideos[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShortsScreen(
                    videos: favVideos,
                    initialIndex: index,
                    favoriteIds: _favoriteIds,
                    onToggleFavorite: (id) async {
                      if (_favoriteIds.contains(id)) {
                        await _favoritesManager.removeFavorite(id);
                      } else {
                        await _favoritesManager.addFavorite(id);
                      }
                      await _loadFavorites();
                      setState(() {});
                    },
                    loadMoreCallback: () async {},
                    isLoading: false),
              ),
            );
          },
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  video.getThumbnailUrl(),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.error),
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
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, backgroundColor: Colors.black54, fontSize: 12),
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
  final List<VideoModel>? initialVideos;
  const HomeScreen({this.initialVideos, Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final YouTubeService _service = YouTubeService();
  final FavoritesManager _favoritesManager = FavoritesManager();

  List<VideoModel> _videos = [];
  List<VideoModel> _searchResults = [];

  bool _isSearching = false;
  bool _isLoading = false;
  bool _quotaExceeded = false;

  List<String> _favoriteIds = [];

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  int _selectedNavIndex = 0;
  late String _selectedCategory;

  Timer? _debounceTimer;

  final List<Category> _categories = const [
    Category("Trending", Icons.trending_up),
    Category("Music", Icons.library_music),
    Category("Comedy", Icons.sentiment_satisfied),
    Category("Sports", Icons.sports_soccer),
    Category("Gaming", Icons.videogame_asset),
  ];

  final Map<String, List<VideoModel>> _cachedVideos = {};

  @override
  void initState() {
    super.initState();

    _videos = widget.initialVideos ?? [];
    _selectedCategory = _categories[0].name;

    _tabController = TabController(length: _categories.length, vsync: this);

    if (_videos.isEmpty) {
      _quotaExceeded = false;
      _service.resetPagination();
      _loadCachedOrFetch(_selectedCategory);
    }

    _loadFavorites();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;

      if (_isSearching) {
        setState(() {
          _isSearching = false;
          _searchResults.clear();
          _searchController.clear();
          _quotaExceeded = false;
        });
      }

      final newCategory = _categories[_tabController.index].name;
      if (newCategory != _selectedCategory) {
        setState(() {
          _selectedCategory = newCategory;
          _videos.clear();
          _quotaExceeded = false;
        });
        _service.resetPagination();
        _loadCachedOrFetch(newCategory);
      }
    });

    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    const thresholdPixels = 700;
    if (!_isLoading &&
        !_quotaExceeded &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - thresholdPixels) {
      if (!_isSearching) {
        if (_service.hasMore) {
          _loadMoreVideos(_selectedCategory);
        }
      }
    }
  }

  Future<void> _loadCachedOrFetch(String query) async {
    if (_cachedVideos.containsKey(query)) {
      setState(() {
        _videos = List.from(_cachedVideos[query]!);
      });
    } else {
      await _loadMoreVideos(query);
    }
  }

  Future<void> _loadMoreVideos(String query) async {
    if (_isLoading || !_service.hasMore || _quotaExceeded) return;

    setState(() {
      _isLoading = true;
      _quotaExceeded = false;
    });

    try {
      final newVideos = await _service.fetchShortVideos(query);

      final existingIds = _videos.map((v) => v.videoId).toSet();
      final uniqueVideos = newVideos.where((v) => !existingIds.contains(v.videoId)).toList();

      final updatedVideos = [..._videos, ...uniqueVideos];
      _cachedVideos[query] = updatedVideos;

      if (!_isSearching || query == _selectedCategory) {
        setState(() {
          _videos = updatedVideos;
        });
      }
    } on QuotaExceededException catch (_) {
      setState(() {
        _quotaExceeded = true;
      });
    } catch (e) {
      // Handle other errors gracefully here or log
      // print('Error loading videos: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFavorites() async {
    final favs = await _favoritesManager.loadFavorites();
    setState(() => _favoriteIds = favs);
  }

  bool _isFavorite(String id) => _favoriteIds.contains(id);

  void _toggleFavorite(String id) async {
    if (_isFavorite(id)) {
      await _favoritesManager.removeFavorite(id);
    } else {
      await _favoritesManager.addFavorite(id);
    }
    await _loadFavorites();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty) {
        setState(() {
          _isSearching = false;
          _searchResults.clear();
          _quotaExceeded = false;
        });
      } else {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    _service.resetPagination();

    setState(() {
      _isSearching = true;
      _searchResults.clear();
      _isLoading = true;
      _quotaExceeded = false;
    });

    try {
      final results = await _service.fetchShortVideos(query);

      setState(() {
        _searchResults = results;
      });
    } on QuotaExceededException catch (_) {
      setState(() {
        _quotaExceeded = true;
      });
    } catch (_) {
      // Handle other errors as needed
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onVideoTap(int index) {
    final listToPlay = _isSearching ? _searchResults : _videos;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShortsScreen(
          videos: listToPlay,
          initialIndex: index,
          favoriteIds: _favoriteIds.toSet(),
          onToggleFavorite: _toggleFavorite,
          loadMoreCallback: () =>
              _isSearching ? Future.value() : _loadMoreVideos(_selectedCategory),
          isLoading: _isLoading,
        ),
      ),
    ).then((_) {
      if (!_isSearching) {
        _loadMoreVideos(_selectedCategory);
      }
    });
  }

  void _onNavTap(int idx) {
    setState(() {
      _selectedNavIndex = idx;
      _searchController.clear();
      _searchResults.clear();
      _isSearching = false;
      _quotaExceeded = false;
    });
  }

  Widget _buildSearchAndCategoriesRow() {
    return Material(
      color: Colors.black,
      elevation: 4,
      shadowColor: Colors.redAccent.withOpacity(0.3),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          offset: const Offset(0, 1),
                          blurRadius: 5,
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search Shorts',
                        hintStyle: const TextStyle(color: Colors.white70),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _onSearchChanged();
                                  FocusScope.of(context).unfocus();
                                },
                                child: const Icon(Icons.close, color: Colors.white70),
                              )
                            : const Icon(Icons.search, color: Colors.white70),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (val) {
                        _performSearch(val);
                        FocusScope.of(context).unfocus();
                      },
                      onChanged: (_) => _onSearchChanged(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat.name;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.redAccent : Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.redAccent.withOpacity(0.6),
                                      offset: const Offset(0, 3),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              if (!isSelected) {
                                setState(() {
                                  _selectedCategory = cat.name;
                                  _isSearching = false;
                                  _searchResults.clear();
                                  _searchController.clear();
                                  _quotaExceeded = false;
                                });
                                _service.resetPagination();
                                _loadCachedOrFetch(cat.name);
                                FocusScope.of(context).unfocus();
                              }
                            },
                            child: Row(
                              children: [
                                Icon(
                                  cat.icon,
                                  size: 20,
                                  color: isSelected ? Colors.white : Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontWeight:
                                        isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
         
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    if (_quotaExceeded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            "Feed temporarily unavailable due to API quota limits.\nPlease try again later.",
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final currentList = _isSearching ? _searchResults : _videos;

    if (currentList.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (currentList.isEmpty) {
      return const Center(child: Text("No videos found.", style: TextStyle(color: Colors.white)));
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 9 / 16),
      itemCount: currentList.length,
      itemBuilder: (context, index) {
        final vid = currentList[index];
        return GestureDetector(
          onTap: () => _onVideoTap(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              vid.getThumbnailUrl(),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.white54),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      Column(
        children: [
          _buildSearchAndCategoriesRow(),
          Expanded(child: _buildVideoGrid()),
        ],
      ),
      FavoritesScreen(allVideos: _videos),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("ReelRush"),
        backgroundColor: Colors.black,
      ),
      body: screens[_selectedNavIndex],
      // bottomNavigationBar: BottomNavigationBar(
      //   currentIndex: _selectedNavIndex,
      //   backgroundColor: Colors.black,
      //   selectedItemColor: Colors.redAccent,
      //   unselectedItemColor: Colors.white70,
      //   onTap: _onNavTap,
      //   items: const [
      //     BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
      //     BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favorites"),
      //   ],
      // ),
    );
  }
}
