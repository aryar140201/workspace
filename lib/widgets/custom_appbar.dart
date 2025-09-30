import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.onSearch,
    required this.onNotifications,
  });

  /// 🔹 Firestore unread notifications count
  Stream<int> unreadNotificationsCount() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream<int>.empty();

    return FirebaseFirestore.instance
        .collection("notifications")
        .where("userId", isEqualTo: uid)
        .where("read", isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontFamily: "Arial",
        ),
      ),
      automaticallyImplyLeading: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black),
          onPressed: onSearch,
        ),

        /// ✅ Notification badge same as AuthWrapper
        StreamBuilder<int>(
          stream: unreadNotificationsCount(),
          builder: (context, snapshot) {
            int count = snapshot.data ?? 0;
            return badges.Badge(
              showBadge: count > 0,
              badgeContent: Text(
                count.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              position: badges.BadgePosition.topEnd(top: -4, end: -4),
              child: IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.black),
                onPressed: onNotifications,
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
