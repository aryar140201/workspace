import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_wrapper.dart';
import '../connections/connection_details.dart';
import '../connections/see_all_connections.dart';
import '../notifications/notifications_page.dart';
import '../work/works_list_page.dart';
import '../work/my_works_page.dart';
import '../profile/profile_page.dart';

class Dashboard extends StatefulWidget {
  final String userRole;
  final Function(int)? onNavigate;
  const Dashboard({
    super.key,
    required this.userRole,
    this.onNavigate,
  });


  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentUid = currentUser.uid;

    final pages = [
      _buildHomePage(context, currentUid), // existing dashboard content
      MyWorksPage(userRole: widget.userRole, uid: currentUid), // My Works
      SeeAllConnections(userRole: widget.userRole), // Connections
      const ProfilePage(),
    ];
    return Scaffold(
      body: pages[_selectedIndex],
      backgroundColor: Colors.white,
    // );

    // return Scaffold(
    //   body: pages[_selectedIndex],
    //   backgroundColor: Colors.white,
    //   bottomNavigationBar: BottomNavigationBar(
    //     currentIndex: _selectedIndex,
    //     onTap: (i) => setState(() => _selectedIndex = i),
    //     items: const [
    //       BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Home"),
    //       BottomNavigationBarItem(icon: Icon(Icons.work), label: "My Works"),
    //       BottomNavigationBarItem(icon: Icon(Icons.people), label: "Connections"),
    //       BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
    //     ],
    //   ),
    );
  }

  /// 🔹 Home Page (Dashboard content)
  Widget _buildHomePage(BuildContext context, String currentUid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 🔹 Gradient Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 50),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.grey.shade900, Colors.black]
                  : [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side text
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome Back 👋",
                      style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.white70,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text("Dashboard",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),

              // Right side icons
              Row(
                children: [
                  // 🔍 Search Button
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AuthWrapper(initialIndex: 1),
                        ),
                      );
                    },
                  ),

                  // 🔔 Notifications with Badge
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection("notifications")
                        .where("userId", isEqualTo: currentUid)
                        .where("read", isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int unreadCount =
                      snapshot.hasData ? snapshot.data!.docs.length : 0;

                      return IconButton(
                        icon: badges.Badge(
                          position: badges.BadgePosition.topEnd(top: -6, end: -6),
                          showBadge: unreadCount > 0,
                          badgeContent: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                          child: const Icon(Icons.notifications_none,
                              color: Colors.white),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsPage(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              )
            ],
          ),
        ),

        // 🔹 Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- CONNECTIONS SECTION ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Connections",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SeeAllConnections(userRole: widget.userRole),
                          ),
                        );
                      },
                      child: const Text("See All →"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildConnectionsList(currentUid),

                const SizedBox(height: 20),

                // --- STATISTICS SECTION ---
                Text("Statistics",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                FutureBuilder<Map<String, int>>(
                  future: _fetchStats(currentUid),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const CircularProgressIndicator();
                    }
                    var stats = snap.data!;
                    return Column(
                      children: [
                        _buildStatCard("Assigned By Me",
                            stats["assignedByMe"] ?? 0, Colors.blue, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WorksListPage(
                                    userRole: "Company",
                                    uid: currentUid,
                                  ),
                                ),
                              );
                            }),
                        _buildStatCard("Assigned To Me",
                            stats["assignedToMe"] ?? 0, Colors.orange, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MyWorksPage(
                                    userRole: widget.userRole,
                                    uid: currentUid,
                                    initialStatusFilter: null,
                                  ),
                                ),
                              );
                            }),
                        _buildStatCard("Payments To Pay",
                            stats["paymentsToPay"] ?? 0, Colors.red, () {}),
                        _buildStatCard("Payments Received",
                            stats["paymentsReceived"] ?? 0, Colors.green, () {}),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // --- WORK STATUS SECTION ---
                Text("Work Status (Assigned By Me)",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _buildWorkStatusRow(currentUid, "assignedBy"),

                const SizedBox(height: 20),
                Text("Work Status (Assigned To Me)",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _buildWorkStatusRow(currentUid, "assignedTo"),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 🔹 Connections widget
  Widget _buildConnectionsList(String currentUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("connections")
          .where(
        Filter.or(
          Filter("userA", isEqualTo: currentUid),
          Filter("userB", isEqualTo: currentUid),
        ),
      )
          .where("status", isEqualTo: "Connected")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var connections = snapshot.data!.docs;
        if (connections.isEmpty) {
          return Text("No connections yet.",
              style: Theme.of(context).textTheme.bodyMedium);
        }

        var latestConnections = connections.take(5).toList();

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: latestConnections.length,
            itemBuilder: (context, index) {
              var data =
              latestConnections[index].data() as Map<String, dynamic>;
              String otherUserId =
              (data["userA"] == currentUid) ? data["userB"] : data["userA"];

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection("users").doc(otherUserId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  var userData =
                  userSnap.data!.data() as Map<String, dynamic>;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ConnectionDetailsPage(userId: otherUserId),
                        ),
                      );
                    },
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: userData["profilePic"] != null
                                ? NetworkImage(userData["profilePic"])
                                : const AssetImage("assets/default_avatar.png")
                            as ImageProvider,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            userData["name"] ?? "Unknown",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  /// 🔹 Fetch statistics
  Future<Map<String, int>> _fetchStats(String uid) async {
    var assignedByMe = await _firestore
        .collection("tasks")
        .where("assignedBy", isEqualTo: uid)
        .get();
    var assignedToMe = await _firestore
        .collection("tasks")
        .where("assignedTo", isEqualTo: uid)
        .get();
    var paymentsToPay = await _firestore
        .collection("payments")
        .where("fromUser", isEqualTo: uid)
        .get();
    var paymentsReceived = await _firestore
        .collection("payments")
        .where("toUser", isEqualTo: uid)
        .get();

    return {
      "assignedByMe": assignedByMe.docs.length,
      "assignedToMe": assignedToMe.docs.length,
      "paymentsToPay": paymentsToPay.docs.length,
      "paymentsReceived": paymentsReceived.docs.length,
    };
  }

  /// 🔹 Build Stat Card
  Widget _buildStatCard(
      String label, int count, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.analytics, color: color),
        ),
        title: Text(label),
        trailing: Text(count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        onTap: onTap,
      ),
    );
  }

  /// 🔹 Build Work Status Row
  Widget _buildWorkStatusRow(String currentUid, String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("tasks")
          .where(type, isEqualTo: currentUid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const CircularProgressIndicator();
        }

        var tasks = snap.data!.docs.map((d) {
          var data = d.data() as Map<String, dynamic>;
          return data["status"] ?? "Pending";
        }).toList();

        Map<String, int> statusCounts = {
          "Pending": 0,
          "In Progress": 0,
          "Failed": 0,
          "Rework": 0,
          "Cancelled": 0,
          "Paid": 0,
          "Completed": 0,
        };

        for (var s in tasks) {
          if (statusCounts.containsKey(s)) {
            statusCounts[s] = statusCounts[s]! + 1;
          }
        }

        final statusList = statusCounts.entries.toList();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: statusList.map((entry) {
              return GestureDetector(
                onTap: () {
                  if (type == "assignedBy") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorksListPage(
                          userRole: widget.userRole,
                          uid: currentUid,
                          initialStatusFilter: entry.key,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyWorksPage(
                          userRole: widget.userRole,
                          uid: currentUid,
                          initialStatusFilter: entry.key,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(entry.key,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(entry.value.toString(),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
