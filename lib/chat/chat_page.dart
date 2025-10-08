import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:gallery_saver_plus/gallery_saver.dart';

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

  // Selection
  Set<String> _selectedMsgIds = {};
  bool _selectionMode = false;

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

  Future<void> _saveMediaHelper(String url, String fileName, String type) async {
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
          m['fileName'] ?? "file_${DateTime.now().millisecondsSinceEpoch}";
      final type = m['type'] ?? 'file';

      if (url != null) {
        await _saveMediaHelper(url, fileName, type);
      }
    }

    _clearSelection();
  }

  Map<String, dynamic>? _replyingTo;

  void _setReply(Map<String, dynamic> message, String msgId) {
    setState(() {
      _replyingTo = {...message, "id": msgId};
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _forwardMessage(Map<String, dynamic> message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForwardPage(
          message: message,
          chatService: _chatService,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(widget.otherUserId);
    _chatService.ensureChat();
    _chatService.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
          if (_showEmoji) _buildEmojiPicker(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      titleSpacing: 0,
      title: _selectionMode
          ? Text("${_selectedMsgIds.length} selected",
          style: const TextStyle(color: Colors.black))
          : Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: (widget.otherUserPic != null &&
                widget.otherUserPic!.startsWith("http"))
                ? NetworkImage(widget.otherUserPic!)
                : null,
            child: (widget.otherUserPic == null ||
                !widget.otherUserPic!.startsWith("http"))
                ? Text(
              widget.otherUserName.isNotEmpty
                  ? widget.otherUserName[0].toUpperCase()
                  : "?",
              style: const TextStyle(fontWeight: FontWeight.bold),
            )
                : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.otherUserName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black)),
              const Text("online",
                  style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ),
        ],
      ),
      actions: _selectionMode
          ? [
        IconButton(
          icon: const Icon(Icons.download, color: Colors.blue),
          onPressed: _downloadSelected,
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: _deleteSelected,
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: _clearSelection,
        ),
      ]
          : [
        // IconButton(
        //     onPressed: () {},
        //     icon: const Icon(Icons.call, color: Colors.blue)),
        // IconButton(
        //     onPressed: () {},
        //     icon: const Icon(Icons.videocam, color: Colors.blue)),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.black87),
          onSelected: (value) {
            if (value == "select") {
              setState(() {
                _selectionMode = true;
              });
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: "select",
              child: Text("Select"),
            ),
          ],
        ),
      ],
    );
  }

  int _lastMessageCount = 0;
  bool _initialScrolled = false;

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _chatService.messagesStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
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

        return ListView.builder(
          controller: _chatService.scrollController,
          padding: const EdgeInsets.all(12),
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
                if (_selectionMode) {
                  _toggleSelection(msgId);
                }
              },
              onLongPress: () {
                if (_selectionMode) {
                  _toggleSelection(msgId);
                } else {
                  // rely on MessageBubble context menu
                }
              },
              onReply: _setReply,
              onForward: _forwardMessage,
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(width: 4, height: 40, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _replyingTo!["senderId"] ==
                                _chatService.currentUid
                                ? "You"
                                : widget.otherUserName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                          Text(
                            _replyingTo!["text"] != null
                                ? _chatService
                                .decryptTextSafe(_replyingTo!["text"])
                                : "[${_replyingTo!["type"]}]",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _cancelReply,
                    ),
                  ],
                ),
              ),
            const Divider(height: 1, color: Colors.black12),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined,
                        color: Colors.grey),
                    onPressed: () =>
                        setState(() => _showEmoji = !_showEmoji),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: () =>
                        _chatService.openAttachmentSheet(context),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _chatService.textController,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          hintText: "Type a message",
                          hintStyle: TextStyle(color: Colors.black54),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _chatService
                            .sendText(replyTo: _replyingTo)
                            .then((_) => _cancelReply()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        _chatService.textController.text.trim().isEmpty
                            ? Icons.mic
                            : Icons.send,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_chatService.textController.text.trim().isEmpty) {
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
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return SizedBox(
      height: 250,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          _chatService.textController.text += emoji.emoji;
        },
        config: const ep.Config(),
      ),
    );
  }
}
