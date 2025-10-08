import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';

import 'encryption_helper.dart';

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

  ChatService(this.otherUserId) {
    currentUid = _auth.currentUser!.uid;
    final ids = [currentUid, otherUserId]..sort();
    chatId = "${ids[0]}_${ids[1]}";
    _crypto = EncryptionHelper(chatId);
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

  /// ✅ Mark delivered with timestamp
  Future<void> markDelivered(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    for (final d in docs) {
      final m = d.data();
      if (m["senderId"] != currentUid) {
        final deliveredMap = (m["deliveredBy"] as Map?) ?? {};
        if (!deliveredMap.containsKey(currentUid)) {
          await d.reference.update({
            "deliveredBy.$currentUid": FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  /// ✅ Send text message
  Future<void> sendText({Map<String, dynamic>? replyTo}) async {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    final encrypted = _crypto.encryptText(text);
    final msgId = msgsCol.doc().id;

    final msgDoc = {
      "id": msgId,
      "type": "text",
      "text": encrypted,
      "senderId": currentUid,
      "createdAt": FieldValue.serverTimestamp(),
      "deliveredBy": {},
      "readBy": {},
      "deletedFor": {},
      if (replyTo != null)
        "replyTo": {
          "id": replyTo["id"],
          "senderId": replyTo["senderId"],
          "type": replyTo["type"] ?? "text",
          "text": replyTo["text"],
          "fileUrl": replyTo["fileUrl"],
        },
    };

    await msgsCol.doc(msgId).set(msgDoc);

    // update chat preview
    await chatRef.set({
      "lastMessage": msgDoc,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    textController.clear();
    _scrollToBottom();
  }

  /// ✅ Upload & send media
  Future<void> sendMediaMessage({
    required File file,
    required String type, // "image", "video", "file"
    String? originalName,
    Map<String, dynamic>? extraMeta,
  }) async {
    final now = FieldValue.serverTimestamp();
    final newMsgRef = msgsCol.doc();

    final fileSize = await file.length();
    final mime = lookupMimeType(file.path) ?? "application/octet-stream";

    final msg = {
      'id': newMsgRef.id,
      'senderId': currentUid,
      'type': type,
      'fileUrl': null,
      'fileName': originalName ?? file.path.split("/").last,
      'fileSize': fileSize,
      'mime': mime,
      'createdAt': now,
      'deliveredBy': {},
      'readBy': {},
      'deletedFor': {},
      'uploading': true,
      'progress': 0.0,
      ...?extraMeta,
    };

    await newMsgRef.set(msg);

    await chatRef.set(
      {
        'updatedAt': now,
        'lastMessage': {
          'id': newMsgRef.id,
          'type': type,
          'fileName': msg['fileName'],
          'senderId': currentUid,
          'createdAt': now,
          'readBy': {},
        },
      },
      SetOptions(merge: true),
    );

    _scrollToBottom();

    // Upload to Firebase Storage
    final storageRef = FirebaseStorage.instance
        .ref("chatMedia/$chatId/${newMsgRef.id}_${msg['fileName']}");

    final uploadTask =
    storageRef.putFile(file, SettableMetadata(contentType: mime));

    uploadTask.snapshotEvents.listen((event) async {
      final progress =
          event.bytesTransferred / (event.totalBytes == 0 ? 1 : event.totalBytes);

      await newMsgRef.update({"progress": progress});

      if (event.state == TaskState.success) {
        final url = await storageRef.getDownloadURL();
        await newMsgRef.update({
          "fileUrl": url,
          "uploading": false,
          "progress": null,
        });
      }
    });
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

  /// ✅ Mark messages as read (with timestamp)
  Future<void> markAllRead() async {
    final snap = await msgsCol.get();
    for (final d in snap.docs) {
      final m = d.data();
      if (m["senderId"] != currentUid) {
        final readMap = (m["readBy"] as Map?) ?? {};
        if (!readMap.containsKey(currentUid)) {
          await d.reference.update({
            "readBy.$currentUid": FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }


  /// ✅ Delete message (time-sensitive)
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
      await docRef.update({
        "deletedFor.$currentUid": true,
      });
    }
  }

  String decryptTextSafe(String? cipherJson) {
    if (cipherJson == null) return '';
    return _crypto.decryptText(cipherJson);
  }

  /// ✅ Attachment sheet
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
                final xfile = await _picker.pickImage(source: ImageSource.camera);
                if (xfile != null) {
                  await sendMediaMessage(
                    file: File(xfile.path),
                    type: 'image',
                    originalName: xfile.name,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("Gallery"),
              onTap: () async {
                Navigator.pop(context);
                final xfile = await _picker.pickImage(source: ImageSource.gallery);
                if (xfile != null) {
                  await sendMediaMessage(
                    file: File(xfile.path),
                    type: 'image',
                    originalName: xfile.name,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text("Video"),
              onTap: () async {
                Navigator.pop(context);
                final xfile = await _picker.pickVideo(source: ImageSource.gallery);
                if (xfile != null) {
                  await sendMediaMessage(
                    file: File(xfile.path),
                    type: 'video',
                    originalName: xfile.name,
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
                  await sendMediaMessage(
                    file: f,
                    type: 'file',
                    originalName: res.files.single.name,
                    extraMeta: {
                      "extension": res.files.single.extension,
                    },
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
