import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../core/fcm_sender.dart';

class MyWorksPage extends StatefulWidget {
  final String userRole;
  final String uid;
  final String? initialStatusFilter;

  const MyWorksPage({
    super.key,
    required this.userRole,
    required this.uid,
    this.initialStatusFilter,
  });

  @override
  State<MyWorksPage> createState() => _MyWorksPageState();
}

class _MyWorksPageState extends State<MyWorksPage>
    with AutomaticKeepAliveClientMixin {
  String searchName = "";
  DateTime? selectedDate;
  String? selectedStatus;

  final ScrollController _scrollController = ScrollController();
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.initialStatusFilter;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];

    var doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    if (doc.exists) {
      _userCache[uid] = doc.data()!;
      return _userCache[uid];
    }
    return null;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Completed":
        return Colors.green;
      case "Pending":
        return Colors.orange;
      case "In Progress":
        return Colors.blue;
      case "Failed":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<String> _getStatusOptions(String currentStatus) {
    if (currentStatus == "Pending") return ["In Progress"];
    if (currentStatus == "In Progress") return ["Completed"];
    return [];
  }

  Future<void> _updateStatus(
      DocumentReference taskRef, String assignerId, String title, String newStatus) async {
    await taskRef.update({"status": newStatus});

    final notifRef =
    await FirebaseFirestore.instance.collection("notifications").add({
      "userId": assignerId,
      "message": "⚡ Work '$title' marked as $newStatus",
      "type": "WorkStatusUpdate",
      "fromUser": widget.uid,
      "createdAt": FieldValue.serverTimestamp(),
      "read": false,
    });

    final userDoc =
    await FirebaseFirestore.instance.collection("users").doc(assignerId).get();
    if (userDoc.exists) {
      final token = userDoc.data()?["fcmToken"];
      if (token != null && token.toString().isNotEmpty) {
        await FcmSender.sendPushMessage(
          targetToken: token,
          title: "Work Status Update",
          body: "⚡ '$title' → $newStatus",
          fromUser: widget.uid,
          notifId: notifRef.id,
          type: "WorkStatusUpdate",
        );
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Status changed to $newStatus")),
    );
  }

  void _changeStatus(BuildContext context, DocumentReference taskRef,
      String currentStatus, String assignerId, String title) {
    final options = _getStatusOptions(currentStatus);

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ No further status change allowed")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Update Status",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...options.map((opt) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(opt,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateStatus(taskRef, assignerId, title, opt);
                  },
                ),
              )),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, QueryDocumentSnapshot doc,
      Map<String, dynamic> data, String assignerName) {
    String title = data["title"] ?? "Untitled";
    String status = data["status"] ?? "Pending";
    String assignerId = data["assignedBy"];
    DateTime? dueDate =
    data["dueDate"] != null ? (data["dueDate"] as Timestamp).toDate() : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Chip(
                label: Text(status),
                backgroundColor: _getStatusColor(status).withOpacity(0.15),
                labelStyle: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.indigo,
                child: Icon(Icons.person, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Assigned By: $assignerName",
                    style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.date_range, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                dueDate != null
                    ? "Due: ${DateFormat("dd MMM yyyy").format(dueDate)}"
                    : "No Deadline",
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _changeStatus(context, doc.reference, status, assignerId, title),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Change Status"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Works Assigned To Me"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)], // 🔵 Blue gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("tasks")
            .where("assignedTo", isEqualTo: widget.uid)
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var tasks = snapshot.data!.docs;

          var filtered = tasks.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String status = data["status"] ?? "";
            DateTime? dueDate =
            data["dueDate"] != null ? (data["dueDate"] as Timestamp).toDate() : null;

            if (selectedStatus != null && status != selectedStatus) return false;
            if (selectedDate != null &&
                (dueDate == null ||
                    dueDate.day != selectedDate!.day ||
                    dueDate.month != selectedDate!.month ||
                    dueDate.year != selectedDate!.year)) {
              return false;
            }
            return true;
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text("🙌 No works found"));
          }

          return ListView.builder(
            key: const PageStorageKey("MyWorksList"),
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            physics: Theme.of(context).platform == TargetPlatform.iOS ||
                Theme.of(context).platform == TargetPlatform.macOS
                ? const BouncingScrollPhysics()
                : const ClampingScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              var data = filtered[index].data() as Map<String, dynamic>;
              String assignerId = data["assignedBy"] ?? "";

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getUserData(assignerId),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox();
                  var user = snap.data!;

                  if (searchName.isNotEmpty &&
                      !user["name"].toString().toLowerCase().contains(searchName)) {
                    return const SizedBox();
                  }

                  return _buildTaskCard(context, filtered[index], data, user["name"]);
                },
              );
            },
          );
        },
      ),
    );
  }
}
