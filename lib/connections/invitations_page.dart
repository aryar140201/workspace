import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/fcm_sender.dart';

class InvitationsPage extends StatelessWidget {
  const InvitationsPage({super.key});

  Future<void> _handleInvitation(
      String inviteId, String fromUserId, String action) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final currentUserDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUserId)
        .get();

    final fromUserDoc =
    await FirebaseFirestore.instance.collection("users").doc(fromUserId).get();

    final currentUserEmail = currentUserDoc.data()?["email"] ?? "Someone";
    final fromUserEmail = fromUserDoc.data()?["email"] ?? "Someone";

    if (action == "Accepted") {
      // ✅ Update invite status
      await FirebaseFirestore.instance
          .collection("invitations")
          .doc(inviteId)
          .update({"status": "Accepted"});

      // ✅ Create connection
      await FirebaseFirestore.instance.collection("connections").add({
        "userA": fromUserId,
        "userB": currentUserId,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // ✅ Firestore notifications
      final notif1 = await FirebaseFirestore.instance.collection("notifications").add({
        "userId": fromUserId,
        "message": "✅ Your invitation was accepted",
        "type": "InviteAccepted",
        "fromUser": currentUserId,
        "timestamp": FieldValue.serverTimestamp(),
        "read": false,
      });

      final notif2 = await FirebaseFirestore.instance.collection("notifications").add({
        "userId": currentUserId,
        "message": "🤝 You are now connected",
        "type": "InviteAccepted",
        "fromUser": fromUserId,
        "timestamp": FieldValue.serverTimestamp(),
        "read": false,
      });

      // ✅ Push notification to inviter
      if (fromUserDoc.exists && fromUserDoc.data()?["fcmToken"] != null) {
        await FcmSender.sendPushMessage(
          targetToken: fromUserDoc.data()!["fcmToken"],
          title: "Invitation Accepted 🎉",
          body: "$currentUserEmail accepted your connection request!",
          notifId: notif1.id,
          fromUser: currentUserId,
          type: "InviteAccepted",
          extraData: {"inviteId": inviteId},
        );
      }

      // ✅ Push notification to invitee (current user)
      if (currentUserDoc.exists && currentUserDoc.data()?["fcmToken"] != null) {
        await FcmSender.sendPushMessage(
          targetToken: currentUserDoc.data()!["fcmToken"],
          title: "New Connection 🤝",
          body: "You are now connected with $fromUserEmail",
          notifId: notif2.id,
          fromUser: fromUserId,
          type: "InviteAccepted",
          extraData: {"inviteId": inviteId},
        );
      }
    } else if (action == "Rejected") {
      await FirebaseFirestore.instance
          .collection("invitations")
          .doc(inviteId)
          .update({"status": "Rejected"});

      final notif = await FirebaseFirestore.instance.collection("notifications").add({
        "userId": fromUserId,
        "message": "❌ Your invitation was rejected",
        "type": "InviteRejected",
        "fromUser": currentUserId,
        "timestamp": FieldValue.serverTimestamp(),
        "read": false,
      });

      // ✅ Push notification to inviter
      if (fromUserDoc.exists && fromUserDoc.data()?["fcmToken"] != null) {
        await FcmSender.sendPushMessage(
          targetToken: fromUserDoc.data()!["fcmToken"],
          title: "Invitation Rejected ❌",
          body: "$currentUserEmail rejected your connection request.",
          notifId: notif.id,
          fromUser: currentUserId,
          type: "InviteRejected",
          extraData: {"inviteId": inviteId},
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _getUser(String uid) async {
    var doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("📩 Invitations"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("invitations")
            .where("toUser", isEqualTo: uid)
            .where("status", isEqualTo: "Pending")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var invites = snapshot.data!.docs;

          if (invites.isEmpty) {
            return const Center(
              child: Text("🎉 No pending invitations right now"),
            );
          }

          return ListView.builder(
            itemCount: invites.length,
            itemBuilder: (context, index) {
              var invite = invites[index];
              var data = invite.data() as Map<String, dynamic>;
              String fromUserId = data['fromUser'];

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getUser(fromUserId),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    );
                  }

                  if (!userSnap.hasData) {
                    return const SizedBox(); // avoids null return
                  }

                  var user = userSnap.data!;
                  String name = user["name"] ?? "Unknown User";
                  String role = user["role"] ?? "Unknown Role";
                  String email = user["email"] ?? "";
                  String? avatar = user["avatarUrl"];

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.deepPurpleAccent,
                            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                            child: avatar == null
                                ? const Icon(Icons.person, size: 28, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(role,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey)),
                                if (email.isNotEmpty)
                                  Text(email,
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    _handleInvitation(invite.id, fromUserId, "Accepted"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text("Accept"),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                onPressed: () =>
                                    _handleInvitation(invite.id, fromUserId, "Rejected"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text("Reject"),
                              ),
                            ],
                          )
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
