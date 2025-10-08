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

    final url = await ProfileUploadHelper.uploadProfilePic(
      file: file,
      uid: uid,
      context: context,
    );

    if (url != null) {
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
        required String typeHint, // image | video | audio | file
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
            : 'application/octet-stream');

    final baseName =
    originalName.replaceAll(RegExp(r'[^a-zA-Z0-9\._-]'), '_');
    final storagePath =
        'chat_uploads/${_chatService.chatId}/${DateTime.now().millisecondsSinceEpoch}_$baseName';

    final ref = FirebaseStorage.instance.ref(storagePath);

    // 🔹 Create a placeholder message in Firestore
    final msgRef = _chatService.msgsCol.doc();
    await msgRef.set({
      'senderId': _chatService.currentUid,
      'type': typeHint,
      'fileName': baseName,
      'fileSize': bytes,
      'mime': mime,
      'createdAt': FieldValue.serverTimestamp(),
      'uploading': true,
      'progress': 0.0,
      'readBy': {_chatService.currentUid: true},
      'deletedFor': <String, bool>{},
    });

    // 🔹 Track upload progress
    final uploadTask = ref.putFile(file, SettableMetadata(contentType: mime));
    uploadProgress[storagePath] = 0;

    uploadTask.snapshotEvents.listen((s) async {
      final total = s.totalBytes == 0 ? 1 : s.totalBytes;
      final progress = s.bytesTransferred / total;

      uploadProgress[storagePath] = progress;

      // update Firestore doc with progress
      await msgRef.update({"progress": progress});
    });

    // 🔹 Wait for completion
    final snap = await uploadTask.whenComplete(() {});
    final url = await snap.ref.getDownloadURL();

    String? thumbUrl;
    int? width;
    int? height;
    int? durationMs = durationMsHint;

    if (typeHint == 'video') {
      // Generate thumbnail
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
    }

    // 🔹 Update the placeholder message with final data
    await msgRef.update({
      'fileUrl': url,
      'thumbUrl': thumbUrl,
      'durationMs': durationMs,
      'width': width,
      'height': height,
      'uploading': false,
      'progress': null,
    });

    uploadProgress.remove(storagePath);

    // 🔹 Update chat's last message
    await _chatService.chatRef.set(
      {
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': {
          'id': msgRef.id,
          'type': typeHint,
          'fileUrl': url,
          'fileName': baseName,
          'senderId': _chatService.currentUid,
          'createdAt': FieldValue.serverTimestamp(),
          'readBy': {_chatService.currentUid: true, _chatService.otherUserId: false},
        },
      },
      SetOptions(merge: true),
    );
  }
}
