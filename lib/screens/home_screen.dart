import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:reelrush/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video_model.dart';
import '../services/youtube_service.dart';
import '../utils/favorites_manager.dart';
import '../widgets/ad_manager.dart';
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

// Favorites Screen
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
    if (!mounted) return;
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
    final List<VideoModel> favVideos =
        widget.allVideos.where((v) => _favoriteIds.contains(v.videoId)).toList();

    if (favVideos.isEmpty) {
      return const Center(
        child: Text(
          'No favorites yet',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 9 / 16),
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
                  onToggle: (id) async {
                    if (_favoriteIds.contains(id)) {
                      await _favoritesManager.removeFavorite(id);
                      _favoriteIds.remove(id);
                    } else {
                      await _favoritesManager.addFavorite(id);
                      _favoriteIds.add(id);
                    }
                    if (!mounted) return;
                    setState(() {});
                  },
                  loadMore: () async {},
                  isLoading: false,
                ),
              ),
            );
          },
          child: Stack(
            children: [
              _VideoPreview(video: video),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _removeFavorite(video.videoId),
                  child: const Icon(Icons.favorite, color: Colors.redAccent, size: 28),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    borderRadius:
                        BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                  ),
                  child: Text(
                    video.title,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

// Video preview widget for grid thumbnail autoplay with visibility detection
class _VideoPreview extends StatefulWidget {
  final VideoModel video;

  const _VideoPreview({required this.video, Key? key}) : super(key: key);

  @override
  __VideoPreviewState createState() => __VideoPreviewState();
}

class __VideoPreviewState extends State<_VideoPreview> with AutomaticKeepAliveClientMixin {
  late YoutubePlayerController _controller;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.videoId,
      flags: const YoutubePlayerFlags(
        mute: true,
        autoPlay: false,
        loop: true,
        disableDragSeek: true,
        hideControls: true,
        forceHD: false,
        showLiveFullscreenButton: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final visible = info.visibleFraction > 0.5;
    if (visible && !_isVisible) {
      _isVisible = true;
      _controller.play();
    } else if (!visible && _isVisible) {
      _isVisible = false;
      _controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return VisibilityDetector(
      key: Key(widget.video.videoId),
      onVisibilityChanged: _handleVisibilityChanged,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container( color: Colors.black,child:  YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: false,
          progressIndicatorColor: Colors.redAccent,
          aspectRatio: 9 / 16
        ),
      ),
      )
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// HomeScreen main widget
class HomeScreen extends StatefulWidget {
  final List<VideoModel>? initialVideos;

  const HomeScreen({this.initialVideos, Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final YouTubeService _service = YouTubeService();
  final FavoritesManager _favoritesManager = FavoritesManager();

  List<VideoModel> _videos = [];
  List<VideoModel> _searchResults = [];

  bool _isSearching = false;
  bool _loading = false;
  bool _quotaExceeded = false;

  Set<String> _favoriteIds = {};

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

  /// Cache by category/query and page token
  final Map<String, Map<String?, List<VideoModel>>> _cachedVideos = {};

  String? _categoryNextToken;
  bool _categoryHasMore = true;

  String? _searchNextToken;
  bool _searchHasMore = true;
  bool _searchLoading = false;

  int _searchQueryId = 0;

  final Set<String> _pendingCategoryPages = {};
  final Set<String> _pendingSearchPages = {};
  final int nativeAdInterval = 6;

  @override
  void initState() {
    super.initState();

    _selectedCategory = _categories[0].name;
    _tabController = TabController(length: _categories.length, vsync: this);

    _initialLoad();

    _loadFavorites();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_isSearching) _clearSearch();

      final newCategory = _categories[_tabController.index].name;
      if (newCategory != _selectedCategory) _changeCategory(newCategory);
    });

    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initialLoad() async {
    // Load cache first
    final cached = await _loadCategoryCache(_selectedCategory);
    if (cached.isNotEmpty) {
      _cachedVideos[_selectedCategory] = {null: cached};
      if (!mounted) return;
      setState(() => _videos = cached);
    }
    // Load fresh data in any case
    await _changeCategory(_selectedCategory);
    //Log screen view
    analytics.logScreenView(screenName: 'HomeScreen');
  }

  void _clearSearch() {
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _searchResults.clear();
      _quotaExceeded = false;
    });
  }

  Future<void> _changeCategory(String category) async {
    if (!mounted) return;
    setState(() {
      _selectedCategory = category;
      _videos.clear();
      _quotaExceeded = false;
    });

    _categoryNextToken = null;
    _categoryHasMore = true;
    _pendingCategoryPages.clear();

    await _loadCategoryPage();
  }

  Future<void> _loadCategoryPage() async {
    if (!_categoryHasMore || _loading || _quotaExceeded) return;
    final pageToken = _categoryNextToken;
    final key = "${_selectedCategory}::$pageToken";
    if (_pendingCategoryPages.contains(key)) return;
    _pendingCategoryPages.add(key);
if (!mounted) return;
    setState(() => _loading = true);
    try {
      final newVideos = await _service.fetchShortVideos(_selectedCategory, pageToken: pageToken);
      _categoryNextToken = _service.nextPageToken;
      _categoryHasMore = _categoryNextToken != null;
      _cachedVideos.putIfAbsent(_selectedCategory, () => {})[pageToken] = newVideos;
      final pages = _cachedVideos[_selectedCategory]!;
      final keys = pages.keys.toList()..sort((a, b) {
        if (a == null) return -1;
        if (b == null) return 1;
        return a.compareTo(b);
      });

      final allVideos = <VideoModel>[];
      for (var k in keys) allVideos.addAll(pages[k]!);
if (!mounted) return; 
      setState(() => _videos = allVideos);

      if (_selectedCategory == "Trending" && pageToken == null) {
        await _saveCategoryCache(_selectedCategory, newVideos);
      }
    } on QuotaExceededException {
      if (!mounted) return;
      setState(() => _quotaExceeded = true);
    } finally {
      _pendingCategoryPages.remove(key);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadFavorites() async {
    final favs = await _favoritesManager.loadFavorites();
    if (!mounted) return;
    setState(() => _favoriteIds = favs.toSet());
  }

  bool _isFavorite(String id) => _favoriteIds.contains(id);

  Future<void> _toggleFavorite(String id) async {
    if (_isFavorite(id)) {
      await _favoritesManager.removeFavorite(id);
      _favoriteIds.remove(id);
    } else {
      await _favoritesManager.addFavorite(id);
      _favoriteIds.add(id);
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<List<VideoModel>> _loadCategoryCache(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('cache_$category');
    if (jsonString == null) return [];
    try {
      final list = jsonDecode(jsonString) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => VideoModel.fromJson(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveCategoryCache(String category, List<VideoModel> videos) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = videos.map((e) => e.toJson()).toList();
    await prefs.setString('cache_$category', jsonEncode(jsonList));
  }

  Future<void> _performSearch(String query) async {
    final currentSearchId = ++_searchQueryId;

    _searchNextToken = null;
    _searchHasMore = true;
    _pendingSearchPages.clear();
if (!mounted) return;
    setState(() {
      _isSearching = true;
      _searchResults.clear();
      _quotaExceeded = false;
      _searchLoading = true;
    });

    final cached = await _loadCategoryCache(query);
    if (cached.isNotEmpty && mounted && currentSearchId == _searchQueryId) {
      _cachedVideos[query] = {null: cached};
      if (!mounted) return;
      setState(() => _searchResults = cached);
    }

    try {
      final results = await _service.fetchShortVideos(query);
      if (!mounted || currentSearchId != _searchQueryId) return;

      _cachedVideos[query] = {null: results};
if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searchNextToken = _service.nextPageToken;
        _searchHasMore = _searchNextToken != null;
      });
    } on QuotaExceededException {
      if (mounted && currentSearchId == _searchQueryId) {
      if (!mounted) return;
        setState(() => _quotaExceeded = true);
      }
    } finally {
      if (mounted && currentSearchId == _searchQueryId) {
        if (!mounted) return;
        setState(() => _searchLoading = false);
      }
    }
  }

  Future<void> _loadMoreSearchResults() async {
    if (!_searchHasMore || _searchLoading || _quotaExceeded) return;

    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final key = "$query::$_searchNextToken";
    if (_pendingSearchPages.contains(key)) return;

    _pendingSearchPages.add(key);
if (!mounted) return;
    setState(() => _searchLoading = true);

    try {
      final newVideos = await _service.fetchShortVideos(query, pageToken: _searchNextToken);

      _searchNextToken = _service.nextPageToken;
      _searchHasMore = _searchNextToken != null;

      _cachedVideos.putIfAbsent(query, () => {})[_searchNextToken] = newVideos;

      final existingIds = _searchResults.map((v) => v.videoId).toSet();
      final uniqueVideos = newVideos.where((v) => !existingIds.contains(v.videoId)).toList();
if (!mounted) return;
      setState(() {
        _searchResults.addAll(uniqueVideos);
      });
    } on QuotaExceededException {
      if (!mounted) return;
      setState(() => _quotaExceeded = true);
    } finally {
      _pendingSearchPages.remove(key);
      if (!mounted) return;
      setState(() => _searchLoading = false);
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async{
      if (!mounted) return;
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        
        setState(() {
        _isSearching = false;
        _searchResults.clear();
        _quotaExceeded = false;
      });
      } else {
       await _performSearch(query);
      }
    });
  }
@override
void dispose() {
 _debounceTimer?.cancel();

  super.dispose();
}
  void _scrollListener() {
    const threshold = 700;
    if (_loading || _searchLoading || _quotaExceeded) return;

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - threshold) {
      if (_isSearching) {
        if (_searchHasMore) _loadMoreSearchResults();
      } else {
        if (_categoryHasMore) _loadCategoryPage();
      }
    }
  }

  void _onVideoTap(int index) {
    print('Opening ShortsScreen with videos count: ${_videos.length}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShortsScreen(
          videos: _isSearching ? _searchResults : _videos,
          initialIndex: index,
          favoriteIds: _favoriteIds,
          onToggle: (id) async {
            await _toggleFavorite(id);
          },
          loadMore: () async {
            if (_isSearching) 
              await _loadMoreSearchResults();
             else 
              await _loadCategoryPage();
            if (!mounted) return;
             setState(() {});
          },
          isLoading: _loading,
        ),
      ),
    );
  }

  void _onNavChanged(int index) {
    if (!mounted) return;
    setState(() {
      _selectedNavIndex = index;
      if (index == 0) _clearSearch();
    });
  }





  Widget _buildSearchAndCategories() {
    return Material(
      color: Colors.black,
      elevation: 4,
      shadowColor: Colors.redAccent.withOpacity(0.3),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 5),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search Shorts',
                        hintStyle: const TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        suffixIcon: _searchController.text.isEmpty ? const Icon(Icons.search, color: Colors.white70)
                            : GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _clearSearch();
                                  FocusScope.of(context).unfocus();
                                },
                                child: const Icon(Icons.close, color: Colors.white70),
                              ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
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
                        final isSelected = cat.name == _selectedCategory;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.redAccent : Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isSelected ? const [
                              BoxShadow(color: Colors.redAccent, offset: Offset(0, 3), blurRadius: 8),
                            ] : null,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              if (!isSelected) _changeCategory(cat.name);
                              FocusScope.of(context).unfocus();
                            },
                            child: Row(
                              children: [
                                Icon(cat.icon, size: 20, color: isSelected ? Colors.white : Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildGrid() {
    if (_quotaExceeded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Feed temporarily unavailable due to API quota limits.\nPlease try again later.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
          ),
        ),
      );
    }
    List<VideoModel> activeList = _isSearching ? _searchResults : _videos;
    final fullCount = activeList.length + (activeList.length ~/ nativeAdInterval);
    if (activeList.isEmpty) {
      if (_loading || _searchLoading) return const Center(child: CircularProgressIndicator());
      return const Center(child: Text('No videos found.', style: TextStyle(color: Colors.white)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 9 / 16),
      itemCount: fullCount,
      itemBuilder: (context, index) {
        if (index > 0 && index % nativeAdInterval == 0) {
          // Insert native ad every 6th item
          return AdManager.of(context)?.nativeAdWidget(height: 90) ??
              const SizedBox(height: 90);
        }
        final videoIndex = index - (index ~/ nativeAdInterval);
        final video = activeList[videoIndex];
        return GestureDetector(
          onTap: () => _onVideoTap(videoIndex),
          child: Stack(
            children: [
              _VideoPreview(video: video),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(color: Colors.white,
                     fontSize: 14,
                     fontWeight: FontWeight.bold,
                     shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black54)],),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      Column(
        children: [
          _buildSearchAndCategories(),
          Expanded(child: _buildGrid()),
        ],
      ),
      FavoritesScreen(allVideos: _videos),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReelRush'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: tabs[_selectedNavIndex],
bottomNavigationBar:Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AdManager.of(context)?.bannerAdWidget() ?? const SizedBox(height: 50)
      ,BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.white70,
        backgroundColor: Colors.black,
        onTap: _onNavChanged,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
        ],
       
      )
       ]
      ),
    
      
    );
  }
}
