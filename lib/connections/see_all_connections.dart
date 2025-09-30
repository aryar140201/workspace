import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;

import '../auth/auth_wrapper.dart';
import '../chat/chat_page.dart';
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
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: SafeArea(
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
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          // 🔍 Search Button → Search Tab via AuthWrapper
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const AuthWrapper(initialIndex: 1),
                                ),
                              );
                            },
                          ),

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
                                  position: badges.BadgePosition.topEnd(),
                                  showBadge: unreadCount > 0,
                                  badgeContent: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                  child: const Icon(Icons.notifications_none, color: Colors.white),
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

                // 🔍 Search / Filter Bar
                Container(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Search connections...",
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) {
                            setState(() => _searchQuery = val.toLowerCase());
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _sortNewestFirst
                              ? Icons.filter_alt
                              : Icons.filter_alt_off,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() => _sortNewestFirst = !_sortNewestFirst);
                        },
                      ),
                    ],
                  ),
                ),
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
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ProfileAvatar(
                            imageUrlOrPath: userData["profilePic"],
                            radius: 26,
                          ),
                          const SizedBox(width: 12),

                          // Name + Last Message
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),

                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection("chats")
                                      .doc(chatId)
                                      .snapshots(),
                                  builder: (context, chatSnap) {
                                    if (!chatSnap.hasData ||
                                        !chatSnap.data!.exists) {
                                      return Text(
                                        "No messages yet",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade500,
                                        ),
                                      );
                                    }

                                    final data = chatSnap.data!.data()
                                    as Map<String, dynamic>?;
                                    if (data == null ||
                                        data["lastMessage"] == null) {
                                      return Text(
                                        "No messages yet",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade500,
                                        ),
                                      );
                                    }

                                    final lastMsg =
                                    Map<String, dynamic>.from(
                                        data["lastMessage"]);
                                    final msgText = lastMsg["text"] ?? "";
                                    final senderId = lastMsg["senderId"];

                                    return Text(
                                      senderId == currentUid
                                          ? "You: $msgText"
                                          : msgText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Time + Unread badge
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection("chats")
                                .doc(chatId)
                                .snapshots(),
                            builder: (context, chatSnap) {
                              if (!chatSnap.hasData ||
                                  !chatSnap.data!.exists) {
                                return const SizedBox();
                              }

                              final data = chatSnap.data!.data()
                              as Map<String, dynamic>?;
                              if (data == null ||
                                  data["lastMessage"] == null) {
                                return const SizedBox();
                              }

                              final lastMsg =
                              Map<String, dynamic>.from(data["lastMessage"]);
                              DateTime msgTime =
                                  (lastMsg["createdAt"] as Timestamp?)
                                      ?.toDate() ??
                                      DateTime.now();

                              bool isUnread = lastMsg["senderId"] !=
                                  currentUid &&
                                  !(lastMsg["readBy"]?[currentUid] ?? false);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatTime(msgTime),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (isUnread)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
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
                            },
                          ),
                        ],
                      ),
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
