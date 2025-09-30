import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../core/fcm_sender.dart';
import 'encryption_helper.dart';
import 'upload_helper.dart';

class ChatService {
  final String otherUserId;
  final _auth = FirebaseAuth.instance;

  final CollectionReference<Map<String, dynamic>> chatsCol =
  FirebaseFirestore.instance.collection("chats");

  late final String currentUid;
  late final String chatId;
  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  late final EncryptionHelper _crypto;
  final ImagePicker _picker = ImagePicker();
  final Map<String, double> uploadProgress = {};
  late final UploadHelper _uploader;

  ChatService(this.otherUserId) {
    currentUid = _auth.currentUser!.uid;
    final ids = [currentUid, otherUserId]..sort();
    chatId = "${ids[0]}_${ids[1]}";
    _crypto = EncryptionHelper(chatId);
    _uploader = UploadHelper(this, uploadProgress);
  }

  DocumentReference<Map<String, dynamic>> get chatRef => chatsCol.doc(chatId);
  CollectionReference<Map<String, dynamic>> get msgsCol =>
      chatRef.collection("messages");

  Stream<QuerySnapshot<Map<String, dynamic>>> get messagesStream =>
      msgsCol.orderBy("createdAt").snapshots();

  Future<void> ensureChat() async {
    final snap = await chatRef.get();
    if (!snap.exists) {
      await chatRef.set({
        "participants": [currentUid, otherUserId],
        "createdAt": FieldValue.serverTimestamp(),
        "lastMessage": null,
      });
    }
  }

  // Future<void> sendText() async {
  //   final text = textController.text.trim();
  //   if (text.isEmpty) return;
  //
  //   final encrypted = _crypto.encryptText(text);
  //   final msgDoc = {
  //     "text": encrypted,
  //     "senderId": currentUid,
  //     "createdAt": FieldValue.serverTimestamp(),
  //     "readBy": {currentUid: true},
  //   };
  //
  //   await msgsCol.add(msgDoc);
  //
  //   await chatRef.set({
  //     "lastMessage": msgDoc,
  //     "updatedAt": FieldValue.serverTimestamp(),
  //   }, SetOptions(merge: true));
  //
  //   textController.clear();
  //   _scrollToBottom();
  // }
  Future<void> sendText({Map<String, dynamic>? replyTo}) async {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    final encrypted = _crypto.encryptText(text);

    final msgDoc = {
      "text": encrypted,
      "senderId": currentUid,
      "createdAt": FieldValue.serverTimestamp(),
      "readBy": {currentUid: true},
      if (replyTo != null)
        "replyTo": {
          "id": replyTo["id"],
          "senderId": replyTo["senderId"],
          "type": replyTo["type"] ?? "text",
          "text": replyTo["text"],
          "fileUrl": replyTo["fileUrl"],
        },
    };

    // Save message
    await msgsCol.add(msgDoc);

    // Update chat last message
    await chatRef.set({
      "lastMessage": msgDoc,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    textController.clear();
    _scrollToBottom();
  }
  Future<void> sendMediaMessage({
    required String type,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? mime,
    String? thumbUrl,
    int? durationMs,
    int? width,
    int? height,
  }) async {
    final now = FieldValue.serverTimestamp();
    final newMsgRef = msgsCol.doc();

    final msg = {
      'senderId': currentUid,
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'mime': mime,
      'thumbUrl': thumbUrl,
      'durationMs': durationMs,
      'width': width,
      'height': height,
      'createdAt': now,
      'deliveredBy': <String, bool>{},
      'readBy': {currentUid: true},
      'deletedFor': <String, bool>{},
    };

    final batch = FirebaseFirestore.instance.batch();
    batch.set(newMsgRef, msg);
    batch.set(
      chatRef,
      {
        'updatedAt': now,
        'lastMessage': {
          'id': newMsgRef.id,
          'type': type,
          'fileUrl': fileUrl,
          'fileName': fileName,
          'senderId': currentUid,
          'createdAt': now,
          'readBy': {currentUid: true, otherUserId: false},
        },
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> markAllRead() async {
    final unread =
    await msgsCol.where("readBy.$currentUid", isEqualTo: false).get();
    for (final d in unread.docs) {
      d.reference.update({"readBy.$currentUid": true});
    }
  }

  Future<void> markDelivered(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    for (final d in docs) {
      final m = d.data();
      if (m["senderId"] != currentUid) {
        d.reference.update({"deliveredBy.$currentUid": true});
      }
    }
  }

  // Future<void> deleteMessage(String id, {bool forBoth = false}) async {
  //   final docRef = msgsCol.doc(id);
  //   final snap = await docRef.get();
  //   if (!snap.exists) return;
  //
  //   final data = snap.data()!;
  //   final senderId = data['senderId'];
  //
  //   if (forBoth) {
  //     if (senderId == currentUid) {
  //       await docRef.delete();
  //     } else {
  //       await docRef.update({"deletedFor.$currentUid": true});
  //     }
  //   } else {
  //     await docRef.update({"deletedFor.$currentUid": true});
  //   }
  // }
  Future<void> deleteMessage(String id, {bool forBoth = false}) async {
    final docRef = msgsCol.doc(id);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final senderId = data['senderId'];

    if (forBoth) {
      if (senderId == currentUid) {
        await docRef.update({
          "text": null,
          "fileUrl": null,
          "fileName": null,
          "mime": null,
          "type": "deleted",
          "deletedForEveryone": true,
          "deletedAt": FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.update({
          "deletedFor.$currentUid": true,
        });
      }
    } else {
      // 👤 Delete only for me
      await docRef.update({
        "deletedFor.$currentUid": true,
      });
    }
  }

  String decryptTextSafe(String? cipherJson) {
    if (cipherJson == null) return '';
    return _crypto.decryptText(cipherJson);
  }

  void openAttachmentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () async {
                Navigator.pop(context);
                final xfile =
                await _picker.pickImage(source: ImageSource.camera);
                if (xfile != null) {
                  await _uploader.uploadMediaFile(
                    File(xfile.path),
                    typeHint: 'image',
                    originalName: xfile.name,
                    context: context,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("Gallery"),
              onTap: () async {
                Navigator.pop(context);
                final xfile =
                await _picker.pickImage(source: ImageSource.gallery);
                if (xfile != null) {
                  await _uploader.uploadMediaFile(
                    File(xfile.path),
                    typeHint: 'image',
                    originalName: xfile.name,
                    context: context,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text("Video"),
              onTap: () async {
                Navigator.pop(context);
                final xfile =
                await _picker.pickVideo(source: ImageSource.gallery);
                if (xfile != null) {
                  await _uploader.uploadMediaFile(
                    File(xfile.path),
                    typeHint: 'video',
                    originalName: xfile.name,
                    context: context,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text("Document"),
              onTap: () async {
                Navigator.pop(context);
                final res = await FilePicker.platform.pickFiles();
                if (res != null && res.files.single.path != null) {
                  final f = File(res.files.single.path!);
                  await _uploader.uploadMediaFile(
                    f,
                    typeHint: 'file',
                    originalName: res.files.single.name,
                    context: context,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
