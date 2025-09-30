import 'package:flutter/material.dart';
import '../chat_service.dart';

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

  const MessageBubble({
    super.key,
    required this.id,
    required this.message,
    required this.currentUid,
    required this.otherUserId,
    required this.onDelete,
    required this.chatService,
    this.isSelected = false,
    this.selectionMode = false,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 🔹 Hide if deleted for this user only
    if (message["deletedFor"]?[currentUid] == true) {
      return const SizedBox.shrink();
    }

    final isMe = message['senderId'] == currentUid;
    final createdAt = (message['createdAt'] as dynamic)?.toDate();
    final type = message['type'] ?? 'text';
    final readBy = Map<String, dynamic>.from(message['readBy'] ?? {});
    final deliveredBy = Map<String, dynamic>.from(message['deliveredBy'] ?? {});
    final replyTo = message["replyTo"];

    // ✅ If deleted for everyone, show placeholder
    if (type == "deleted" || message["deletedForEveryone"] == true) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade500,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "This message was deleted",
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.white,
            ),
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

    // ✅ Normal content
    Widget content;
    switch (type) {
      case 'image':
        content = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message['fileUrl'],
            width: 220,
            height: 220,
            fit: BoxFit.cover,
          ),
        );
        break;
      default:
        final plain = chatService.decryptTextSafe(message['text']);
        content = Text(
          plain,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        );
    }

    // ✅ Bubble
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
            border: isSelected
                ? Border.all(color: Colors.lightBlueAccent, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // 🔹 Reply preview
              if (replyTo != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        replyTo["senderId"] == currentUid
                            ? "You"
                            : otherUserId,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      if (replyTo["text"] != null)
                        Text(
                          chatService.decryptTextSafe(replyTo["text"]),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          "[${replyTo["type"]}]",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),

              // 🔹 Main message content
              content,

              const SizedBox(height: 4),

              // 🔹 Time + ticks
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (createdAt != null)
                    Text(
                      "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                    ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(tick, size: 14, color: tickColor),
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
