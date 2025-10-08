import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

class MediaPreviewPage extends StatefulWidget {
  final String url;
  final String type; // "image" or "video"
  final String fileName;

  const MediaPreviewPage({
    super.key,
    required this.url,
    required this.type,
    required this.fileName,
  });

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.type == "video") {
      _controller = VideoPlayerController.network(widget.url)
        ..initialize().then((_) {
          setState(() {});
          _controller!.play();
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    bool? success;
    if (widget.type == "image") {
      success = await GallerySaver.saveImage(widget.url, albumName: "MyApp");
    } else if (widget.type == "video") {
      success = await GallerySaver.saveVideo(widget.url, albumName: "MyApp");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success == true
              ? "✅ Saved to gallery: ${widget.fileName}"
              : "❌ Failed to save",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _download,
          ),
        ],
      ),
      body: Center(
        child: widget.type == "image"
            ? InteractiveViewer(child: Image.network(widget.url))
            : (_controller != null && _controller!.value.isInitialized)
            ? AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: widget.type == "video"
          ? FloatingActionButton(
        backgroundColor: Colors.white,
        child: Icon(
          _controller?.value.isPlaying ?? false
              ? Icons.pause
              : Icons.play_arrow,
          color: Colors.black,
        ),
        onPressed: () {
          setState(() {
            if (_controller!.value.isPlaying) {
              _controller!.pause();
            } else {
              _controller!.play();
            }
          });
        },
      )
          : null,
    );
  }
}
