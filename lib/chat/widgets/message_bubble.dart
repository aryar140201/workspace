import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import '../chat_service.dart';
import '../media_preview_page.dart';

class MessageBubble extends StatelessWidget {
  final String id;
  final Map<String, dynamic> message;
  final String currentUid;
  final String otherUserId;
  final Future<void> Function(String id) onDelete;
  final ChatService chatService;

  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  final void Function(Map<String, dynamic> message, String msgId)? onReply;
  final void Function(Map<String, dynamic> message)? onForward;

  MessageBubble({
    super.key,
    required this.id,
    required this.message,
    required this.currentUid,
    required this.otherUserId,
    required this.chatService,
    required this.onDelete,
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
    this.selectionMode = false,
    this.onReply,
    this.onForward,
  });

  /// store tap position for context menu
  late Offset _tapPosition;

  void _storePosition(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  /// ✅ Unified permission request for Android/iOS
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.photos.isGranted ||
          await Permission.videos.isGranted) {
        return true;
      }
      if (await Permission.storage.isGranted) {
        return true;
      }

      if (Platform.version.startsWith("13") ||
          Platform.version.startsWith("14")) {
        final statuses = await [Permission.photos, Permission.videos].request();
        return statuses.values.any((s) => s.isGranted);
      } else {
        final statuses = await [Permission.storage].request();
        return statuses.values.any((s) => s.isGranted);
      }
    } else if (Platform.isIOS) {
      var status = await Permission.photos.request();
      if (status.isPermanentlyDenied) {
        openAppSettings();
        return false;
      }
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  /// ✅ Save media to gallery or downloads
  Future<void> _saveMedia(BuildContext context, String fileUrl, String fileName,
      String type) async {
    bool hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Storage permission denied")),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⬇️ Downloading...")),
      );

      bool? success;

      if (type == "image") {
        success = await GallerySaver.saveImage(fileUrl, albumName: "MyApp");
      } else if (type == "video") {
        success = await GallerySaver.saveVideo(fileUrl, albumName: "MyApp");
      } else {
        final dir = Directory("/storage/emulated/0/Download");
        if (!await dir.exists()) await dir.create(recursive: true);

        final savePath = "${dir.path}/$fileName";
        final dio = Dio();
        final response = await dio.download(fileUrl, savePath);

        if (response.statusCode == 200) {
          success = true;
        }
      }

      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Saved successfully: $fileName")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Failed to save file")),
        );
      }
    } catch (e) {
      debugPrint("Error saving media: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error: $e")),
      );
    }
  }

  /// ✅ WhatsApp-style context menu
  void _showContextMenu(BuildContext context) async {
    final RenderBox overlay =
    Overlay
        .of(context)
        .context
        .findRenderObject() as RenderBox;

    final url = message["fileUrl"];
    final fileName =
        message["fileName"] ?? "file_${DateTime
            .now()
            .millisecondsSinceEpoch}";
    final type = message["type"] ?? "file";
    final isText = type == "text" || type == null;

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(_tapPosition.dx, _tapPosition.dy - 40, 0, 0),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      elevation: 6,
      constraints: const BoxConstraints(minWidth: 220),
      items: [
        _menuItem("info", "Message info", Icons.info_outline),
        _menuItem("reply", "Reply", Icons.reply),
        _menuItem("copy", "Copy", Icons.copy),
        // _menuItem("react", "React", Icons.emoji_emotions_outlined),
        _menuItem("download", "Download", Icons.download),
        _menuItem("forward", "Forward", Icons.forward),
        // _menuItem("pin", "Pin", Icons.push_pin),
        // _menuItem("star", "Star", Icons.star_border),
        const PopupMenuDivider(height: 0, color: Colors.black12),
        _menuItem("delete", "Delete", Icons.delete, isDestructive: true),
      ],
    );

    // 🔹 Actions
    switch (value) {
      case "info":
        _showMessageInfo(context);
        break;
      case "reply":
        onReply?.call(message, id);
        break;
      case "copy":
        if (isText && message["text"] != null) {
          final text = chatService.decryptTextSafe(message["text"]);
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Copied to clipboard")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("⚠️ Copy not available for this type")),
          );
        }
        break;
      case "react":
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("😊 React feature coming soon...")),
        );
        break;
      case "download":
        if (url != null) {
          await _saveMedia(context, url, fileName, type);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⚠️ No file to download")),
          );
        }
        break;
      case "forward":
        onForward?.call(message);
        break;
      case "pin":
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("📌 Pin feature coming soon...")),
        );
        break;
      case "star":
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⭐ Star feature coming soon...")),
        );
        break;
      case "delete":
        _showDeleteDialog(context);
        break;
    }
  }

  /// 🔹 Helper for consistent style
  PopupMenuItem<String> _menuItem(String value,
      String label,
      IconData icon, {
        bool isDestructive = false,
      }) {
    return PopupMenuItem(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDestructive ? Colors.red : Colors.black87,
            ),
          ),
          Icon(
            icon,
            size: 20,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final isMine = message["senderId"] == currentUid;

    showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text("Delete message?"),
            content: const Text("Do you want to delete this message?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel", style: TextStyle(color: Colors.blueAccent)
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete(id); // delete only for me
                },
                child: const Text(
                  "Delete for me", style: TextStyle(color: Colors.blueAccent)),
              ),
              if (isMine)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // ✅ call delete for everyone in your service
                    chatService.deleteMessage(id, forBoth: true);
                  },
                  child: const Text(
                    "Delete for everyone",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
    );
  }

  void _showMessageInfo(BuildContext context) {
    final createdAt = (message['createdAt'] as dynamic)?.toDate();
    final deliveredBy = Map<String, dynamic>.from(message['deliveredBy'] ?? {});
    final readBy = Map<String, dynamic>.from(message['readBy'] ?? {});

    String _formatTS(DateTime? t) {
      if (t == null) return "—";
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      if (t.day == now.day && t.month == now.month && t.year == now.year) {
        return "Today at ${DateFormat('h:mm a').format(t)}";
      } else if (t.day == yesterday.day &&
          t.month == yesterday.month &&
          t.year == yesterday.year) {
        return "Yesterday at ${DateFormat('h:mm a').format(t)}";
      } else {
        return DateFormat("d/M/yyyy 'at' h:mm a").format(t);
      }
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280), // 🔹 smaller popup
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Message Info",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 20, color: Colors.blueAccent),

                // ✅ Read
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.done_all, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Read",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(
                            readBy.isEmpty
                                ? "Not read yet"
                                : _formatTS((readBy.values.first as Timestamp?)?.toDate()),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ✅ Delivered
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.done_all, color: Colors.grey, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Delivered",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(
                            deliveredBy.isEmpty
                                ? "Not delivered yet"
                                : _formatTS((deliveredBy.values.first as Timestamp?)?.toDate()),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CLOSE",
                        style: TextStyle(fontWeight: FontWeight.bold,color: Colors.blueAccent)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isMe = message['senderId'] == currentUid;
    final createdAt = (message['createdAt'] as dynamic)?.toDate();
    final type = message['type'] ?? 'text';
    final readBy = Map<String, dynamic>.from(message['readBy'] ?? {});
    final deliveredBy = Map<String, dynamic>.from(message['deliveredBy'] ?? {});
    final replyTo = message["replyTo"];

    // ✅ Deleted placeholder (always keep in timeline)
    if (message["deletedFor"]?[currentUid] == true ||
        message["deletedForEveryone"] == true ||
        type == "deleted") {
      // tick icons
      IconData tick = Icons.check;
      Color tickColor = Colors.white70;
      if (readBy[otherUserId] == true) {
        tick = Icons.done_all;
        tickColor = Colors.lightBlueAccent;
      } else if (deliveredBy[otherUserId] == true) {
        tick = Icons.done_all;
      }

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade600,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              const Text(
                "This message was deleted",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              if (createdAt != null)
                Text(
                  "${createdAt.hour}:${createdAt.minute.toString().padLeft(
                      2, '0')}",
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(tick, size: 14, color: tickColor),
              ],
            ],
          ),
        ),
      );
    }

    // ✅ Ticks
    IconData tick = Icons.check;
    Color tickColor = Colors.white70;
    if (readBy[otherUserId] == true) {
      tick = Icons.done_all;
      tickColor = Colors.lightBlueAccent;
    } else if (deliveredBy[otherUserId] == true) {
      tick = Icons.done_all;
    }

    // ✅ Content builder
    Widget content;
    switch (type) {
      case 'image':
        final fileUrl = message['fileUrl'] ?? "";
        final uploading = message['uploading'] == true;
        final progress = (message['progress'] as double?) ?? 0.0;

        content = GestureDetector(
          onTap: () {
            if (fileUrl.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaPreviewPage(
                    url: fileUrl,
                    type: "image",
                    fileName: message['fileName'] ?? "image.jpg",
                  ),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF001E60), width: 5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (fileUrl.isEmpty)
                    Container(
                      width: 220,
                      height: 180,
                      color: Colors.black26,
                      child: const Icon(Icons.image, color: Colors.white70, size: 40),
                    )
                  else
                    Image.network(fileUrl,
                        width: 220, height: 180, fit: BoxFit.cover),

                  if (uploading)
                    Container(
                      width: 220,
                      height: 180,
                      color: Colors.black45,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(value: progress > 0 ? progress : null),
                          const SizedBox(height: 8),
                          Text("${(progress * 100).toStringAsFixed(0)}%",
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        break;

      case 'video':
        final fileUrl = message['fileUrl'] ?? "";
        final uploading = message['uploading'] == true;
        final progress = (message['progress'] as double?) ?? 0.0;

        content = GestureDetector(
          onTap: () {
            if (fileUrl.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaPreviewPage(
                    url: fileUrl,
                    type: "video",
                    fileName: message['fileName'] ?? "video.mp4",
                  ),
                ),
              );
            }
          },
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black26, width: 0.6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    color: Colors.black26,
                    child: fileUrl.isEmpty
                        ? const Icon(Icons.videocam, color: Colors.white70, size: 40)
                        : const Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 64),
                  ),
                  if (uploading)
                    Container(
                      color: Colors.black54,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(value: progress > 0 ? progress : null),
                          const SizedBox(height: 8),
                          Text("${(progress * 100).toStringAsFixed(0)}%",
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        break;

      case 'file':
        final fileUrl = message['fileUrl'] ?? "";
        final uploading = message['uploading'] == true;
        final progress = (message['progress'] as double?) ?? 0.0;

        content = GestureDetector(
          onTap: () {
            if (fileUrl.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaPreviewPage(
                    url: fileUrl,
                    type: "file",
                    fileName: message['fileName'] ?? "document",
                  ),
                ),
              );
            }
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black26, width: 0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message['fileName'] ?? "Document",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (uploading)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: progress > 0 ? progress : null,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        break;

      default:
        final plain = chatService.decryptTextSafe(message['text']);
        content = GestureDetector(
          onTap: () => selectionMode ? onTap() : null,
          onTapDown: _storePosition,
          onLongPress: () {
            selectionMode ? onTap() : _showContextMenu(context);
          },
          child: Text(
            plain,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        );
    }

    // Bubble wrapper
    return GestureDetector(
      onTapDown: _storePosition,
      onTap: () => selectionMode ? onTap() : null,
      onLongPress: () {
        selectionMode ? onTap() : _showContextMenu(context);
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: type == "text" // 🔹 only text has bubble
            ? Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue : Colors.grey.shade600,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(18),
            ),
            border: isSelected
                ? Border.all(color: Colors.lightBlueAccent, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              content,
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (createdAt != null)
                    Text(
                      "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(tick, size: 14, color: tickColor),
                  ],
                ],
              ),
            ],
          ),
        )
            : Container( // 🔹 Media = NO fat outer bubble
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              content, // image/video/file directly shown
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (createdAt != null)
                    Text(
                      "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(color: Colors.black54, fontSize: 11),
                    ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(tick, size: 14, color: Colors.lightBlueAccent),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
