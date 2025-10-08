import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;

import '../auth/auth_wrapper.dart';
import '../chat/chat_page.dart';
import '../chat/encryption_helper.dart';
import '../widgets/profile_avatar.dart';
import '../connections/search_invite.dart';
import '../notifications/notifications_page.dart';

class SeeAllConnections extends StatefulWidget {
  final String userRole;
  const SeeAllConnections({super.key, required this.userRole});

  @override
  State<SeeAllConnections> createState() => _SeeAllConnectionsState();
}

class _SeeAllConnectionsState extends State<SeeAllConnections> {
  final currentUid = FirebaseAuth.instance.currentUser!.uid;

  String _searchQuery = "";
  bool _sortNewestFirst = true;

  // Custom colors from the generated image for a modern gradient look
  static const Color _gradientStartColor = Color(0xFF19B2A9); // Teal-Cyan
  static const Color _gradientEndColor = Color(0xFFF09A4D);   // Orange-Peach
  static const Color _iconColor = Color(0xFFFFFFFF);
  static const Color _primaryTextColor = Color(0xFF2C3E50); // Dark text for contrast

  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    var doc =
    await FirebaseFirestore.instance.collection("users").doc(uid).get();
    if (doc.exists) return doc.data();
    return null;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      return "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
    } else if (now.difference(time).inDays == 1) {
      return "Yesterday";
    } else {
      return "${time.day}/${time.month}/${time.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold background color matching the light area of the gradient bleed
    return Scaffold(
      backgroundColor: const Color(0xFFE0F7FA), // Very light background
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130), // Adjusted height
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              // Using the custom gradient colors
              colors: [_gradientStartColor, _gradientEndColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            // Subtle curve at the bottom
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Title + Actions Row
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Chat",
                        style: TextStyle(
                          color: _iconColor,
                          fontSize: 24, // Slightly larger title
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          // 🔍 Search Button → Search Tab via AuthWrapper - Removed for new search bar design
                          // However, I will keep the original logic to navigate to the search tab
                          IconButton(
                            icon: const Icon(Icons.search, color: _iconColor),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const AuthWrapper(initialIndex: 1), // Navigate to Search tab (index 1)
                                ),
                              );
                            },
                          ),

                          // 🔔 Notifications
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection("notifications")
                                .where("userId", isEqualTo: currentUid)
                                .where("read", isEqualTo: false)
                                .snapshots(),
                            builder: (context, snapshot) {
                              int unreadCount =
                              snapshot.hasData ? snapshot.data!.docs.length : 0;

                              return IconButton(
                                icon: badges.Badge(
                                  position: badges.BadgePosition.topEnd(top: 0, end: 0),
                                  showBadge: unreadCount > 0,
                                  badgeContent: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                  child: const Icon(Icons.notifications_none, color: _iconColor),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const NotificationsPage(),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                // 🔍 Floating Search / Filter Bar (Overlapping the gradient and body)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: "Search connections...",
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (val) {
                              setState(() => _searchQuery = val.toLowerCase());
                            },
                          ),
                        ),
                        // Filter Icon matching the new color scheme
                        IconButton(
                          icon: Icon(
                            _sortNewestFirst
                                ? Icons.filter_list_rounded
                                : Icons.sort,
                            color: _gradientEndColor, // Use the accent color for the icon
                          ),
                          onPressed: () {
                            setState(() => _sortNewestFirst = !_sortNewestFirst);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10), // Spacing below the search bar
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("connections")
            .where(Filter.or(
          Filter("userA", isEqualTo: currentUid),
          Filter("userB", isEqualTo: currentUid),
        ))
            .where("status", isEqualTo: "Connected")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final Map<String, QueryDocumentSnapshot> uniqueConnections = {};
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data["status"] != "Connected") continue;
            String otherUserId =
            (data["userA"] == currentUid) ? data["userB"] : data["userA"];
            uniqueConnections[otherUserId] = doc;
          }

          final connections = uniqueConnections.values.toList();
          if (connections.isEmpty) {
            return const Center(
              child: Text(
                "No connected users yet 🙌",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          connections.sort((a, b) {
            var aTime =
                (a["createdAt"] as Timestamp?)?.toDate() ?? DateTime(2000);
            var bTime =
                (b["createdAt"] as Timestamp?)?.toDate() ?? DateTime(2000);
            return _sortNewestFirst
                ? bTime.compareTo(aTime)
                : aTime.compareTo(bTime);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: connections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              var conn = connections[index];
              var data = conn.data() as Map<String, dynamic>;
              String otherUserId =
              (data["userA"] == currentUid) ? data["userB"] : data["userA"];

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getUserData(otherUserId),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const SizedBox();
                  }

                  var userData = userSnap.data!;
                  String name = userData["name"] ?? "Unknown";

                  if (_searchQuery.isNotEmpty &&
                      !name.toLowerCase().contains(_searchQuery)) {
                    return const SizedBox.shrink();
                  }

                  // ChatId based on sorted UIDs
                  final ids = [currentUid, otherUserId]..sort();
                  final chatId = "${ids[0]}_${ids[1]}";

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            otherUserId: otherUserId,
                            otherUserName: name,
                            otherUserPic: userData["profilePic"],
                          ),
                        ),
                      );
                    },
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("chats")
                          .doc(chatId)
                          .snapshots(),
                      builder: (context, chatSnap) {
                        // Check for unread status to apply gradient to the tile
                        bool isUnread = false;
                        if (chatSnap.hasData && chatSnap.data!.exists) {
                          final data = chatSnap.data!.data() as Map<String, dynamic>?;
                          final lastMsg = data?["lastMessage"] != null
                              ? Map<String, dynamic>.from(data!["lastMessage"])
                              : null;

                          isUnread = lastMsg != null &&
                              lastMsg["senderId"] != currentUid &&
                              !(lastMsg["readBy"]?[currentUid] ?? false);
                        }

                        // Custom BoxDecoration for the chat tile
                        final BoxDecoration decoration = BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isUnread
                              ? Border.all(color: _gradientEndColor.withOpacity(0.8), width: 2) // New message border
                              : null,
                          gradient: isUnread
                              ? LinearGradient(
                            colors: [
                              _gradientEndColor.withOpacity(0.1), // Subtle background gradient for "New"
                              Colors.white,
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        );

                        // Last Message Logic
                        String lastMessageText = "No messages yet";
                        DateTime? lastMessageTime;
                        if (chatSnap.hasData && chatSnap.data!.exists) {
                          final data = chatSnap.data!.data() as Map<String, dynamic>?;
                          if (data != null && data["lastMessage"] != null) {
                            final lastMsg = Map<String, dynamic>.from(data["lastMessage"]);
                            final senderId = lastMsg["senderId"];
                            lastMessageTime = (lastMsg["createdAt"] as Timestamp?)?.toDate();

                            String msgText = "";
                            if (lastMsg["type"] == null || lastMsg["type"] == "text") {
                              try {
                                final helper = EncryptionHelper(chatId);
                                msgText = helper.decryptText(lastMsg["text"]);
                              } catch (_) {
                                msgText = "[Message]";
                              }
                            } else if (lastMsg["type"] == "image") {
                              msgText = "📷 Photo";
                            } else if (lastMsg["type"] == "video") {
                              msgText = "🎥 Video";
                            } else if (lastMsg["type"] == "file") {
                              msgText = "📎 ${lastMsg["fileName"] ?? "File"}";
                            } else {
                              msgText = "[${lastMsg["type"]}]";
                            }
                            lastMessageText = senderId == currentUid ? "You: $msgText" : msgText;
                          }
                        }

                        // Time and Unread Badge Logic
                        Widget timeAndUnreadBadge;
                        if (lastMessageTime != null) {
                          timeAndUnreadBadge = Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(lastMessageTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isUnread ? _gradientEndColor : Colors.grey.shade600,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (isUnread)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _gradientEndColor, // Use the accent color for the badge
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    "New",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        } else {
                          timeAndUnreadBadge = const SizedBox();
                        }


                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: decoration,
                          child: Row(
                            children: [
                              // 🌟 FIX APPLIED HERE: Manual Border for ProfileAvatar
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: isUnread
                                      ? Border.all(
                                    color: _gradientEndColor.withOpacity(0.8),
                                    width: 2,
                                  )
                                      : null,
                                ),
                                child: ProfileAvatar(
                                  imageUrlOrPath: userData["profilePic"],
                                  radius: 26,
                                ),
                              ),
                              // ----------------------------------------------
                              const SizedBox(width: 12),

                              // Name + Last Message
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: _primaryTextColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),

                                    // Last Message Text
                                    Text(
                                      lastMessageText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isUnread ? _primaryTextColor.withOpacity(0.8) : Colors.grey.shade600,
                                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Time + Unread badge
                              timeAndUnreadBadge,
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}