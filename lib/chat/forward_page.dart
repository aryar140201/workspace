import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_service.dart';

class ForwardPage extends StatelessWidget {
  final Map<String, dynamic> message;
  final ChatService chatService;
  const ForwardPage({
    super.key,
    required this.message,
    required this.chatService,
  });


  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Forward To")),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection("connections")
            .where("status", isEqualTo: "Connected")
            .where(
          Filter.or(
            Filter("userA", isEqualTo: currentUid),
            Filter("userB", isEqualTo: currentUid),
          ),
        )
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final connections = snap.data!.docs;

          if (connections.isEmpty) {
            return const Center(child: Text("No connections available"));
          }

          return ListView.builder(
            itemCount: connections.length,
            itemBuilder: (context, i) {
              final conn = connections[i].data() as Map<String, dynamic>;
              final otherUserId =
              conn["userA"] == currentUid ? conn["userB"] : conn["userA"];

              return FutureBuilder<DocumentSnapshot>(
                future: firestore.collection("users").doc(otherUserId).get(),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox();
                  }
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox(); // user doc not found
                  }

                  final rawData = userSnap.data!.data();
                  if (rawData == null) {
                    return const SizedBox(); // avoid null cast
                  }

                  final user = rawData as Map<String, dynamic>;
                  final userName = (user["name"] ?? "Unknown") as String;
                  final profilePic = user["profilePic"] as String?;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                      child: profilePic == null
                          ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : "?")
                          : null,
                    ),
                    title: Text(userName),
                    onTap: () async {
                      final cs = ChatService(otherUserId);
                      await cs.ensureChat();

                      if (message["text"] != null) {
                        // ✅ Decrypt using original chat service
                        final decrypted = chatService.decryptTextSafe(message["text"]);

                        // ✅ Send plain text in new chat
                        cs.textController.text = decrypted;
                        await cs.sendText();
                      } else {
                        await cs.sendMediaMessage(
                          type: message["type"],
                          fileUrl: message["fileUrl"],
                          fileName: message["fileName"],
                          mime: message["mime"],
                        );
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Forwarded to ${user["name"]}")),
                      );
                    },
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
