import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../auth/login_page.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';
import '../payments/payments_page.dart';
import '../main.dart';

/// 🔹 Reusable avatar widget (with fallback)
class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;

  const ProfileAvatar({super.key, required this.imageUrl, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white24,
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? NetworkImage(imageUrl!)
          : const AssetImage("assets/default_avatar.png") as ImageProvider,
      onBackgroundImageError: (_, __) {
        // fallback if URL fails
      },
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? const Icon(Icons.person, color: Colors.white70)
          : null,
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String _name = "";
  String _email = "";
  String _role = "";
  String _uniqueId = "";
  String? _profileUrl;
  String? _phoneNumber;
  bool _emailVerified = false;
  DateTime? _memberSince;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = _auth.currentUser!;
    var doc = await _firestore.collection("users").doc(user.uid).get();

    if (doc.exists) {
      var data = doc.data()!;
      String? picUrl = data["profilePic"];

      setState(() {
        _name = data["name"] ?? "";
        _email = data["email"] ?? user.email ?? "";
        _role = data["role"] ?? "";
        _uniqueId = data["uniqueId"] ?? "";
        _profileUrl = picUrl;
        _phoneNumber = user.phoneNumber;
        _emailVerified = user.emailVerified;
        _memberSince = user.metadata.creationTime;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("Profile"),
      //   backgroundColor: Colors.deepPurple,
      //   actions: [
      //     // 🔹 Small avatar on AppBar
      //     Padding(
      //       padding: const EdgeInsets.only(right: 12),
      //       child: ProfileAvatar(imageUrl: _profileUrl, radius: 18),
      //     ),
      //   ],
      // ),
      backgroundColor: Colors.blue.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 🔹 Gradient header with large avatar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.grey.shade900, Colors.black]
                    : [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                ProfileAvatar(imageUrl: _profileUrl, radius: 55),
                const SizedBox(height: 10),
                Text(_name.isNotEmpty ? _name : "No Name",
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text(_role.isNotEmpty ? _role : "User",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16, color: Colors.white)),
                if (_uniqueId.isNotEmpty)
                  Text("ID: $_uniqueId",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14, color: Colors.white)),
                if (_memberSince != null)
                  Text(
                      "Member since: ${DateFormat.yMMMMd().format(_memberSince!)}",
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),

          const SizedBox(height: 0),

          // 🔹 Options list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text("Edit Profile"),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditProfilePage()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text("Settings"),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsPage(
                        isDarkMode: isDark,
                        onToggleDarkMode: (val) =>
                            (context.findAncestorStateOfType<MyAppState>())
                                ?.toggleTheme(val),
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.payment),
                  title: const Text("Payments"),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PaymentsPage(userRole: _role)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text("Logout",
                      style: TextStyle(color: Colors.red)),
                  onTap: _logout,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
