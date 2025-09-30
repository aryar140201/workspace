import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ProfileUploadHelper {
  static const _kMaxUploadBytes = 5 * 1024 * 1024; // 5 MB for profile pic

  static Future<String?> uploadProfilePic({
    required File file,
    required String uid,
    required BuildContext context,
  }) async {
    final bytes = await file.length();
    if (bytes > _kMaxUploadBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture too large. Max 5 MB.')),
      );
      return null;
    }

    final baseName = file.path.split('/').last.replaceAll(RegExp(r'[^a-zA-Z0-9\._-]'), '_');
    final storagePath = "profile_pics/$uid/$baseName";

    final ref = FirebaseStorage.instance.ref(storagePath);
    final upload = ref.putFile(
      file,
      SettableMetadata(contentType: "image/jpeg"),
    );

    await upload.whenComplete(() {});
    final url = await ref.getDownloadURL(); // ✅ always get URL from Firebase

    return url; // return download URL to save in Firestore
  }
}
