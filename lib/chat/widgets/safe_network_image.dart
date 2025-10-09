import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _placeholder("No image");
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => _placeholder("Loading..."),
        errorWidget: (_, __, ___) => _placeholder("Offline"),
      ),
    );
  }

  Widget _placeholder(String message) => Container(
    color: Colors.grey.shade300,
    width: width,
    height: height,
    alignment: Alignment.center,
    child: Text(
      message,
      style: const TextStyle(color: Colors.black54, fontSize: 12),
    ),
  );
}
