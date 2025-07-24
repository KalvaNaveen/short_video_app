import 'package:flutter/material.dart';
import '../utils/favorites_manager.dart';
import '../models/video_model.dart';  // adjust import to your video model path

class FavoritesScreen extends StatefulWidget {
  final List<VideoModel> allVideos;

  const FavoritesScreen({required this.allVideos, Key? key}) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesManager _favoritesManager = FavoritesManager();
  List<String> _favoriteVideoIds = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await _favoritesManager.loadFavorites();
    setState(() {
      _favoriteVideoIds = favs;
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
      return Center(child: Text('No favorite videos yet'));
    }

    return GridView.builder(
      padding: EdgeInsets.all(8),
      itemCount: favoriteVideos.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemBuilder: (_, index) {
        final video = favoriteVideos[index];
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                video.getThumbnailUrl(highQuality: true),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
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
                    Shadow(
                      blurRadius: 5,
                      color: Colors.black,
                      offset: Offset(0, 0),
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
