import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../connections/see_all_connections.dart';
import 'login_page.dart';
import '../dashboard/Dashboard.dart';
import '../connections/search_invite.dart';
import '../work/my_works_page.dart';
import '../work/assign_work_page.dart';
import '../profile/profile_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key, this.initialIndex = 0});

  final int initialIndex; // 👈 Pass down starting tab

  Future<String?> _getUserRole(String uid) async {
    final doc =
    await FirebaseFirestore.instance.collection("users").doc(uid).get();
    if (doc.exists) {
      return doc["role"] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return const LoginPage();
        }
        String uid = snapshot.data!.uid;
        return FutureBuilder<String?>(
          future: _getUserRole(uid),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return MainHome(
              userRole: roleSnap.data!,
              uid: uid,
              initialIndex: initialIndex, // 👈 carry forward
            );
          },
        );
      },
    );
  }
}

class MainHome extends StatefulWidget {
  final String userRole;
  final String uid;
  final int initialIndex;

  const MainHome({
    super.key,
    required this.userRole,
    required this.uid,
    this.initialIndex = 0, // default Dashboard
  });

  @override
  State<MainHome> createState() => _MainHomeState();
}

class _MainHomeState extends State<MainHome> {
  late int _selectedIndex;
  late List<Widget> _pages;


  // Gradient colors
  static const Color _lightStart = Color(0xFF19B2A9);
  static const Color _lightEnd = Color(0xFFF09A4D);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    if (widget.userRole == "Freelancer") {
      _pages = [
        Dashboard(userRole: widget.userRole),
        const SearchAndInvite(),
        MyWorksPage(userRole: widget.userRole, uid: widget.uid),
        SeeAllConnections(userRole: widget.userRole),
        const ProfilePage(),
      ];
    } else {
      _pages = [
        Dashboard(userRole: widget.userRole),
        const SearchAndInvite(),
        AssignWorkPage(userRole: widget.userRole),
        SeeAllConnections(userRole: widget.userRole),
        const ProfilePage(),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      "Freelenia",
      "Search",
      widget.userRole == "Freelancer" ? "My Work" : "Assign Work",
      "Chat",
      "Profile"
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: (_selectedIndex == 0 || _selectedIndex == 1 || _selectedIndex == 2 || _selectedIndex == 3 || _selectedIndex == 4)
          ? null
          : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          titles[_selectedIndex],
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontFamily: "Arial",
          ),
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        selectedItemColor: _lightStart, // ✅ teal for selected
        unselectedItemColor: isDark ? Colors.white : Colors.black, // ✅ dark/light
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home), // ❌ no fixed color, Flutter handles it
            label: "Dashboard",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Search",
          ),
          if (widget.userRole == "Freelancer")
            const BottomNavigationBarItem(
              icon: Icon(Icons.work),
              label: "My Work",
            )
          else
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_box),
              label: "Add",
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "Chat",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
