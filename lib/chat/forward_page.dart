import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemUiOverlayStyle

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

    final SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );
    // If your gradient is dark, use:
    // final SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    //   statusBarColor: Colors.transparent,
    //   statusBarIconBrightness: Brightness.light,
    //   statusBarBrightness: Brightness.dark, // For iOS
    // );


    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Forward To",
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),

        backgroundColor: Colors.blue.shade50,
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
                      return const SizedBox.shrink(); // Use shrink for less space when loading
                    }
                    if (!userSnap.hasData || !userSnap.data!.exists) {
                      return const SizedBox.shrink(); // user doc not found
                    }

                    final rawData = userSnap.data!.data();
                    if (rawData == null) {
                      return const SizedBox.shrink(); // avoid null cast
                    }

                    final user = rawData as Map<String, dynamic>;
                    final userName = (user["name"] ?? "Unknown") as String;
                    final profilePic = user["profilePic"] as String?;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: profilePic != null && profilePic.isNotEmpty
                            ? NetworkImage(profilePic)
                            : null,
                        child: profilePic == null || profilePic.isEmpty
                            ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : "?")
                            : null,
                      ),
                      title: Text(userName),
                      onTap: () async {
                        // Ensure the context is still valid if operations are long
                        if (!context.mounted) return;

                        final cs = ChatService(otherUserId);
                        await cs.ensureChat();

                        final now = FieldValue.serverTimestamp();
                        final newMsgRef = cs.msgsCol.doc();

                        final msg = {
                          "senderId": cs.currentUid,
                          "type": message["type"],
                          "fileUrl": message["fileUrl"],  // reuse existing file URL
                          "fileName": message["fileName"],
                          "mime": message["mime"],
                          "createdAt": now,
                          "deliveredBy": <String, bool>{},
                          "readBy": {cs.currentUid: true},
                          "deletedFor": <String, bool>{},
                        };

                        // Save forwarded message
                        await newMsgRef.set(msg);

                        // Update chat's lastMessage
                        await cs.chatRef.set(
                          {
                            "updatedAt": now,
                            "lastMessage": {
                              "id": newMsgRef.id,
                              "type": message["type"],
                              "fileUrl": message["fileUrl"],
                              "fileName": message["fileName"],
                              "senderId": cs.currentUid,
                              "createdAt": now,
                              "readBy": {cs.currentUid: true, otherUserId: false},
                            },
                          },
                          SetOptions(merge: true),
                        );

                        if (!context.mounted) return;
                        Navigator.pop(context); // Pop current page
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
      ),
    );
  }
}
