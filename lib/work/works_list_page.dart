import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/fcm_sender.dart';

class WorksListPage extends StatefulWidget {
  final String userRole;
  final String uid;
  final String? initialStatusFilter;

  const WorksListPage({
    super.key,
    required this.userRole,
    required this.uid,
    this.initialStatusFilter,
  });

  @override
  State<WorksListPage> createState() => _WorksListPageState();
}

class _WorksListPageState extends State<WorksListPage> {
  String searchName = "";
  DateTime? selectedDate;
  String? selectedStatus;

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.initialStatusFilter;
  }

  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    var doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    if (doc.exists) return doc.data();
    return null;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Completed":
        return Colors.green;
      case "Pending":
        return Colors.orange;
      case "Failed":
        return Colors.red;
      case "Rework":
        return Colors.purple;
      case "Paid":
        return Colors.teal;
      case "Cancelled":
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  /// 🔹 Status rules
  List<String> _getStatusOptions(String currentStatus) {
    if (currentStatus == "Pending") return ["Cancel"];
    if (currentStatus == "Completed") return ["Failed", "Rework", "Paid"];
    if (currentStatus == "Paid") return []; // lock
    return ["Cancel"];
  }

  Future<void> _updateStatus(
      DocumentReference taskRef,
      String assigneeId,
      String title,
      String newStatus,
      ) async {
    await taskRef.update({"status": newStatus});

    // Save notification
    final notifRef = await FirebaseFirestore.instance.collection("notifications").add({
      "userId": assigneeId,
      "message": "⚡ Work '$title' updated to $newStatus",
      "type": "WorkStatusUpdate",
      "fromUser": widget.uid,
      "createdAt": FieldValue.serverTimestamp(),
      "read": false,
    });

    // Send FCM
    final userDoc =
    await FirebaseFirestore.instance.collection("users").doc(assigneeId).get();
    if (userDoc.exists) {
      final token = userDoc.data()?["fcmToken"];
      if (token != null && token.toString().isNotEmpty) {
        await FcmSender.sendPushMessage(
          targetToken: token,
          title: "Work Status Changed",
          body: "⚡ '$title' → $newStatus",
          fromUser: widget.uid,
          notifId: notifRef.id,
          type: "WorkStatusUpdate",
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Status changed to $newStatus")),
      );
    }
  }

  /// 🔹 Show bottom sheet for status change
  void _changeStatus(
      BuildContext context,
      DocumentReference taskRef,
      String currentStatus,
      String assigneeId,
      String title,
      ) {
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
                    await _updateStatus(taskRef, assigneeId, title, opt);
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

  /// 🔹 Task card UI
  Widget _buildTaskCard(
      BuildContext context,
      QueryDocumentSnapshot doc,
      Map<String, dynamic> data,
      String assigneeName,
      ) {
    String title = data["title"] ?? "Untitled";
    String status = data["status"] ?? "Pending";
    String assigneeId = data["assignedTo"];
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
          // Title + Status
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

          // Assignee
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.indigo,
                child: Icon(Icons.person, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Assignee: $assigneeName",
                    style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Deadline
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

          // Single Change Status Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _changeStatus(
                  context, doc.reference, status, assigneeId, title),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Change Status"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(" Works Assigned By Me"),
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
      body: Column(
        children: [
          // 🔍 Filter Bar (one line)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Search
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search by assignee",
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => searchName = val.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),

                // Date
                IconButton(
                  icon: const Icon(Icons.date_range, color: Colors.indigo),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),

                // Status Filter
                IconButton(
                  icon: const Icon(Icons.filter_alt, color: Colors.indigo),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Filter by Status",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                "Pending",
                                "Completed",
                                "Cancel",
                                "Failed",
                                "Rework",
                                "Paid"
                              ].map((status) {
                                return ChoiceChip(
                                  label: Text(status),
                                  selected: selectedStatus == status,
                                  onSelected: (_) {
                                    setState(() => selectedStatus = status);
                                    Navigator.pop(context);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() => selectedStatus = null);
                                Navigator.pop(context);
                              },
                              child: const Text("Clear Filter"),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // List of Tasks
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("tasks")
                  .where("assignedBy", isEqualTo: widget.uid)
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
                  DateTime? dueDate = data["dueDate"] != null
                      ? (data["dueDate"] as Timestamp).toDate()
                      : null;

                  if (selectedStatus != null && status != selectedStatus) {
                    return false;
                  }
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
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    var data = filtered[index].data() as Map<String, dynamic>;
                    String assigneeId = data["assignedTo"] ?? "";

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _getUserData(assigneeId),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox();
                        var user = snap.data!;
                        if (searchName.isNotEmpty &&
                            !user["name"]
                                .toString()
                                .toLowerCase()
                                .contains(searchName)) {
                          return const SizedBox();
                        }
                        return _buildTaskCard(
                          context,
                          filtered[index],
                          data,
                          user["name"],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
