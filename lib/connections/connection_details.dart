import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:freelenia/widgets/profile_avatar.dart';
import '../core/fcm_sender.dart'; // ✅ helper for push messages

class ConnectionDetailsPage extends StatefulWidget {
  final String userId;

  const ConnectionDetailsPage({super.key, required this.userId});

  @override
  State<ConnectionDetailsPage> createState() => _ConnectionDetailsPageState();
}

class _ConnectionDetailsPageState extends State<ConnectionDetailsPage>
    with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser!;
  late final TabController _tabController;
  late final String _pairId;

  String _currentUserRole = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    String a = currentUser.uid.compareTo(widget.userId) < 0 ? currentUser.uid : widget.userId;
    String b = currentUser.uid.compareTo(widget.userId) < 0 ? widget.userId : currentUser.uid;
    _pairId = "${a}_$b";

    _loadCurrentUserRole();

    // 👀 Listen for removal approval/rejection
    FirebaseFirestore.instance
        .collection("remove_requests")
        .doc(_pairId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        if (data["status"] == "approved") {
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil("/dashboard", (route) => false);
          }
        } else if (data["status"] == "rejected" && data["requestedBy"] == currentUser.uid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("❌ Your connection removal request was rejected")),
            );
          }
        }
      }
    });
  }

  Future<void> _loadCurrentUserRole() async {
    var doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .get();
    if (doc.exists) {
      setState(() {
        _currentUserRole = doc.data()?["role"] ?? "";
      });
    }
  }

  /// 🔹 Handle remove request popup for the receiver
  Future<void> handleRemoveRequest(String pairId, String requestedBy) async {
    bool? approve = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Connection Removal"),
        content: const Text("Do you approve removing this connection?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Reject"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Approve"),
          ),
        ],
      ),
    );

    if (approve == true) {
      // ✅ Remove connection + cleanup
      await FirebaseFirestore.instance.collection("connections").doc(pairId).delete();
      await FirebaseFirestore.instance.collection("remove_requests").doc(pairId).update({
        "status": "approved",
      });

      // Send back FCM notification
      final requester = await FirebaseFirestore.instance.collection("users").doc(requestedBy).get();
      final token = requester["fcmToken"];
      if (token != null) {
        await FcmSender.sendPushMessage(
          targetToken: token,
          title: "Remove Connection Approved",
          body: "✅ ${currentUser.email} approved the removal of this connection.",
          notifId: pairId,
          fromUser: currentUser.uid,
          type: "RemoveApproved",
          extraData: {"pairId": pairId},
        );
      }

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil("/dashboard", (route) => false);
      }
    } else {
      // ❌ Rejected → mark rejected
      await FirebaseFirestore.instance.collection("remove_requests").doc(pairId).update({
        "status": "rejected",
      });

      // Send back FCM notification
      final requester = await FirebaseFirestore.instance.collection("users").doc(requestedBy).get();
      final token = requester["fcmToken"];
      if (token != null) {
        await FcmSender.sendPushMessage(
          targetToken: token,
          title: "Request Rejected",
          body: "❌ Your connection removal request was rejected.",
          notifId: pairId,
          fromUser: currentUser.uid,
          type: "RemoveRejected",
          extraData: {"pairId": pairId},
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    var doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(widget.userId)
        .get();
    if (doc.exists) return doc.data();
    return null;
  }

  Stream<List<Map<String, dynamic>>> _getUserTasks() {
    return FirebaseFirestore.instance
        .collection("tasks")
        .where("pair", isEqualTo: _pairId)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => d.data() as Map<String, dynamic>).toList());
  }

  /// 🔹 Ask confirmation before removal
  Future<void> _confirmRemoveConnection() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Connection"),
        content: const Text(
            "Are you sure you want to request removing this connection? Both parties must confirm."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Request Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _sendRemoveRequest();
    }
  }

  /// 🔹 Send removal request (needs mutual confirmation)
  Future<void> _sendRemoveRequest() async {
    try {
      await FirebaseFirestore.instance
          .collection("remove_requests")
          .doc(_pairId)
          .set({
        "pairId": _pairId,
        "requestedBy": currentUser.uid,
        "otherUser": widget.userId,
        "status": "pending",
        "timestamp": FieldValue.serverTimestamp(),
      });

      // Save notification
      final notifRef = await FirebaseFirestore.instance.collection("notifications").add({
        "userId": widget.userId,
        "message":
        "⚠️ ${currentUser.email} has requested to remove this connection. Please confirm.",
        "type": "RemoveRequest",
        "fromUser": currentUser.uid,
        "pairId": _pairId,
        "timestamp": FieldValue.serverTimestamp(),
        "read": false,
      });

      // Send push
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.userId)
          .get();
      final token = userDoc["fcmToken"];
      if (token != null) {
        await FcmSender.sendPushMessage(
          targetToken: token,
          title: "Remove Connection Request",
          body:
          "⚠️ ${currentUser.email} has requested to remove your connection. Please confirm.",
          notifId: notifRef.id,           // ✅ Firestore docId
          fromUser: currentUser.uid,
          type: "RemoveRequest",
          extraData: {"pairId": _pairId},
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Removal request sent")),
      );
    } catch (e) {
      debugPrint("❌ Error sending remove request: $e");
    }
  }

  /// 🔹 Approve request (final removal)
  static Future<void> approveRemoval(String pairId) async {
    await FirebaseFirestore.instance
        .collection("connections")
        .doc(pairId)
        .delete();
    await FirebaseFirestore.instance
        .collection("remove_requests")
        .doc(pairId)
        .delete();
  }

  /// 🔹 Assign new work with push + notification
  Future<void> _assignWork(BuildContext context) async {
    final _titleController = TextEditingController();
    final _priceController = TextEditingController();
    DateTime? selectedDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Assign Work",
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Work Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: "Price (₹)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDate == null
                          ? "Select Due Date"
                          : DateFormat.yMMMd().format(selectedDate!),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: const Text("Pick Date"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_titleController.text.trim().isEmpty ||
                      selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please fill all fields")),
                    );
                    return;
                  }

                  final title = _titleController.text.trim();
                  final price =
                      double.tryParse(_priceController.text.trim()) ?? 0;

                  // ✅ Save Task
                  await FirebaseFirestore.instance.collection("tasks").add({
                    "pair": _pairId,
                    "title": title,
                    "price": price,
                    "status": "Pending",
                    "dueDate": Timestamp.fromDate(selectedDate!),
                    "assignedBy": currentUser.uid,
                    "assignedTo": widget.userId,
                    "createdAt": FieldValue.serverTimestamp(),
                  });

                  // ✅ Firestore Notification
                  final notifRef =
                  await FirebaseFirestore.instance.collection("notifications").add({
                    "userId": widget.userId,
                    "message":
                    "📋 New work '$title' assigned to you. Due: ${DateFormat("dd MMM").format(selectedDate!)}",
                    "type": "WorkAssigned",
                    "fromUser": currentUser.uid,
                    "pairId": _pairId,
                    "timestamp": FieldValue.serverTimestamp(),
                    "read": false,
                  });

                  // ✅ Send FCM push
                  final userDoc = await FirebaseFirestore.instance
                      .collection("users")
                      .doc(widget.userId)
                      .get();
                  final token = userDoc["fcmToken"];
                  if (token != null) {
                    await FcmSender.sendPushMessage(
                      targetToken: token,
                      title: "New Work Assigned",
                      body:
                      "📋 $title (Due: ${DateFormat("dd MMM").format(selectedDate!)})",
                      notifId: notifRef.id,
                      fromUser: currentUser.uid,
                      type: "WorkAssigned",
                      extraData: {"pairId": _pairId},
                    );
                  }

                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ Work Assigned")),
                  );
                },
                child: const Text("Assign"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _currentUserRole == "Company"
          ? FloatingActionButton.extended(
        onPressed: () => _assignWork(context),
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: const Text("Assign Work",
            style: TextStyle(color: Colors.white)),
      )
          : null,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var user = snapshot.data!;
          String name = user["name"] ?? "Unknown";
          String role = user["role"] ?? "N/A";
          String email = user["email"] ?? "N/A";

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getUserTasks(),
            builder: (context, taskSnap) {
              if (!taskSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var tasks = taskSnap.data!;
              int total = tasks.length;
              int completed =
                  tasks.where((t) => t["status"] == "Completed").length;
              int pending =
                  tasks.where((t) => t["status"] != "Completed").length;

              double totalPayments = tasks.fold<double>(
                0.0,
                    (s, t) => s + ((t["price"] ?? 0) as num).toDouble(),
              );

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      expandedHeight: 250,
                      floating: false,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ProfileAvatar(
                              imageUrlOrPath: user["profilePic"], // 👈 show real profile
                              radius: 50,
                            ),
                            const SizedBox(height: 10),
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(role, style: const TextStyle(color: Colors.grey)),
                            Text(email, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _confirmRemoveConnection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.person_remove, color: Colors.white),
                              label: const Text("Remove Connection",
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),

                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStat("Total", total),
                            _buildStat("Completed", completed),
                            _buildStat("Pending", pending),
                            _buildStat("Payments",
                                "₹${totalPayments.toStringAsFixed(0)}"),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      delegate: _SliverTabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.deepPurple,
                          tabs: const [
                            Tab(icon: Icon(Icons.work), text: "Works"),
                            Tab(icon: Icon(Icons.payments), text: "Payments"),
                          ],
                        ),
                      ),
                      pinned: true,
                    )
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    // Works Tab
                    ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: tasks.length,
                      itemBuilder: (context, i) {
                        var t = tasks[i];
                        DateTime due = (t["dueDate"] as Timestamp).toDate();
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.task_alt,
                                color: Colors.blue),
                            title: Text(t["title"] ?? "Untitled"),
                            subtitle: Text(
                                "Status: ${t["status"]} • Due: ${DateFormat("dd MMM").format(due)}"),
                            trailing: Text(
                              "₹${((t["price"] ?? 0) as num).toDouble().toStringAsFixed(0)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: t["status"] == "Completed"
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Payments Tab
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.check_circle,
                                color: Colors.green),
                            title: const Text("Completed Payments"),
                            trailing: Text(
                              "₹${tasks.where((t) => t["status"] == "Completed").fold<double>(0.0, (s, t) => s + ((t["price"] ?? 0) as num).toDouble()).toStringAsFixed(0)}",
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.pending,
                                color: Colors.orange),
                            title: const Text("Pending Payments"),
                            trailing: Text(
                              "₹${tasks.where((t) => t["status"] != "Completed").fold<double>(0.0, (s, t) => s + ((t["price"] ?? 0) as num).toDouble()).toStringAsFixed(0)}",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, dynamic value) {
    return Column(
      children: [
        Text("$value",
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

/// Custom delegate for TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverTabBarDelegate(this._tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
