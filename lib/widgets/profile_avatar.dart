import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrlOrPath;
  final double radius;

  const ProfileAvatar({super.key, this.imageUrlOrPath, this.radius = 24});

  Future<String?> _resolveUrl(String? pathOrUrl) async {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;

    // Case 1: Already a valid URL
    if (pathOrUrl.startsWith("http")) {
      if (pathOrUrl.contains(".firebasestorage.app")) {
        return pathOrUrl.replaceAll(".firebasestorage.app", ".appspot.com");
      }
      return pathOrUrl;
    }

    // Case 2: It’s a Firebase Storage path → generate fresh URL
    try {
      return await FirebaseStorage.instance.ref(pathOrUrl).getDownloadURL();
    } catch (e) {
      debugPrint("⚠️ Failed to get download URL for $pathOrUrl: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveUrl(imageUrlOrPath),
      builder: (context, snapshot) {
        final url = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, color: Colors.white),
          );
        }
        if (imageUrlOrPath != null && imageUrlOrPath!.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(imageUrlOrPath!),
            backgroundColor: Colors.grey.shade200,
            onBackgroundImageError: (_, __) {
              debugPrint("Failed to load profile: $imageUrlOrPath");
            },
          );
        }
        if (url == null || url.isEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, color: Colors.white),
          );
        }

        return CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).colorScheme.primary,
          backgroundImage: const AssetImage("assets/default_avatar.png"),
        );
      },
    );
  }
}
