// import 'package:flutter/material.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:reelrush/main.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:youtube_player_flutter/youtube_player_flutter.dart';
// import '../widgets/ad_manager.dart';
// import '../services/google_sign_in_service.dart';

// class ShortsScreen extends StatefulWidget {
//   final List videos; // Live mutable reference
//   final int initialIndex;
//   final Set favoriteIds;
//   final Function(String) onToggle;
//   final Future Function() loadMore;
//   final bool isLoading;

//   const ShortsScreen({
//     required this.videos,
//     required this.initialIndex,
//     required this.favoriteIds,
//     required this.onToggle,
//     required this.loadMore,
//     required this.isLoading,
//     Key? key,
//   }) : super(key: key);

//   @override
//    _ShortsScreenState createState() => _ShortsScreenState();
// }

// class _ShortsScreenState extends State<ShortsScreen> with WidgetsBindingObserver {
//   late PageController _pageController;
//   final Map<int, YoutubePlayerController> _controllers = {};
//   late Set favoriteIds;
//   int _currentIndex = 0;
//   int _videosViewed = 0;
//   final GoogleSignInService _googleSignInService = GoogleSignInService();
//  GoogleSignInAccount? _user;
//  Set<String> _likedVideos = {}; // liked video IDs (sample)
//   Set<String> _subscribedChannels = {}; // subscribed channel names (sample)


//   @override
//   void initState() {
//     super.initState();
//     _googleSignInService.signIn().then((user) {
//       setState(() {
//         _user = user;
//       });
//     });
//     WidgetsBinding.instance.addObserver(this);
//     _currentIndex = widget.initialIndex;
//     favoriteIds = Set.from(widget.favoriteIds);

//     // Init page controller.
//     _pageController = PageController(initialPage: _currentIndex);

//     // Preload more videos for ultra-smooth scroll (expand window to 3 each side).
//     _initControllersAround(_currentIndex);

//     // Log screen view
//   analytics.logScreenView(screenName: 'ShortsScreen');
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     for (var c in _controllers.values) {
//       c.dispose();
//     }
//     _controllers.clear();
//     _pageController.dispose();
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     final controller = _controllers[_currentIndex];
//     if (controller == null) return;
//     if (state == AppLifecycleState.paused) {
//       controller.pause();
//     } else if (state == AppLifecycleState.resumed) {
//       controller.play();
//     }
//   }

//   void _initControllersAround(int idx) {
//     const window = 5; // Preload more videos before & after for zero spinner.
//     final indexes = [
//       for (var i = idx - window; i <= idx + window; i++)
//         if (i >= 0 && i < widget.videos.length) i
//     ];

//     // Dispose controllers outside the preload window.
//     for (final key in _controllers.keys.toList()) {
//       if (!indexes.contains(key)) {
//         _controllers[key]?.dispose();
//         _controllers.remove(key);
//       }
//     }

//     // Init/new controllers for upcoming videos.
//     for (final i in indexes) {
//       if (!_controllers.containsKey(i)) {
//         _controllers[i] = YoutubePlayerController(
//           initialVideoId: widget.videos[i].videoId,
//           flags: const YoutubePlayerFlags(
//             autoPlay: true,
//             mute: false,
//             disableDragSeek: true,
//             loop: false,
//             isLive: false,
//             enableCaption: false,
//             forceHD: true,
//           ),
//         );
//       }
//       if (i == idx) {
//         _controllers[i]!.play();
//       } else {
//         _controllers[i]!.pause();
//       }
//     }
  
//   }

//   String _formatCount(int count) {
//   if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
//   if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
//   return count.toString();
// }

// Future<void> _handleLikeOrSubscribe({
//     required String videoId,
//     required String channelName,
//     required bool isLikeAction,
//   }) async {
//     if (_user == null) {
//       // User not signed in, prompt sign in first
//       final user = await _googleSignInService.signIn();
//       if (user == null) {
//         // User cancelled sign in or error
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Sign-in required to perform this action')),
//         );
//         return;
//       }
//       setState(() {
//         _user = user;
//       });
//     }

//     // User is signed in - toggle like or subscription logic
//     setState(() {
//       if (isLikeAction) {
//         if (_likedVideos.contains(videoId)) {
//           _likedVideos.remove(videoId);
//         } else {
//           _likedVideos.add(videoId);
//         }
//       } else {
//         if (_subscribedChannels.contains(channelName)) {
//           _subscribedChannels.remove(channelName);
//         } else {
//           _subscribedChannels.add(channelName);
//         }
//       }
//     });

//     // TODO: Persist these changes to backend or local storage tied to _user.id
//   }


//   Future<void> _onPageChanged(int idx) async {
//     if (idx < 0 || idx >= widget.videos.length) return;
//     setState(() {
//       _currentIndex = idx;
//       _videosViewed++;
//     });

//     _initControllersAround(idx);


//     // Load more videos early, when 10 left
//     if (idx >= widget.videos.length - 10 && !widget.isLoading) {
//       await widget.loadMore();
//       if (mounted) setState(() {});
//     }
//     // Show Rewarded Ad every 7 videos (customize as needed)
//     if (_videosViewed % 7 == 0) {
//       final adManager = AdManager.of(context);
//       if (adManager != null) {
//         await adManager.showRewardedInterstitialAd(context);
//       }
//     }

//   }

//   void _togglePlayPause() {
//     final controller = _controllers[_currentIndex];
//     if (controller == null) return;
//     if (controller.value.isPlaying) {
//       controller.pause();
//     } else {
//       controller.play();
//     }
//     setState(() {});
//   }

//   void _handleFavoriteToggle() {
//     final currVideoId = widget.videos[_currentIndex].videoId;

//      // Log event before or after toggling
//   analytics.logEvent(
//     name: 'video_favorited',
//     parameters: {'video_id': currVideoId},
//   );
  
//     widget.onToggle(currVideoId);
//     setState(() {
//       if (favoriteIds.contains(currVideoId)) {
//         favoriteIds.remove(currVideoId);
//       } else {
//         favoriteIds.add(currVideoId);
//       }
//     });
//   }

//   void _onShare() {
//     final video = widget.videos[_currentIndex];
//     final url = 'https://www.youtube.com/watch?v=${video.videoId}';
//     Share.share('Check out this video on ReelRush: $url');
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (widget.videos.isEmpty) {
//       return Scaffold(
//         backgroundColor: Colors.black,
//         body: const Center(
//           child: Text('No videos available', style: TextStyle(color: Colors.white)),
//         ),
//       );
//     }

//     final video = widget.videos[_currentIndex];
//     final controller = _controllers[_currentIndex];

//     // Safety: guarantee controller is pre-initialized (should always be, but fallback if not).
//     if (controller == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     final isFav = favoriteIds.contains(video.videoId);
//     return YoutubePlayerBuilder(
//       player: YoutubePlayer(
//         key: ValueKey(video.videoId),
//         controller: controller,
//         showVideoProgressIndicator: true,
//         progressIndicatorColor: Colors.redAccent,
//         progressColors: const ProgressBarColors(
//           playedColor: Colors.redAccent,
//           handleColor: Colors.redAccent,
//         ),
//         onEnded: (_) async {
//           if (_currentIndex < widget.videos.length - 1) {
//             await Future.delayed(const Duration(milliseconds: 100));
//             _pageController.nextPage(
//               duration: const Duration(milliseconds: 200),
//               curve: Curves.fastEaseInToSlowEaseOut,
//             );
//           }
//         },
//         bottomActions: const [],
//       ),
//       builder: (context, player) => Scaffold(
//         backgroundColor: Colors.black,
//         body: Stack(
//           children: [
//             PageView.builder(
//               controller: _pageController,
//               scrollDirection: Axis.vertical,
//               itemCount: widget.videos.length,
//               onPageChanged: _onPageChanged,
//               itemBuilder: (context, index) {
//                 if (index == _currentIndex) {
//                   return GestureDetector(
//                     behavior: HitTestBehavior.opaque,
//                     onTap: _togglePlayPause,
//                     child: SizedBox.expand(child: player),
//                   );
//                 } else {
//                   // For preloading effect, show silent still when not focused.
//                   final silentController = _controllers[index];
//                   if (silentController != null) {
//                     silentController.pause();
//                   }
//                   return Container(color: Colors.black);
//                 }
//               },
//             ),
//             // Favorite and share buttons
//             Positioned(
//               bottom: 80,
//               right: 16,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   IconButton(
//                     icon: Icon(
//                       isFav ? Icons.favorite : Icons.favorite_border,
//                       size: 36,
//                       color: isFav ? Colors.redAccent : Colors.white,
//                     ),
//                     onPressed: _handleFavoriteToggle,
//                     tooltip: 'Favorite',
//                   ),
//                   const SizedBox(height: 16),
//                   IconButton(
//                     icon: const Icon(Icons.share, size: 28, color: Colors.white),
//                     onPressed: _onShare,
//                     tooltip: 'Share',
//                   ),
//                 ],
//               ),
//             ),
//             // Title/text details overlay
//             Positioned(
//   left: 16,
//   bottom: 80,
//   right: 16,
//   child: Row(
//     children: [
//       CircleAvatar(
//         radius: 20,
//         backgroundImage: NetworkImage(video.channelProfilePicUrl),
//       ),
//       const SizedBox(width: 12),
//       Expanded(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               video.channelName,
//               style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
//             ),
//             const SizedBox(height: 4),
//             Row(
//               children: [
//                 Text('${_formatCount(video.subscriberCount)} subscribers',
//                     style: TextStyle(color: Colors.white70, fontSize: 12)),
//                 const SizedBox(width: 12),
//                 Text('${_formatCount(video.totalViews)} views',
//                     style: TextStyle(color: Colors.white70, fontSize: 12)),
//                 const SizedBox(width: 12),
//                 Text('${_formatCount(video.totalLikes)} likes',
//                     style: TextStyle(color: Colors.white70, fontSize: 12)),
//               ],
//             ),
//           ],
//         ),
//       ),
//     ],
//   ),
// ),


//             Positioned(
//               left: 16,
//               right: 16,
//               bottom: 40,
//               child: Text(
//                 video.title,
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   shadows: [Shadow(blurRadius: 4, offset: Offset(0, 1), color: Colors.black54)],
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../widgets/ad_manager.dart';
import '../services/google_sign_in_service.dart';

// Make sure your Video model includes channelName, channelProfilePicUrl, subscriberCount, totalViews, totalLikes, etc.

class ShortsScreen extends StatefulWidget {
  final List videos; // List of your Video model
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

  final GoogleSignInService _googleSignInService = GoogleSignInService();
  GoogleSignInAccount? _user;
  Set<String> _likedVideos = {};
  Set<String> _subscribedChannels = {};

  // --- PRELOAD WINDOW: Controls how many videos before/after are kept hot. ---
  static const int _preloadWindow = 4; // 4 before + 4 after = 9 total kept hot

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    favoriteIds = Set.from(widget.favoriteIds);
    _pageController = PageController(initialPage: _currentIndex);
    _initControllersAround(_currentIndex);
    // Optionally auto sign in Google on widget open:
    _googleSignInService.signInSilently().then((user) {
      if (mounted) setState(() { _user = user; });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var c in _controllers.values) {
      c.dispose();
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

  void _initControllersAround(int idx) {
    // Compute a window of indexes before and after the current video, e.g. -4..+4
    final indexes = [
      for (int i = idx - _preloadWindow; i <= idx + _preloadWindow; i++)
        if (i >= 0 && i < widget.videos.length) i
    ];

    // Dispose controllers outside window, so memory is freed
    for (final key in _controllers.keys.toList()) {
      if (!indexes.contains(key)) {
        _controllers[key]?.dispose();
        _controllers.remove(key);
      }
    }

    // For all needed videos, initialize and pre-play controllers
    for (final i in indexes) {
      final video = widget.videos[i];
      if (!_controllers.containsKey(i)) {
        _controllers[i] = YoutubePlayerController(
          initialVideoId: video.videoId,
          flags: YoutubePlayerFlags(
            autoPlay: true,
            mute: false, // Mute by default, for preloading
            disableDragSeek: true,
            loop: false,
            isLive: false,
            enableCaption: false,
            //forceHD: true,
          ),
        );
      }
    }

    // Unmute and play *only* the current controller; mute and play the others
    for (final entry in _controllers.entries) {
      final controller = entry.value;
      if (entry.key == idx) {
        controller.play();
      } else {
        controller.play(); // keeps buffer hot, so next swipe = instant preplay
      }
    }
  }

  Future<void> _onPageChanged(int idx) async {
    if (idx < 0 || idx >= widget.videos.length) return;
    setState(() {
      _currentIndex = idx;
      _videosViewed++;
    });

    _initControllersAround(idx);

    // Load more early so infinite scroll never blocks
    if (idx >= widget.videos.length - 10 && !widget.isLoading) {
      await widget.loadMore();
      if (mounted) setState(() {});
    }

    // Show reward ad after N videos (optional)
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

  // Like & Subscribe logic with Google auth check
  Future<void> _handleLikeOrSubscribe({
    required String videoId,
    required bool isLikeAction,
  }) async {
    if (_user == null) {
      final user = await _googleSignInService.signIn();
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in required to perform this action')),
        );
        return;
      }
      setState(() { _user = user; });
    }
    setState(() {
      if (isLikeAction) {
        if (_likedVideos.contains(videoId)) {
          _likedVideos.remove(videoId);
        } else {
          _likedVideos.add(videoId);
        }
      }
    });
    // Optionally: persist these lists by user.id (see earlier example)
  }

  void _handleFavoriteToggle() {
    final currVideoId = widget.videos[_currentIndex].videoId;
    widget.onToggle(currVideoId);
    setState(() {
      if (favoriteIds.contains(currVideoId)) {
        favoriteIds.remove(currVideoId);
      } else {
        favoriteIds.add(currVideoId);
      }
    });
    // Optionally persist favorites as shown in previous answers
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
          child: Text('No videos available', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final video = widget.videos[_currentIndex];
    final controller = _controllers[_currentIndex];
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isFav = favoriteIds.contains(video.videoId);

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        key: ValueKey(video.videoId),
        controller: controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.redAccent,
        progressColors: const ProgressBarColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.redAccent,
        ),
        onEnded: (_) async {
          if (_currentIndex < widget.videos.length - 1) {
            await Future.delayed(const Duration(milliseconds: 100));
            _pageController.nextPage(
              duration: const Duration(milliseconds: 200),
              curve: Curves.fastEaseInToSlowEaseOut,
            );
          }
        },
        bottomActions: const [],
      ),
      builder: (context, player) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Main vertical scroll
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: widget.videos.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                if (index == _currentIndex) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _togglePlayPause,
                    child: SizedBox.expand(child: player),
                  );
                } else {
                  // Show silent still for preloading (no spinner experienced!)
                  return Container(color: Colors.black);
                }
              },
            ),
            // Action buttons
            Positioned(
              bottom: 120,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LIKE button (Google)
                  IconButton(
                    icon: Icon(
                      _likedVideos.contains(video.videoId)
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      color: _likedVideos.contains(video.videoId)
                          ? Colors.redAccent
                          : Colors.white,
                      size: 36,
                    ),
                    onPressed: () => _handleLikeOrSubscribe(
                      videoId: video.videoId,
                      isLikeAction: true,
                    ),
                    tooltip: 'Like',                   
                  ),
                  const SizedBox(height: 20),               
                  // FAVORITE
                  IconButton(
                    icon: const Icon(Icons.share, size: 36, color: Colors.white,),
                    onPressed: _onShare,
                    tooltip: 'Share',
                  ),
                  const SizedBox(height: 20),
                 // SHARE 
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      size: 36,
                      color: isFav ? Colors.redAccent : Colors.white,
                    ),
                    onPressed: _handleFavoriteToggle,
                    tooltip: 'Favorite',
                  ),
                ],
              ),
            ),
            // Video title overlay
            Positioned(
              left: 16,
              right: 16,
              bottom: 40,
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 4, offset: Offset(0, 1), color: Colors.black54)],
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

