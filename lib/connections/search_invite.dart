import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../core/fcm_sender.dart';

class SearchAndInvite extends StatefulWidget {
  const SearchAndInvite({super.key});

  @override
  State<SearchAndInvite> createState() => _SearchAndInviteState();
}

class _SearchAndInviteState extends State<SearchAndInvite> {
  final _searchController = TextEditingController();
  Map<String, dynamic>? _searchedUser;
  String? _searchedUserId;
  List<Map<String, dynamic>> _recommendedUsers = [];
  bool _permissionDenied = false;

  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  /// 🔹 Manual Search
  Future<void> _searchUser() async {
    var query = _searchController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Unique ID / Email / Phone")),
      );
      return;
    }

    QuerySnapshot result = await FirebaseFirestore.instance
        .collection("users")
        .where("uniqueId", isEqualTo: query)
        .get();

    if (result.docs.isEmpty) {
      result = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: query)
          .get();
    }

    if (result.docs.isEmpty) {
      result = await FirebaseFirestore.instance
          .collection("users")
          .where("phone", isEqualTo: query)
          .get();
    }

    if (result.docs.isEmpty) {
      setState(() {
        _searchedUser = null;
        _searchedUserId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No user found")),
      );
      return;
    }

    setState(() {
      _searchedUser = result.docs.first.data() as Map<String, dynamic>;
      _searchedUserId = result.docs.first.id;
    });
  }

  /// 🔹 Fetch Recommended Users
  Future<void> _fetchRecommendedUsers() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      setState(() => _permissionDenied = true);
      return;
    }

    List<Contact> contacts =
    await FlutterContacts.getContacts(withProperties: true);

    List<String> phoneNumbers = [];
    for (var contact in contacts) {
      for (var phone in contact.phones) {
        String normalized = phone.number.replaceAll(RegExp(r'\D'), '');
        if (normalized.isNotEmpty) phoneNumbers.add(normalized);
      }
    }

    if (phoneNumbers.isEmpty) return;

    List<Map<String, dynamic>> matched = [];
    for (var chunk in phoneNumbers.slices(10)) {
      QuerySnapshot matchedUsers = await FirebaseFirestore.instance
          .collection("users")
          .where("phone", whereIn: chunk)
          .get();
      matched.addAll(
          matchedUsers.docs.map((doc) => doc.data() as Map<String, dynamic>));
    }

    setState(() {
      _recommendedUsers = matched;
    });
  }

  /// 🚀 Send Invitation
  Future<void> _sendInvitation(String targetUserId) async {
    if (targetUserId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot invite yourself")),
      );
      return;
    }

    // Check existing connection
    var existingConn = await FirebaseFirestore.instance
        .collection("connections")
        .where(Filter.or(
      Filter("userA", isEqualTo: currentUserId),
      Filter("userB", isEqualTo: currentUserId),
    ))
        .get();

    for (var doc in existingConn.docs) {
      var d = doc.data() as Map<String, dynamic>;
      if ((d["userA"] == targetUserId || d["userB"] == targetUserId) &&
          d["status"] == "Connected") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Already connected ✅")),
        );
        return;
      }
    }

    // 🚀 Create new connection with Pending status
    final connDoc =
    await FirebaseFirestore.instance.collection("connections").add({
      "userA": currentUserId,
      "userB": targetUserId,
      "status": "Pending",
      "createdAt": FieldValue.serverTimestamp(),
    });

    // 🔹 Add to Notifications collection
    final notifDoc =
    await FirebaseFirestore.instance.collection("notifications").add({
      "userId": targetUserId,
      "type": "ConnectionRequest",
      "fromUser": currentUserId,
      "status": "Pending",
      "message": "You have a new connection request",
      "createdAt": FieldValue.serverTimestamp(),
      "read": false,
    });

    // 🔹 Send FCM Push
    var targetDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(targetUserId)
        .get();
    String? targetToken = targetDoc.data()?["fcmToken"];

    if (targetToken != null && targetToken.isNotEmpty) {
      await FcmSender.sendPushMessage(
        targetToken: targetToken,
        title: "New Connection Request",
        body: "Someone sent you a connection request!",
        notifId: notifDoc.id,
        fromUser: currentUserId,
        type: "ConnectionRequest",
        extraData: {
          "connectionId": connDoc.id,
        },
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invitation Sent ✅")),
    );
  }

  /// ❌ Cancel Invitation
  Future<void> _cancelInvitation(String targetUserId) async {
    var invites = await FirebaseFirestore.instance
        .collection("connections")
        .where("userA", isEqualTo: currentUserId)
        .where("userB", isEqualTo: targetUserId)
        .where("status", isEqualTo: "Pending")
        .get();

    for (var doc in invites.docs) {
      await doc.reference.delete();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invitation Cancelled ❌")),
    );
  }

  /// ✅ Listen for invitation responses
  void _listenForInvitationResponses() {
    FirebaseFirestore.instance
        .collection("notifications")
        .where("userId", isEqualTo: currentUserId)
        .where("type", isEqualTo: "ConnectionRequest")
        .where("status", isEqualTo: "Pending")
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        var data = doc.data();
        _showInvitationDialog(doc.id, data);
      }
    });
  }

  /// ✅ Show Accept/Reject Dialog
  /// ✅ Show Accept/Reject Dialog
  void _showInvitationDialog(String notifId, Map<String, dynamic> data) async {
    final String? fromUser = data["fromUser"] as String?;
    final String? connectionId = data["connectionId"] as String?;

    if (fromUser == null || connectionId == null) {
      debugPrint("⚠️ Missing required data in invitation: $data");
      return; // 🔥 Avoid crash
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Connection Request"),
        content: const Text("Do you want to accept this connection?"),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("connections")
                  .doc(connectionId)
                  .update({"status": "Rejected"});
              await FirebaseFirestore.instance
                  .collection("notifications")
                  .doc(notifId)
                  .update({"status": "Rejected"});
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Reject"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("connections")
                  .doc(connectionId)
                  .update({"status": "Connected"});
              await FirebaseFirestore.instance
                  .collection("notifications")
                  .doc(notifId)
                  .update({"status": "Accepted"});
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Accept", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchRecommendedUsers();
    _listenForInvitationResponses(); // ✅ Start listening
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? Colors.grey[850] : Colors.grey.shade100;
    final iconColor = isDark ? Colors.white70 : Colors.grey;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔹 Search Bar
            Container(
              decoration: BoxDecoration(
                // color: surfaceColor,
                // color: Colors.white.withOpacity(0.15),
                gradient: LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: Colors.white),
                  hintText: "Enter Unique ID / Email / Phone...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.arrow_forward_ios,
                        color: isDark
                            ? Colors.white
                            : Colors.white),
                    onPressed: _searchUser,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 User Preview
            if (_searchedUser != null)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(_searchedUser!["name"] ?? "Unknown User"),
                  subtitle: Text(_searchedUser!["email"] ?? ""),
                  trailing: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("connections")
                        .where(Filter.or(
                      Filter("userA", isEqualTo: currentUserId),
                      Filter("userB", isEqualTo: currentUserId),
                    ))
                        .snapshots(),
                    builder: (context, connSnap) {
                      if (connSnap.hasData) {
                        for (var doc in connSnap.data!.docs) {
                          var d = doc.data() as Map<String, dynamic>;
                          if ((d["userA"] == _searchedUserId ||
                              d["userB"] == _searchedUserId)) {
                            if (d["status"] == "Connected") {
                              return ElevatedButton(
                                onPressed: null, // disable remove here
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey),
                                child: const Text("Connected"),
                              );
                            } else if (d["status"] == "Pending" &&
                                d["userA"] == currentUserId) {
                              return ElevatedButton(
                                onPressed: () =>
                                    _cancelInvitation(_searchedUserId!),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange),
                                child: const Text("Cancel Invite",
                                    style: TextStyle(color: Colors.white)),
                              );
                            } else if (d["status"] == "Pending" &&
                                d["userB"] == currentUserId) {
                              // 👈 Disable button if they invited me
                              return ElevatedButton(
                                onPressed: null,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey),
                                child: const Text("Requested"),
                              );
                            }
                          }
                        }
                      }

                      // If no connection
                      return ElevatedButton(
                        onPressed: () => _sendInvitation(_searchedUserId!),
                        style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text("Invite",
                            style: TextStyle(color: Colors.white)),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension ListChunk<T> on List<T> {
  Iterable<List<T>> slices(int size) sync* {
    for (var i = 0; i < length; i += size) {
      yield sublist(i, i + size > length ? length : i + size);
    }
  }
}
