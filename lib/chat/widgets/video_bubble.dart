import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

class VideoThumbBubble extends StatelessWidget {
  final String url;
  final String? thumbUrl;
  final int durationMs;

  const VideoThumbBubble({
    super.key,
    required this.url,
    required this.thumbUrl,
    required this.durationMs,
  });

  String _fmtDur(int ms) {
    final d = Duration(milliseconds: ms);
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _VideoPlayerPage(videoUrl: url),
          ),
        );
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: thumbUrl != null
                ? CachedNetworkImage(
              imageUrl: thumbUrl!,
              width: 240,
              height: 160,
              fit: BoxFit.cover,
            )
                : Container(
              width: 240,
              height: 160,
              color: Colors.black26,
              alignment: Alignment.center,
              child: const Icon(Icons.videocam),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 36),
              ),
            ),
          ),
          if (durationMs > 0)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _fmtDur(durationMs),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerPage({required this.videoUrl});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late final VideoPlayerController _vc;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _vc = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _vc.initialize().then((_) {
      setState(() => _ready = true);
      _vc.play();
    });
  }

  @override
  void dispose() {
    _vc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(),
      body: Center(
        child: _ready
            ? AspectRatio(
          aspectRatio: _vc.value.aspectRatio,
          child: VideoPlayer(_vc),
        )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: _ready
          ? FloatingActionButton(
        onPressed: () => setState(() {
          _vc.value.isPlaying ? _vc.pause() : _vc.play();
        }),
        child:
        Icon(_vc.value.isPlaying ? Icons.pause : Icons.play_arrow),
      )
          : null,
    );
  }
}
