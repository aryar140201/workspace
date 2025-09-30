import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../core/fcm_sender.dart';

class AssignWorkPage extends StatefulWidget {
  final String userRole;
  const AssignWorkPage({super.key, required this.userRole});

  @override
  State<AssignWorkPage> createState() => _AssignWorkPageState();
}

class _AssignWorkPageState extends State<AssignWorkPage> {
  final _workNameController = TextEditingController();
  final _priceController = TextEditingController();

  String? _selectedRole;
  String? _selectedUserId;
  String? _selectedUserName;
  DateTime? _dueDate;

  final currentUser = FirebaseAuth.instance.currentUser!;
  bool _isLoading = false;

  /// 🔹 Fetch only connected users with selected role
  Future<List<Map<String, dynamic>>> _getUsersByRole(String role) async {
    var connSnap = await FirebaseFirestore.instance
        .collection("connections")
        .where("userA", isEqualTo: currentUser.uid)
        .get();

    var connSnap2 = await FirebaseFirestore.instance
        .collection("connections")
        .where("userB", isEqualTo: currentUser.uid)
        .get();

    final connectedIds = <String>{};
    for (var doc in connSnap.docs) {
      connectedIds.add(doc["userB"]);
    }
    for (var doc in connSnap2.docs) {
      connectedIds.add(doc["userA"]);
    }
    connectedIds.remove(currentUser.uid);

    if (connectedIds.isEmpty) return [];

    final List<Map<String, dynamic>> results = [];
    final chunks = _splitList(connectedIds.toList(), 10);

    for (var chunk in chunks) {
      var userSnap = await FirebaseFirestore.instance
          .collection("users")
          .where(FieldPath.documentId, whereIn: chunk)
          .where("role", isEqualTo: role)
          .get();

      results.addAll(userSnap.docs.map((doc) {
        final data = doc.data();
        return {
          "id": doc.id,
          "name": data["name"] as String? ?? "Unknown",
          "role": data["role"] as String? ?? "",
        };
      }));
    }
    return results;
  }

  List<List<T>> _splitList<T>(List<T> list, int n) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += n) {
      chunks.add(list.sublist(i, i + n > list.length ? list.length : i + n));
    }
    return chunks;
  }

  /// 🔹 Save task + send push
  Future<void> _assignWork() async {
    if (_workNameController.text.isEmpty ||
        _selectedRole == null ||
        _selectedUserId == null ||
        _dueDate == null ||
        _priceController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please fill all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String a = currentUser.uid.compareTo(_selectedUserId!) < 0
          ? currentUser.uid
          : _selectedUserId!;
      String b = currentUser.uid.compareTo(_selectedUserId!) < 0
          ? _selectedUserId!
          : currentUser.uid;
      String pairId = "${a}_$b";

      final taskTitle = _workNameController.text.trim();

      // ✅ Save Task
      await FirebaseFirestore.instance.collection("tasks").add({
        "pair": pairId,
        "title": taskTitle,
        "assignedBy": currentUser.uid,
        "assignedTo": _selectedUserId,
        "assignedToName": _selectedUserName,
        "assignedToRole": _selectedRole,
        "assignDate": DateTime.now(),
        "dueDate": _dueDate,
        "price": double.tryParse(_priceController.text.trim()) ?? 0,
        "status": "Pending",
        "createdAt": FieldValue.serverTimestamp(),
      });

      // ✅ Save Notification
      final notifRef =
      await FirebaseFirestore.instance.collection("notifications").add({
        "userId": _selectedUserId,
        "message":
        "📋 New work '$taskTitle' assigned to you. Due: ${DateFormat("dd MMM").format(_dueDate!)}",
        "type": "WorkAssigned",
        "fromUser": currentUser.uid,
        "timestamp": FieldValue.serverTimestamp(),
        "read": false,
      });

      // ✅ Send FCM push
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(_selectedUserId)
          .get();

      if (userDoc.exists) {
        final token = userDoc.data()?["fcmToken"];
        if (token != null && token.toString().isNotEmpty) {
          await FcmSender.sendPushMessage(
            targetToken: token,
            title: "New Work Assigned",
            body:
            "📋 $taskTitle (Due: ${DateFormat("dd MMM").format(_dueDate!)})",
            fromUser: currentUser.uid,
            notifId: notifRef.id,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Work Assigned Successfully")),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint("❌ Error assigning work: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!(widget.userRole == "Company" || widget.userRole == "Vendor")) {
      return const Scaffold(
        body: Center(
          child: Text(
            "❌ Only Company or Vendor can assign works",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Work"),
        centerTitle: true,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildInputCard(
              label: "Work Title",
              icon: Icons.work_outline,
              child: TextField(
                controller: _workNameController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Enter work name",
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildInputCard(
              label: "Assign To Role",
              icon: Icons.people_alt,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration.collapsed(hintText: ""),
                value: _selectedRole,
                hint: const Text("Select role"),
                items: ["Freelancer", "Vendor", "Company"]
                    .map((role) => DropdownMenuItem<String>(
                  value: role,
                  child: Text(role),
                ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedRole = val;
                    _selectedUserId = null;
                    _selectedUserName = null;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedRole != null)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _getUsersByRole(_selectedRole!),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snap.data!.isEmpty) {
                    return const Text("⚠️ No connected users found");
                  }
                  return _buildInputCard(
                    label: "Select User",
                    icon: Icons.person,
                    child: DropdownButtonFormField<String>(
                      decoration:
                      const InputDecoration.collapsed(hintText: ""),
                      value: _selectedUserId,
                      hint: const Text("Choose user"),
                      items: snap.data!
                          .map((u) => DropdownMenuItem<String>(
                        value: u["id"] as String,
                        child: Text(
                          "${u["name"]} (${u["role"]})",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                      ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedUserId = val;
                          _selectedUserName = snap.data!
                              .firstWhere((u) => u["id"] == val)["name"];
                        });
                      },
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),

            _buildInputCard(
              label: "Due Date",
              icon: Icons.calendar_today,
              child: InkWell(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _dueDate == null
                        ? "Select due date"
                        : DateFormat("dd MMM yyyy").format(_dueDate!),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildInputCard(
              label: "Price",
              icon: Icons.attach_money,
              child: TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Enter price",
                ),
              ),
            ),
            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: _assignWork,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.send),
              label: const Text(
                "Assign Work",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(
      {required String label, required IconData icon, required Widget child}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
