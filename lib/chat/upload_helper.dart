import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';

import 'ProfileUploadHelper.dart';
import 'chat_service.dart';

const _kMaxUploadBytes = 30 * 1024 * 1024; // 30 MB

class UploadHelper {
  final ChatService _chatService;
  final Map<String, double> uploadProgress;

  UploadHelper(this._chatService, this.uploadProgress);
  Future<void> updateProfilePic(File file, BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Upload and get URL
    final url = await ProfileUploadHelper.uploadProfilePic(
      file: file,
      uid: uid,
      context: context,
    );

    if (url != null) {
      // ✅ Save download URL in Firestore under "users"
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "profilePic": url,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile picture updated ✅")),
      );
    }
  }
  Future<void> uploadMediaFile(
      File file, {
        required String typeHint, // image | video | audio
        required String originalName,
        int? durationMsHint,
        required BuildContext context,
      }) async {
    final bytes = await file.length();
    if (bytes > _kMaxUploadBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File too large. Max 30 MB.')),
      );
      return;
    }

    final mime = lookupMimeType(originalName) ??
        (typeHint == 'image'
            ? 'image/jpeg'
            : typeHint == 'video'
            ? 'video/mp4'
            : 'audio/m4a');

    final baseName = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9\._-]'), '_');
    final storagePath =
        'chat_uploads/${_chatService.chatId}/${DateTime.now().millisecondsSinceEpoch}_$baseName';

    final ref = FirebaseStorage.instance.ref(storagePath);
    final upload = ref.putFile(file, SettableMetadata(contentType: mime));

    // track progress
    uploadProgress[storagePath] = 0;
    upload.snapshotEvents.listen((s) {
      final total = s.totalBytes == 0 ? 1 : s.totalBytes;
      uploadProgress[storagePath] = s.bytesTransferred / total;
    });

    final snap = await upload.whenComplete(() {});
    final url = await snap.ref.getDownloadURL();

    String? thumbUrl;
    int? width;
    int? height;
    int? durationMs = durationMsHint;

    if (typeHint == 'video') {
      // generate thumbnail
      final uint8 = await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 75,
      );
      if (uint8 != null) {
        final thumbRef = FirebaseStorage.instance.ref(
            'chat_uploads/${_chatService.chatId}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await thumbRef.putData(
          Uint8List.fromList(uint8),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        thumbUrl = await thumbRef.getDownloadURL();
      }

      try {
        final vp = VideoPlayerController.file(file);
        await vp.initialize();
        durationMs = vp.value.duration.inMilliseconds;
        width = vp.value.size.width.toInt();
        height = vp.value.size.height.toInt();
        await vp.dispose();
      } catch (_) {}

      await _chatService.sendMediaMessage(
        type: 'video',
        fileUrl: url,
        fileName: baseName,
        fileSize: bytes,
        mime: mime,
        thumbUrl: thumbUrl,
        durationMs: durationMs,
        width: width,
        height: height,
      );
    } else if (typeHint == 'image') {
      await _chatService.sendMediaMessage(
        type: 'image',
        fileUrl: url,
        fileName: baseName,
        fileSize: bytes,
        mime: mime,
      );
    } else if (typeHint == 'audio') {
      durationMs ??= 0;
      await _chatService.sendMediaMessage(
        type: 'audio',
        fileUrl: url,
        fileName: baseName,
        fileSize: bytes,
        mime: mime,
        durationMs: durationMs,
      );
    }

    uploadProgress.remove(storagePath);
  }
}
