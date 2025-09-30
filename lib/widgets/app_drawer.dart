import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freelenia/dashboard/Dashboard.dart';
import 'package:freelenia/work/assign_work_page.dart';
import 'package:freelenia/work/my_works_page.dart';
import '../notifications/notifications_page.dart';
import '../connections/invitations_page.dart';
import '../auth/auth_wrapper.dart';
import '../auth/login_page.dart';

class AppDrawer extends StatelessWidget {
  final String userRole;
  final String uid; // 👈 add uid

  const AppDrawer({super.key, required this.userRole, required this.uid});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Text(
              "$userRole Menu",
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text("Dashboard"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AuthWrapper()),
              );
            },
          ),

          // ✅ Company/Vendor => Assign Work
          if (userRole == "Company" || userRole == "Vendor")
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text("Assign Work"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignWorkPage(userRole: userRole),
                  ),
                );
              },
            ),

          // ✅ Freelancer => My Works
          if (userRole == "Freelancer")
            ListTile(
              leading: const Icon(Icons.work_history),
              title: const Text("My Works"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyWorksPage(
                      userRole: userRole, // 👈 role directly use
                      uid: uid,           // 👈 uid pass
                      initialStatusFilter: "All",
                    ),
                  ),
                );
              },
            ),

          ListTile(
            leading: const Icon(Icons.mail),
            title: const Text("Invitations"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InvitationsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text("Notifications"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("⚙️ Settings coming soon...")),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
