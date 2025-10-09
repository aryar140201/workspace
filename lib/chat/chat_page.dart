import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:freelenia/chat/widgets/safe_network_image.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'chat_service.dart';
import 'forward_page.dart';
import 'widgets/message_bubble.dart';

class ChatPage extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPic;

  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPic,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatService _chatService;
  bool _showEmoji = false;

  // ✅ Connectivity flag
  bool _isOffline = false;

  // Message selection
  Set<String> _selectedMsgIds = {};
  bool _selectionMode = false;

  // Reply state
  Map<String, dynamic>? _replyingTo;

  int _lastMessageCount = 0;
  bool _initialScrolled = false;

// Define a primary color and a light background for a modern look
  static const Color primaryColor = Color(
      0xFF007AFF); // A vibrant, standard blue
  static const Color chatBackgroundColor = Color(
      0xFFF0F0F0); // Custom light gray
  static const Color inputBarColor = Colors.white;

  // ------------------------------ INIT ------------------------------
  @override
  void initState() {
    super.initState();
    _chatService = ChatService(widget.otherUserId);
    _chatService.ensureChat();
    _chatService.markAllRead();

    // ✅ Listen to connectivity
    Connectivity().onConnectivityChanged.listen((status) {
      setState(() {
        _isOffline = (status == ConnectivityResult.none);
      });
    });
  }

  // ------------------------------ SELECTION ------------------------------
  void _toggleSelection(String msgId) {
    setState(() {
      if (_selectedMsgIds.contains(msgId)) {
        _selectedMsgIds.remove(msgId);
        if (_selectedMsgIds.isEmpty) _selectionMode = false;
      } else {
        _selectedMsgIds.add(msgId);
        _selectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMsgIds.clear();
      _selectionMode = false;
    });
  }

  void _deleteSelected() async {
    if (_selectedMsgIds.isEmpty) return;
    for (final id in _selectedMsgIds) {
      await _chatService.deleteMessage(id, forBoth: true);
    }
    _clearSelection();
  }

  // ------------------------------ MEDIA SAVE ------------------------------
  Future<void> _saveMediaHelper(String url, String fileName,
      String type) async {
    bool? success;
    try {
      if (type == "image") {
        success = await GallerySaver.saveImage(url, albumName: "MyApp");
      } else if (type == "video") {
        success = await GallerySaver.saveVideo(url, albumName: "MyApp");
      } else {
        final dir = Directory("/storage/emulated/0/Download");
        if (!await dir.exists()) await dir.create(recursive: true);
        final savePath = "${dir.path}/$fileName";
        final dio = Dio();
        final response = await dio.download(url, savePath);
        if (response.statusCode == 200) success = true;
      }

      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Saved successfully: $fileName")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save file")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _downloadSelected() async {
    if (_selectedMsgIds.isEmpty) return;
    for (final id in _selectedMsgIds) {
      final doc = await _chatService.msgsCol.doc(id).get();
      if (!doc.exists) continue;
      final m = doc.data()!;
      final url = m['fileUrl'];
      final fileName =
          m['fileName'] ?? "file_${DateTime
              .now()
              .millisecondsSinceEpoch}";
      final type = m['type'] ?? 'file';
      if (url != null) await _saveMediaHelper(url, fileName, type);
    }
    _clearSelection();
  }

  // ------------------------------ REPLY / FORWARD ------------------------------
  void _setReply(Map<String, dynamic> message, String msgId) {
    setState(() {
      _replyingTo = {...message, "id": msgId};
    });
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _forwardMessage(Map<String, dynamic> message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ForwardPage(
              message: message,
              chatService: _chatService,
            ),
      ),
    );
  }

  // ------------------------------ BUILD ------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use the custom light gray background
      backgroundColor: chatBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isOffline) _buildOfflineBanner(), // Dedicated banner widget
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
          if (_showEmoji) _buildEmojiPicker(),
        ],
      ),
    );
  }

  // ------------------------------ APP BAR ------------------------------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      // Use a subtle elevation for definition
      elevation: 2,
      shadowColor: Colors.black12,
      backgroundColor: inputBarColor,
      // Match input bar for consistency
      titleSpacing: 0,
      iconTheme: const IconThemeData(color: primaryColor),

      title: _selectionMode
          ? Text("${_selectedMsgIds.length} selected",
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold))
          : Row(
        children: [
          // Enhanced Avatar styling
          CircleAvatar(
            radius: 20,
            backgroundColor: primaryColor.withOpacity(0.1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: (widget.otherUserPic != null &&
                  widget.otherUserPic!.isNotEmpty &&
                  widget.otherUserPic!.startsWith("http"))
                  ? SafeNetworkImage(
                imageUrl: widget.otherUserPic,
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(20),
              )
                  : Center(
                child: Text(
                  widget.otherUserName.isNotEmpty
                      ? widget.otherUserName[0].toUpperCase()
                      : "?",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18, // Slightly larger
                    color: primaryColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.otherUserName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, // Medium-bold
                      color: Colors.black87,
                      fontSize: 16)),
              const Text("Active Now", // Slightly better status text
                  style: TextStyle(color: Colors.green, fontSize: 11)),
            ],
          ),
        ],
      ),
      actions: _selectionMode
          ? [
        // Use a more neutral color for selection mode icons
        IconButton(
          icon: const Icon(Icons.download_rounded, color: primaryColor),
          onPressed: _downloadSelected,
        ),
        IconButton(
          icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
          onPressed: _deleteSelected,
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: _clearSelection,
        ),
      ]
          : [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.black54),
          onSelected: (value) {
            if (value == "select") {
              setState(() => _selectionMode = true);
            }
          },
          itemBuilder: (_) =>
          const [
            PopupMenuItem(
                value: "select", child: Text("Select Messages")),
          ],
        ),
      ],
    );
  }

// ------------------------------ OFFLINE BANNER ------------------------------
  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      // Use a more noticeable, yet pleasing, warning color
      color: const Color(0xFFFFCC00).withOpacity(0.2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: const Text(
        "⚠️ Offline — messages will sync when back online",
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Color(0xFFCC7A00), // Darker orange/brown for contrast
            fontWeight: FontWeight.w500,
            fontSize: 13),
      ),
    );
  }

  // ------------------------------ MESSAGE LIST (Offline-Aware) ------------------------------
  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _chatService.msgsCol
          .orderBy("createdAt", descending: false)
          .snapshots(includeMetadataChanges: true),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        final bool fromCache = snap.data!.metadata.isFromCache;

        _chatService.markDelivered(docs);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatService.scrollController.hasClients) {
            final pos = _chatService.scrollController.position;
            if (!_initialScrolled && docs.isNotEmpty) {
              _chatService.scrollController.jumpTo(pos.maxScrollExtent);
              _initialScrolled = true;
            }
            if (docs.length > _lastMessageCount) {
              _chatService.scrollController.animateTo(
                pos.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          }
        });
        _lastMessageCount = docs.length;

        if (docs.isEmpty) {
          return Center(
            child: Text(
              fromCache
                  ? "No cached messages available."
                  : "Start chatting 👋",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }


        return ListView.builder(
          controller: _chatService.scrollController,
          padding: const EdgeInsets.only(
              left: 10, right: 10, top: 10, bottom: 4),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final msgId = doc.id;
            final m = doc.data();

            if (m["deletedFor"]?[_chatService.currentUid] == true) {
              return const SizedBox.shrink();
            }

            return MessageBubble(
              id: msgId,
              message: m,
              currentUid: _chatService.currentUid,
              otherUserId: widget.otherUserId,
              chatService: _chatService,
              onDelete: (id) => _chatService.deleteMessage(id),
              isSelected: _selectedMsgIds.contains(msgId),
              selectionMode: _selectionMode,
              onTap: () {
                if (_selectionMode) _toggleSelection(msgId);
              },
              onLongPress: () {
                if (!_selectionMode) {
                  _toggleSelection(msgId);
                }
              },
              onReply: _setReply,
              onForward: _forwardMessage,
              // REMOVED: primaryColor: primaryColor, (since it's not defined in your MessageBubble)
            );
          },
        );
      },
    );
  }

  // ------------------------------ INPUT BAR ------------------------------
  Widget _buildInputBar() {
    // Define a new color for the buttons to match the image (a light teal/cyan)
    const Color buttonColor = Color(0xFF4DD0E1);
    // Define the background color for the entire bottom area
    const Color fullBackgroundColor = Colors.white;

    return Container(
      // Set the white color for the entire bottom bar area
      color: fullBackgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ADDED SPACE ABOVE THE INPUT BAR
            const SizedBox(height: 8),

            // Reply Bar (Remains the same)
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                  const Border(left: BorderSide(color: primaryColor, width: 3)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _replyingTo!["senderId"] == _chatService.currentUid
                                ? "Replying to You"
                                : "Replying to ${widget.otherUserName}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _replyingTo!["text"] != null
                                ? _chatService.decryptTextSafe(
                                _replyingTo!["text"])
                                : "[${_replyingTo!["type"]}]",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                            const TextStyle(color: Colors.black54,
                                fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 20, color: Colors.black54),
                      onPressed: _cancelReply,
                    ),
                  ],
                ),
              ),

            // Input Row matching the first image
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Container(
                // This container forms the large, rounded capsule background
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [ // Add a subtle shadow for depth
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // --- 1. Emoji Button (Leftmost) ---
                    _buildIconButton(
                      icon: _showEmoji ? Icons.keyboard_rounded : Icons
                          .sentiment_satisfied_rounded,
                      color: buttonColor,
                      onPressed: () =>
                          setState(() {
                            _showEmoji = !_showEmoji;
                            if (_showEmoji) FocusScope.of(context).unfocus();
                          }),
                    ),

                    // --- 2. Plus/Attachment Button ---
                    _buildIconButton(
                      icon: Icons.add_rounded,
                      color: buttonColor,
                      onPressed: () =>
                          _chatService.openAttachmentSheet(context),
                    ),

                    // --- 3. Text Input Field (Expanded Middle) ---
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _chatService.textController,
                          style: const TextStyle(color: Colors.black,
                              fontSize: 16),
                          maxLines: 5,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: "Start typing...",
                            hintStyle: TextStyle(
                                color: Colors.black45, fontSize: 16),
                            border: InputBorder.none,
                            isCollapsed: true,
                            // Crucial for tight vertical fit
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) {
                            if (_chatService.textController.text
                                .trim()
                                .isNotEmpty) {
                              _chatService
                                  .sendText(replyTo: _replyingTo)
                                  .then((_) => _cancelReply());
                            }
                          },
                        ),
                      ),
                    ),

                    // --- 4. Send/Mic Button (Rightmost) ---
                    // This button needs to dynamically change, and the image uses a distinct button.
                    _buildIconButton(
                      // Send icon when typing, Mic icon otherwise (based on your existing logic)
                      icon: _chatService.textController.text
                          .trim()
                          .isEmpty
                          ? Icons.mic_rounded
                          : Icons.send_rounded,
                      color: buttonColor,
                      onPressed: () {
                        if (_chatService.textController.text
                            .trim()
                            .isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("🎤 Voice note feature WIP")),
                          );
                        } else {
                          _chatService
                              .sendText(replyTo: _replyingTo)
                              .then((_) => _cancelReply());
                        }
                      },
                      // Send button needs a solid background circle as per the image
                      isSolid: true,
                      backgroundColor: buttonColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- New Helper Widget for the specific button style ---
  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isSolid = false,
    Color? backgroundColor,
  }) {
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: isSolid
          ? BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      )
          : null,
      // No background for non-solid buttons
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          color: isSolid ? Colors.white : color,
          size: isSolid ? 22 : 28, // Slightly larger for the emoji/plus icons
        ),
        onPressed: onPressed,
      ),
    );
  }

  // ------------------------------ EMOJI PICKER (Fully Compatible with v1.x / v2.0.x) ------------------------------
  Widget _buildEmojiPicker() {
    return Container(
      height: 250,
      padding: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 0,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: EmojiPicker(
        onEmojiSelected: (Category? category, Emoji? emoji) {
          if (emoji != null && emoji.emoji != null) {
            _chatService.textController.text += emoji.emoji!;
          }
        },
      ),
    );
  }

}
