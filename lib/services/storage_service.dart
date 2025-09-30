import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a profile picture and delete old one if exists
  Future<String?> uploadProfileImage({
    required String uid,
    required File file,
    String? oldUrl,
  }) async {
    try {
      // Generate unique filename
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final ref = _storage.ref().child("profile_pics/$uid/$fileName");

      // Upload file with metadata
      await ref.putFile(
        file,
        SettableMetadata(contentType: "image/jpeg"),
      );
      print("Uploaded file to: ${ref.fullPath}");

      // Get download URL
      var newUrl = await ref.getDownloadURL();
      // print("Download URL: $newUrl");

      // DO NOT replace .firebasestorage.app with .appspot.com
      // Your project bucket is workspace-fd140.firebasestorage.app

      // Delete old file if exists
      if (oldUrl != null && oldUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(oldUrl).delete();
          print("Deleted old profile picture: $oldUrl");
        } catch (e) {
          print("Old file delete error: $e");
        }
      }

      return newUrl;
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }

  /// Delete any file by its Firebase URL
  Future<void> deleteFile(String fileUrl) async {
    try {
      await _storage.refFromURL(fileUrl).delete();
      print("🗑Deleted file: $fileUrl");
    } catch (e) {
      print("Delete error: $e");
    }
  }
}
