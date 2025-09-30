import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:flutter/services.dart';

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
  void _showDeleteOptions(String msgId) async {
    final doc = await _chatService.msgsCol.doc(msgId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final isMine = data["senderId"] == _chatService.currentUid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("Delete for me"),
              onTap: () async {
                Navigator.pop(context);
                await _chatService.deleteMessage(msgId, forBoth: false);
              },
            ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Delete for everyone"),
                onTap: () async {
                  Navigator.pop(context);
                  await _chatService.deleteMessage(msgId, forBoth: true);
                },
              ),
          ],
        ),
      ),
    );
  }
  void _showMessageOptions(String msgId) async {
    final doc = await _chatService.msgsCol.doc(msgId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final isMine = data["senderId"] == _chatService.currentUid;
    final isText = data["type"] == null || data["type"] == "text";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (isText)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text("Copy"),
                onTap: () {
                  Navigator.pop(context);
                  final text = _chatService.decryptTextSafe(data["text"]);
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Copied to clipboard")),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text("Reply"),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement reply UI → set reply state
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text("Forward"),
              onTap: () {
                Navigator.pop(context);
                _forwardMessage(data);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("Delete for me"),
              onTap: () async {
                Navigator.pop(context);
                await _chatService.deleteMessage(msgId, forBoth: false);
              },
            ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Delete for everyone"),
                onTap: () async {
                  Navigator.pop(context);
                  await _chatService.deleteMessage(msgId, forBoth: true);
                },
              ),
          ],
        ),
      ),
    );
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
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: _deleteSelected,
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: _clearSelection,
        ),
      ]
          : [
        IconButton(
            onPressed: () {},
            icon: const Icon(Icons.call, color: Colors.blue)),
        IconButton(
            onPressed: () {},
            icon: const Icon(Icons.videocam, color: Colors.blue)),
        IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: Colors.black87)),
      ],
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _chatService.messagesStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        _chatService.markDelivered(docs);

        return ListView.builder(
          controller: _chatService.scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final msgId = docs[i].id;
            final m = docs[i].data();

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
                _showMessageOptions(msgId);
              },
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
        color: Colors.white, // ✅ whole bottom is white
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔹 Reply preview (if replying)
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            _replyingTo!["senderId"] == _chatService.currentUid
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

            // 🔹 Divider line
            const Divider(height: 1, color: Colors.black12),

            // 🔹 Main bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  // Emoji button
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined,
                        color: Colors.grey),
                    onPressed: () => setState(() => _showEmoji = !_showEmoji),
                  ),

                  // Attachments
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: () => _chatService.openAttachmentSheet(context),
                  ),

                  // Input box
                  Expanded(
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

                  // Send / Mic button
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
