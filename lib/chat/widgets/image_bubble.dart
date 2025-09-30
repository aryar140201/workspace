import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageBubble extends StatelessWidget {
  final String url;
  const ImageBubble({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 220,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 220,
          height: 160,
          color: Colors.black12,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 220,
          height: 160,
          color: Colors.black26,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image),
        ),
      ),
    );
  }
}
