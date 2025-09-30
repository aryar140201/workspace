import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../connections/invitations_page.dart';
import '../work/works_list_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  String getNotificationGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAfter(today)) {
      return "Today";
    } else if (date.isAfter(yesterday)) {
      return "Yesterday";
    } else if (now.difference(date).inDays <= 7) {
      return "This Week";
    } else {
      return "Older";
    }
  }

  Future<void> _clearAll(String uid) async {
    var snap = await FirebaseFirestore.instance
        .collection("notifications")
        .where("userId", isEqualTo: uid)
        .get();

    for (var doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  /// 🔹 Show Accept/Reject dialog
  void _showAcceptRejectDialog(
      BuildContext context, String notifId, String fromUserId) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Connection Request"),
        content: const Text("Do you want to accept this connection request?"),
        actions: [
          TextButton(
            onPressed: () async {
              var conn = await FirebaseFirestore.instance
                  .collection("connections")
                  .where("userA", isEqualTo: fromUserId)
                  .where("userB", isEqualTo: currentUserId)
                  .where("status", isEqualTo: "Pending")
                  .get();

              for (var doc in conn.docs) {
                await doc.reference.update({"status": "Connected"});
              }

              await FirebaseFirestore.instance
                  .collection("notifications")
                  .doc(notifId)
                  .update({"status": "Accepted"});

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Connection Accepted ✅")),
              );
            },
            child: const Text("Accept"),
          ),
          TextButton(
            onPressed: () async {
              var conn = await FirebaseFirestore.instance
                  .collection("connections")
                  .where("userA", isEqualTo: fromUserId)
                  .where("userB", isEqualTo: currentUserId)
                  .where("status", isEqualTo: "Pending")
                  .get();

              for (var doc in conn.docs) {
                await doc.reference.update({"status": "Rejected"});
              }

              await FirebaseFirestore.instance
                  .collection("notifications")
                  .doc(notifId)
                  .update({"status": "Rejected"});

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Connection Rejected ❌")),
              );
            },
            child: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  /// 🔹 Navigate for other types
  void _handleTap(
      BuildContext context, String type, String notifId, String? fromUser) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    if (type == "ConnectionRequest") {
      if (fromUser != null) {
        _showAcceptRejectDialog(context, notifId, fromUser);
      }
    } else if (type == "RemoveRequest") {
      final notifDoc = await FirebaseFirestore.instance
          .collection("notifications")
          .doc(notifId)
          .get();

      if (!notifDoc.exists) return;
      final data = notifDoc.data()!;

      final connectionId = data["connectionId"];
      final requestId = data["requestId"];

      if (connectionId == null || requestId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid removal request ❌")),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Remove Connection Request"),
          content: const Text(
              "The other user has requested to remove this connection. Do you agree?"),
          actions: [
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection("removalRequests")
                    .doc(requestId)
                    .update({"status": "rejected"});

                await FirebaseFirestore.instance
                    .collection("notifications")
                    .doc(notifId)
                    .update({"status": "Rejected"});

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Request Rejected")),
                );
              },
              child: const Text("Reject",style: TextStyle(color: Colors.black45)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection("connections")
                    .doc(connectionId)
                    .delete();

                await FirebaseFirestore.instance
                    .collection("removalRequests")
                    .doc(requestId)
                    .update({"status": "accepted"});

                await FirebaseFirestore.instance
                    .collection("notifications")
                    .doc(notifId)
                    .update({"status": "Accepted"});

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Connection Removed")),
                );
              },
              child: const Text("Remove", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else if (type == "InviteAccepted" ||
        type == "InviteRejected" ||
        type == "InviteReceived") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InvitationsPage()),
      );
    } else if (type == "WorkAssigned") {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorksListPage(
              userRole: "Freelancer",
              uid: uid,
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No page linked for $type")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () async {
              await _clearAll(uid);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("All notifications cleared")),
              );
            },
            child:
            const Text("Clear All", style: TextStyle(color: Colors.blueAccent)),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("notifications")
            .where("userId", isEqualTo: uid)
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications yet"));
          }

          var notifs = snapshot.data!.docs;

          // Group notifications
          Map<String, List<QueryDocumentSnapshot>> groupedNotifs = {};
          for (var n in notifs) {
            var data = n.data() as Map<String, dynamic>;
            DateTime date = (data["createdAt"] as Timestamp).toDate();
            String group = getNotificationGroup(date);

            groupedNotifs.putIfAbsent(group, () => []);
            groupedNotifs[group]!.add(n);
          }

          return ListView(
            children: groupedNotifs.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...entry.value.map((n) {
                    var data = n.data() as Map<String, dynamic>;
                    DateTime date = (data["createdAt"] as Timestamp).toDate();
                    String formattedDate =
                    DateFormat('hh:mm a, dd MMM').format(date);
                    bool isRead = data["read"] ?? false;
                    String type = data["type"] ?? "General";
                    String? fromUser = data["fromUser"];

                    return Dismissible(
                      key: Key(n.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) async {
                        await FirebaseFirestore.instance
                            .collection("notifications")
                            .doc(n.id)
                            .delete();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Notification deleted")),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.notifications,
                              color: isRead ? Colors.grey : Colors.blue),
                          title: Text(
                            data["message"] ?? "No message",
                            style: TextStyle(
                              fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text("$type • $formattedDate"),
                          trailing: IconButton(
                            icon: Icon(
                              isRead
                                  ? Icons.mark_email_read
                                  : Icons.mark_email_unread,
                              color: isRead ? Colors.grey : Colors.blue,
                            ),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection("notifications")
                                  .doc(n.id)
                                  .update({"read": !isRead});
                            },
                          ),
                          onTap: () async {
                            try {
                              await FirebaseFirestore.instance
                                  .collection("notifications")
                                  .doc(n.id)
                                  .update({"read": true});
                              _handleTap(context, type, n.id, fromUser);
                            } catch (e, st) {
                              debugPrint("Tap error: $e\n$st");
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
