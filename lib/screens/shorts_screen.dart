import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:reelrush/services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../widgets/ad_manager.dart';
import '../services/auth_service.dart';

class ShortsScreen extends StatefulWidget {
  final List videos;
  final int initialIndex;
  final Set favoriteIds;
  final Function(String) onToggle;
  final Future Function() loadMore;
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

class _ShortsScreenState extends State<ShortsScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  final Map<int, YoutubePlayerController> _controllers = {};
  late Set favoriteIds;
  int _currentIndex = 0;
  int _videosViewed = 0;
  Set<String> _likedVideos = {};

  static const int _preloadWindow = 2;
  AuthService _authService = AuthService();
  User? _firebaseUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    favoriteIds = Set.from(widget.favoriteIds);
    
    _pageController = PageController(initialPage: _currentIndex);
    
    // Initialize controllers first, then start playing
    _initializeControllers();
    
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _firebaseUser = user;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controllers[_currentIndex];
    if (controller == null) return;
    
    if (state == AppLifecycleState.paused) {
      controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      controller.play();
    }
  }

  void _initializeControllers() {
    // Create controllers for current and nearby videos
    for (int i = 0; i < widget.videos.length; i++) {
      if (i >= _currentIndex - _preloadWindow && i <= _currentIndex + _preloadWindow) {
        _createController(i);
      }
    }
    
    // Start playing the current video after a brief delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _playCurrentVideo();
      }
    });
  }

  void _createController(int index) {
    if (_controllers.containsKey(index) || index >= widget.videos.length) return;
    
    final video = widget.videos[index];
    _controllers[index] = YoutubePlayerController(
      initialVideoId: video.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: true,
        loop: false,
        isLive: false,
        enableCaption: false,
        hideControls: false,
        controlsVisibleAtStart: false,
        useHybridComposition: true,
      ),
    );
  }

  void _playCurrentVideo() {
    // Pause all videos first
    for (int i = 0; i < _controllers.length; i++) {
      final controller = _controllers[i];
      if (controller != null && i != _currentIndex) {
        controller.pause();
      }
    }

    // Play current video with sound
    final currentController = _controllers[_currentIndex];
    if (currentController != null) {
      currentController.play();
      // Make sure it's unmuted
      if (currentController.flags.mute) {
        // Create a new controller if the current one is muted
        _recreateCurrentController();
      }
    }
  }

  void _recreateCurrentController() {
    final currentController = _controllers[_currentIndex];
    if (currentController != null) {
      currentController.dispose();
    }
    
    final video = widget.videos[_currentIndex];
    _controllers[_currentIndex] = YoutubePlayerController(
      initialVideoId: video.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: true,
        loop: false,
        isLive: false,
        enableCaption: false,
        hideControls: false,
        controlsVisibleAtStart: false,
        useHybridComposition: true,
      ),
    );
    
    setState(() {});
  }

  void _manageControllers(int newIndex) {
    // Create controllers for the new window
    for (int i = newIndex - _preloadWindow; i <= newIndex + _preloadWindow; i++) {
      if (i >= 0 && i < widget.videos.length) {
        _createController(i);
      }
    }

    // Only dispose controllers that are very far away to prevent memory issues
    // Keep more controllers in memory for smoother scrolling
    final keysToRemove = <int>[];
    for (final key in _controllers.keys) {
      if (key < newIndex - (_preloadWindow * 3) || key > newIndex + (_preloadWindow * 3)) {
        keysToRemove.add(key);
      }
    }
    
    for (final key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }
  }

  Future<void> _onPageChanged(int index) async {
    if (index < 0 || index >= widget.videos.length) return;
    
    setState(() {
      _currentIndex = index;
      _videosViewed++;
    });

    _manageControllers(index);
    
    // Play the new current video immediately
    _playCurrentVideo();

    // Load more videos much earlier for true infinite scroll
    // Start loading when user is 3 videos away from the end
    if (index >= widget.videos.length - 3 && !widget.isLoading) {
      try {
        await widget.loadMore();
        if (mounted) {
          setState(() {
            // Refresh the UI to show new videos are available
          });
        }
      } catch (e) {
        print('Error loading more videos: $e');
      }
    }

    // Show ads
    if (_videosViewed % 7 == 0) {
      final adManager = AdManager.of(context);
      if (adManager != null) {
        await adManager.showRewardedInterstitialAd(context);
      }
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

  Future<void> _handleLike({required String videoId, required bool isLikeAction}) async {
    if (_firebaseUser == null) {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign-in required to perform this action')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() { 
          _firebaseUser = user; 
        });
      }
    }
    
    if (mounted) {
      setState(() {
        if (isLikeAction) {
          if (_likedVideos.contains(videoId)) {
            _likedVideos.remove(videoId);
          } else {
            _likedVideos.add(videoId);
          }
        }
      });
    }
  }

  void _handleFavoriteToggle() {
    // Ensure we have a valid current video
    if (_currentIndex >= widget.videos.length) return;
    
    final currVideoId = widget.videos[_currentIndex].videoId;
    widget.onToggle(currVideoId);
    
    if (mounted) {
      setState(() {
        if (favoriteIds.contains(currVideoId)) {
          favoriteIds.remove(currVideoId);
        } else {
          favoriteIds.add(currVideoId);
        }
      });
    }
  }

  void _onShare() {
    // Ensure we have a valid current video
    if (_currentIndex >= widget.videos.length) return;
    
    final video = widget.videos[_currentIndex];
    final url = 'https://www.youtube.com/watch?v=${video.videoId}';
    Share.share('Check out this video on ReelRush: $url');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No videos available', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final video = widget.videos[index];
              final controller = _controllers[index];

              if (controller == null) {
                return Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  ),
                );
              }

              return GestureDetector(
                onTap: _togglePlayPause,
                child: YoutubePlayerBuilder(
                  player: YoutubePlayer(
                    key: ValueKey('${video.videoId}_$index'),
                    controller: controller,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: Colors.redAccent,
                    progressColors: const ProgressBarColors(
                      playedColor: Colors.redAccent,
                      handleColor: Colors.redAccent,
                      backgroundColor: Colors.grey,
                      bufferedColor: Colors.white24,
                    ),
                    onEnded: (_) {
                      if (_currentIndex < widget.videos.length - 1) {
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (mounted) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.fastLinearToSlowEaseIn,
                            );
                          }
                        });
                      }
                    },
                    bottomActions: const [],
                    topActions: const [],
                  ),
                  builder: (context, player) => Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: player,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Action buttons - Only show if we have a valid current video
          if (_currentIndex < widget.videos.length)
            Positioned(
              bottom: 120,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: _likedVideos.contains(widget.videos[_currentIndex].videoId)
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    color: _likedVideos.contains(widget.videos[_currentIndex].videoId)
                        ? Colors.redAccent
                        : Colors.white,
                    onPressed: () => _handleLike(
                      videoId: widget.videos[_currentIndex].videoId,
                      isLikeAction: true,
                    ),
                    tooltip: 'Like',
                  ),
                  const SizedBox(height: 20),
                  
                  _buildActionButton(
                    icon: Icons.share,
                    color: Colors.white,
                    onPressed: _onShare,
                    tooltip: 'Share',
                  ),
                  const SizedBox(height: 20),
                  
                  _buildActionButton(
                    icon: favoriteIds.contains(widget.videos[_currentIndex].videoId)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: favoriteIds.contains(widget.videos[_currentIndex].videoId)
                        ? Colors.redAccent
                        : Colors.white,
                    onPressed: _handleFavoriteToggle,
                    tooltip: 'Favorite',
                  ),
                ],
              ),
            ),

          // Video title - Only show if we have a valid current video
          if (_currentIndex < widget.videos.length)
            Positioned(
              left: 16,
              right: 80,
              bottom: 40,
              child: Text(
                widget.videos[_currentIndex].title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [
                    Shadow(blurRadius: 8, offset: Offset(0, 2), color: Colors.black87),
                  ],
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          if (widget.isLoading)
            const Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 32, color: color),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
      ),
    );
  }
}