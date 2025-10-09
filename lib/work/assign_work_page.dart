import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class AssignWorkPage extends StatefulWidget {
  final String userRole;
  const AssignWorkPage({super.key, required this.userRole});

  @override
  State<AssignWorkPage> createState() => _AssignWorkPageState();
}

class _AssignWorkPageState extends State<AssignWorkPage> {
  final _workNameController = TextEditingController();
  final _priceController = TextEditingController();

  String? _selectedUserId;
  String? _selectedUserName;
  DateTime? _dueDate;

  final currentUser = FirebaseAuth.instance.currentUser!;
  bool _isLoading = false;

  // Gradient colors
  static const Color _lightStart = Color(0xFF19B2A9);
  static const Color _lightEnd = Color(0xFFF09A4D);
  static const Color _gradientStartColor = Color(0xFF19B2A9);
  static const Color _gradientEndColor = Color(0xFFF09A4D);

  // --- Fetch connected users ---
  Future<List<Map<String, dynamic>>> _getAllConnectedUsers() async {
    final firestore = FirebaseFirestore.instance;
    final uid = currentUser.uid;
    final connectedIds = <String>{};

    var connA = await firestore
        .collection("connections")
        .where("userA", isEqualTo: uid)
        .where("status", isEqualTo: "Connected")
        .get();

    var connB = await firestore
        .collection("connections")
        .where("userB", isEqualTo: uid)
        .where("status", isEqualTo: "Connected")
        .get();

    for (var d in connA.docs) connectedIds.add(d["userB"]);
    for (var d in connB.docs) connectedIds.add(d["userA"]);

    connectedIds.remove(uid);
    if (connectedIds.isEmpty) return [];

    final List<Map<String, dynamic>> users = [];
    final chunks = _splitList(connectedIds.toList(), 10);

    for (var c in chunks) {
      final snap = await firestore
          .collection("users")
          .where(FieldPath.documentId, whereIn: c)
          .get();

      users.addAll(snap.docs.map((e) {
        final data = e.data();
        return {
          "id": e.id,
          "name": data["name"] ?? "Unknown",
          "role": data["role"] ?? "",
          "profilePic": data["profilePic"] ?? "",
        };
      }));
    }
    return users;
  }

  List<List<T>> _splitList<T>(List<T> list, int n) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += n) {
      chunks.add(list.sublist(i, i + n > list.length ? list.length : i + n));
    }
    return chunks;
  }

  // --- Assign Work ---
  Future<void> _assignWork() async {
    if (_workNameController.text.isEmpty ||
        _selectedUserId == null ||
        _dueDate == null ||
        _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please fill all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = currentUser.uid;
      String a = uid.compareTo(_selectedUserId!) < 0 ? uid : _selectedUserId!;
      String b = uid.compareTo(_selectedUserId!) < 0 ? _selectedUserId! : uid;
      String pairId = "${a}_$b";

      await FirebaseFirestore.instance.collection("tasks").add({
        "pair": pairId,
        "title": _workNameController.text.trim(),
        "assignedBy": uid,
        "assignedTo": _selectedUserId,
        "assignedToName": _selectedUserName,
        "assignDate": DateTime.now(),
        "dueDate": _dueDate,
        "price": double.tryParse(_priceController.text) ?? 0,
        "status": "Pending",
        "createdAt": FieldValue.serverTimestamp(),
      });

      _showSuccessDialog();
      _workNameController.clear();
      _priceController.clear();
      setState(() {
        _selectedUserId = null;
        _selectedUserName = null;
        _dueDate = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF5DC2A0), size: 70),
            SizedBox(height: 15),
            Text(
              "Work Assigned Successfully!",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black87 : Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 🔹 Gradient Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
                top: 90, bottom: 45, left: 20, right: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [_lightStart, _lightEnd]
                    : [_lightStart, _lightEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                "Assign Work",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: isDark ? Colors.black : Colors.white,
                  shadows: const [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black38,
                    )
                  ],
                ),
              ),
            ),
          ),

          // 🔹 Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // 🔸 Work Title
                  _buildCardInput(
                    icon: Icons.work_outline,
                    hint: "Work Title...",
                    controller: _workNameController,
                    iconColor: _lightStart,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 15),

                  // 🔸 Connected Users Dropdown
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getAllConnectedUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return _buildDisabledCard(
                            "Error loading users", isDark);
                      } else if (!snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return _buildDisabledCard(
                            "No connected users found", isDark);
                      }

                      final users = snapshot.data!;
                      return _buildSearchDropdown(users, isDark);
                    },
                  ),
                  const SizedBox(height: 15),

                  // 🔸 Due Date
                  _buildDateCard(isDark, iconColor: _lightStart),
                  const SizedBox(height: 15),

                  // 🔸 Price Input
                  _buildCardInput(
                    icon: Icons.currency_rupee,
                    hint: "Price...",
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    iconColor: _lightStart,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 30),

                  // 🔹 Assign Button
                  GestureDetector(
                    onTap: _isLoading ? null : _assignWork,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_lightStart, _lightEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: _lightEnd.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "Assign",
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Components ---
  Widget _buildCardInput({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
    Color iconColor = Colors.teal, // 👈 default color if not passed
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: iconColor), // ✅ Icon uses _lightStart color
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                inputFormatters: keyboardType == TextInputType.number
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : [],
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchDropdown(List<Map<String, dynamic>> users, bool isDark) {
    final TextEditingController searchController = TextEditingController();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<Map<String, dynamic>>(
          isExpanded: true,
          hint: Text("Search or select connection...",
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey[700])),
          value: users.firstWhereOrNull((u) => u['id'] == _selectedUserId),
          onChanged: (user) {
            if (user != null) {
              setState(() {
                _selectedUserId = user['id'];
                _selectedUserName = user['name'];
              });
            }
          },
          items: users.map((user) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: user,
              child: Row(
                children: [
                  user['profilePic'] != ""
                      ? CircleAvatar(
                    backgroundImage: NetworkImage(user['profilePic']),
                    radius: 15,
                  )
                      : const Icon(Icons.account_circle,
                      color: Colors.teal, size: 30),
                  const SizedBox(width: 10),
                  Text(user['name'] ?? '',
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }).toList(),
          dropdownStyleData: DropdownStyleData(
            maxHeight: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark ? const Color(0xFF2B2B2B) : Colors.white,
            ),
          ),
          dropdownSearchData: DropdownSearchData<Map<String, dynamic>>(
            searchController: searchController,
            searchInnerWidgetHeight: 50,
            searchInnerWidget: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: searchController,
                style:
                TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search user...',
                  hintStyle:
                  TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                  prefixIcon: Icon(Icons.search,
                      color: isDark ? Colors.white54 : Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            searchMatchFn: (item, value) {
              final name = item.value?['name']?.toLowerCase() ?? '';
              return name.contains(value.toLowerCase());
            },
          ),
          onMenuStateChange: (isOpen) {
            if (!isOpen) searchController.clear();
          },
        ),
      ),
    );
  }

  Widget _buildDateCard(bool isDark, {Color iconColor = Colors.teal}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: iconColor), // ✅ color applied here
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: iconColor, // ✅ header & selected date color
                            onPrimary: Colors.white,
                            onSurface: isDark ? Colors.white70 : Colors.black87,
                          ),
                          dialogBackgroundColor:
                          isDark ? const Color(0xFF121212) : Colors.white,
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(
                              foregroundColor: iconColor,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                  }
                },
                child: Text(
                  _dueDate == null
                      ? "Select due date..."
                      : DateFormat("dd MMM yyyy").format(_dueDate!),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledCard(String text, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
      ),
    );
  }
}
