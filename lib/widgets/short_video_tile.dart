import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video_model.dart';

class ShortVideoTile extends StatefulWidget {
  final VideoModel video;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final Function(bool visible) onVisibilityChanged;
  final VoidCallback onEnded;

  const ShortVideoTile({
    required this.video,
    required this.isPlaying,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onVisibilityChanged,
    required this.onEnded,
    Key? key,
  }) : super(key: key);

  @override
  State<ShortVideoTile> createState() => _ShortVideoTileState();
}

class _ShortVideoTileState extends State<ShortVideoTile> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.isPlaying,
        mute: true,
        hideControls: true,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ShortVideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: VisibilityDetector(
        key: Key('video-${widget.video.videoId}'),
        onVisibilityChanged: (info) {
          widget.onVisibilityChanged(info.visibleFraction > 0.6);
        },
        child: YoutubePlayerBuilder(
          player: YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            onEnded: (_) => widget.onEnded(),
          ),
          builder: (_, player) => Stack(
            fit: StackFit.expand,
            children: [
              player,
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: widget.onToggleFavorite,
                  child: Icon(
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: widget.isFavorite ? Colors.redAccent : Colors.white,
                    size: 26,
                    shadows: const [
                      Shadow(
                        blurRadius: 5,
                        color: Colors.black,
                      )
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 8,
                right: 8,
                child: Text(
                  widget.video.title,
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
  }
}
