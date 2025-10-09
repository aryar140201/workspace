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

  // --- UI Colors & Constants ---
  static const Color darkTeal = Color(0xFF009688);
  static const Color accentBlue = Color(0xFF01217C);
  static const Color lightGreen = Color(0xFF00936F);
  static const Color redError = Color(0xFFEF5350);
  static const Color goldPending = Color(0xFFFFC107);
  static const double horizontalPadding = 15.0;

  // Status color mapping
  final Map<String, Color> statusColors = {
    "Pending": Colors.orangeAccent,
    "In Progress": Colors.blueAccent,
    "Failed": Colors.redAccent,
    "Rework": Colors.deepPurpleAccent,
    "Cancelled": Colors.grey,
    "Paid": Colors.green,
    "Completed": Colors.lightGreen,
  };

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    widget.onNavigate?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = currentUser.uid;

    final pages = [
      _buildHomePage(context, currentUid),
      MyWorksPage(userRole: widget.userRole, uid: currentUid),
      SeeAllConnections(userRole: widget.userRole),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      backgroundColor: Colors.white,
    );
  }

  /// 🔹 Home Page
  Widget _buildHomePage(BuildContext context, String currentUid) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
              horizontalPadding, 45, horizontalPadding, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Freelenia",
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search, color: darkTeal, size: 26),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AuthWrapper(initialIndex: 1)),
                      );
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection("notifications")
                        .where("userId", isEqualTo: currentUid)
                        .where("read", isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int unreadCount = snapshot.hasData ? snapshot.data!.docs
                          .length : 0;
                      return IconButton(
                        icon: badges.Badge(
                          position: badges.BadgePosition.topEnd(
                              top: -4, end: -4),
                          showBadge: unreadCount > 0,
                          badgeContent: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                          badgeStyle: const badges.BadgeStyle(
                            badgeColor: redError,
                            padding: EdgeInsets.all(5),
                            elevation: 0,
                          ),
                          child: const Icon(Icons.notifications_none,
                              color: darkTeal, size: 26),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NotificationsPage()),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Body Content
        Expanded(
          child: Container(
            color: const Color(0xFFF9FAFA),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TEAM & CONNECTIONS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Team & Connections",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            widget.onNavigate?.call(2);
                          },
                          child: const Row(
                            children: [
                              Text(
                                "See All",
                                style: TextStyle(
                                  color: darkTeal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, color: darkTeal,
                                  size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildConnectionsList(currentUid),

                  const SizedBox(height: 30),

                  // --- Responsive Workload + Financials Section ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding),
                    child: FutureBuilder<Map<String, int>>(
                      future: _fetchStats(currentUid),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator(
                                color: darkTeal)),
                          );
                        }

                        var stats = snap.data!;
                        final screenWidth = MediaQuery
                            .of(context)
                            .size
                            .width;
                        final isTabletOrLarger = screenWidth >=
                            600; // ✅ side-by-side for tablet/desktop

                        if (isTabletOrLarger) {
                          // 💻 SIDE-BY-SIDE (for all tablets, including S9 FE portrait or landscape)
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Workload",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _buildMetricsGrid(
                                        context, currentUid, stats,
                                        type: 'workload'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 25),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Financials",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _buildMetricsGrid(
                                        context, currentUid, stats,
                                        type: 'financials'),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          // 📱 STACKED (phones)
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Workload",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildMetricsGrid(
                                  context, currentUid, stats, type: 'workload'),
                              const SizedBox(height: 30),
                              const Text(
                                "Financials",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildMetricsGrid(context, currentUid, stats,
                                  type: 'financials'),
                            ],
                          );
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- ACTIVITY LOG ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding),
                    child: const Text(
                      "Activity Log",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildActivityLogs(currentUid),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 🔹 Connections List (fixed overflow)
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
          return const Center(
              child: CircularProgressIndicator(color: darkTeal));
        }

        var connections = snapshot.data!.docs;
        if (connections.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 20, horizontal: horizontalPadding),
            child: Text(
              "No connections yet.",
              style: Theme
                  .of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.black54),
            ),
          );
        }

        var latestConnections = connections.take(5).toList();

        return SizedBox(
          height: 88, // ✅ increased to avoid RenderFlex overflow
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: horizontalPadding),
            itemCount: latestConnections.length,
            itemBuilder: (context, index) {
              var data = latestConnections[index].data() as Map<String,
                  dynamic>;
              String otherUserId =
              (data["userA"] == currentUid) ? data["userB"] : data["userA"];

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection("users").doc(otherUserId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return _buildConnectionAvatar(
                      context,
                      name: '...',
                      onTap: () {},
                      isPlaceholder: true,
                    );
                  }

                  var userData = userSnap.data!.data() as Map<String, dynamic>;

                  return _buildConnectionAvatar(
                    context,
                    name: userData["name"] ?? "User",
                    profilePicUrl: userData["profilePic"],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ConnectionDetailsPage(userId: otherUserId),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  /// 🔹 Connection Avatar (overflow-safe)
  Widget _buildConnectionAvatar(BuildContext context, {
    required String name,
    String? profilePicUrl,
    required VoidCallback onTap,
    bool isPlaceholder = false,
  }) {
    String initials = name.isNotEmpty
        ? name.split(' ').map((s) => s[0]).join()
        : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min, // ✅ prevent overflow
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: darkTeal.withOpacity(0.5), width: 1),
              ),
              child: CircleAvatar(
                radius: 26, // ✅ reduced from 28
                backgroundColor: isPlaceholder ? Colors.grey[300] : darkTeal
                    .withOpacity(0.1),
                backgroundImage: profilePicUrl != null &&
                    profilePicUrl.isNotEmpty
                    ? NetworkImage(profilePicUrl)
                    : null,
                child: (profilePicUrl == null || profilePicUrl.isEmpty)
                    ? Text(
                  initials,
                  style: const TextStyle(
                    color: darkTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                )
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme
                  .of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black87, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Metrics Grid
  Widget _buildMetricsGrid(BuildContext context,
      String currentUid,
      Map<String, int> stats, {
        required String type,
      }) {
    List<Map<String, dynamic>> metrics = [];

    if (type == 'workload') {
      metrics = [
        {
          "label": "My Assignments",
          "key": "assignedByMe",
          "subtitle": "Assigned By Me",
          "icon": Icons.arrow_circle_up,
          "color": accentBlue.withOpacity(0.8),
          "onTap": () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      WorksListPage(userRole: "Company", uid: currentUid),
                ),
              ),
        },
        {
          "label": "Team Assignments",
          "key": "assignedToMe",
          "subtitle": "Assigned To Me",
          "icon": Icons.arrow_circle_down,
          "color": lightGreen.withOpacity(0.8),
          "onTap": () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MyWorksPage(userRole: widget.userRole, uid: currentUid),
                ),
              ),
        },
      ];
    } else if (type == 'financials') {
      metrics = [
        {
          "label": "Money Out",
          "key": "paymentsToPay",
          "subtitle": "Payments To Pay",
          "isCurrency": true,
          "icon": Icons.account_balance_wallet_outlined,
          "color": redError.withOpacity(0.8),
          "onTap": () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      WorksListPage(
                        userRole: "Company",
                        uid: currentUid,
                        initialStatusFilter: "Completed", // ✅ only show completed works
                      ),
                ),
              ),
        },
        {
          "label": "Money In",
          "key": "paymentsReceived",
          "subtitle": "Payments Receive",
          "isCurrency": true,
          "icon": Icons.attach_money,
          "color": darkTeal.withOpacity(0.8),
          "onTap": () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MyWorksPage(
                        userRole: widget.userRole,
                        uid: currentUid,
                        initialStatusFilter: "Completed", // ✅ only show completed works
                      ),
                ),
              ),
        },
      ];
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.25,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        var m = metrics[index];
        int count = stats[m["key"]] ?? 0;

        return _buildStyledStatCard(
          context,
          label: m["label"],
          subtitle: m["subtitle"],
          count: count,
          color: m["color"],
          icon: m["icon"],
          isCurrency: m["isCurrency"] ?? false,
          onTap: m["onTap"],
        );
      },
    );
  }

  /// 🔹 Responsive & Orientation-Aware Stat Card
  Widget _buildStyledStatCard(BuildContext context, {
    required String label,
    required String subtitle,
    required int count,
    required Color color,
    required IconData icon,
    bool isCurrency = false,
    required VoidCallback onTap,
  }) {
    final valueText = isCurrency ? "₹ $count" : count.toString();
    final size = MediaQuery
        .of(context)
        .size;
    final orientation = MediaQuery
        .of(context)
        .orientation;

    final isTablet = size.width >= 400 && size.width < 900;
    final isWideScreen = size.width >= 1100;
    final isTabletPortrait = isTablet && orientation == Orientation.portrait;

    // Dynamic scaling
    final double fontSizeValue = isWideScreen
        ? 18
        : isTabletPortrait
        ? 24
        : 26;
    final double fontSizeLabel = isWideScreen
        ? 11
        : isTabletPortrait
        ? 12
        : 12;
    final double fontSizeSubtitle = isWideScreen
        ? 10
        : isTabletPortrait
        ? 10
        : 10;
    final double iconSize = isWideScreen
        ? 16
        : isTabletPortrait
        ? 18
        : 18;
    final double padding = isWideScreen
        ? 10
        : isTabletPortrait
        ? 13
        : 14;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: fontSizeLabel,
                    ),
                  ),
                ),
                Icon(icon, color: color, size: iconSize),
              ],
            ),
            const Spacer(),
            Text(
              valueText,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: fontSizeValue,
                height: 1.1,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
                fontSize: fontSizeSubtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 NEW: Activity Log Controller (Replaces _buildCombinedWorkStatus)
  Widget _buildActivityLogs(String currentUid) {
    // Stream for tasks assigned By Me
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("tasks")
          .where("assignedBy", isEqualTo: currentUid)
          .snapshots(),
      builder: (context, assignedBySnapshot) {
        // Stream for tasks assigned To Me
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection("tasks")
              .where("assignedTo", isEqualTo: currentUid)
              .snapshots(),
          builder: (context, assignedToSnapshot) {
            if (!assignedBySnapshot.hasData || !assignedToSnapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: darkTeal));
            }

            var tasksBy = assignedBySnapshot.data!.docs;
            var tasksTo = assignedToSnapshot.data!.docs;

            // Calculate status counts for each group
            Map<String, int> countsBy = _calculateStatusCounts(tasksBy);
            Map<String, int> countsTo = _calculateStatusCounts(tasksTo);

            int failedCountBy = countsBy["Failed"] ?? 0;
            int failedCountTo = countsTo["Failed"] ?? 0;
            int totalFailedCount = failedCountBy + failedCountTo;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: horizontalPadding),
                  child: Text(
                    "Assigned By Me",
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(
                        fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatusScrollList(countsBy, currentUid, "assignedBy"),
                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: horizontalPadding),
                  child: Text(
                    "Assigned To Me",
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(
                        fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatusScrollList(countsTo, currentUid, "assignedTo"),
                if (totalFailedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 20, left: horizontalPadding),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                WorksListPage(
                                  userRole: widget.userRole,
                                  uid: currentUid,
                                  initialStatusFilter: "Failed",
                                ),
                          ),
                        );
                      },
                      child: Text(
                        "$totalFailedCount Total Tasks Failed. View Details >",
                        style: const TextStyle(
                          color: redError,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                          decorationColor: redError,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Helper Functions for Activity Logs ---

  Map<String, int> _calculateStatusCounts(List<QueryDocumentSnapshot> docs) {
    Map<String, int> counts = {};
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      String status = data["status"] ?? "Pending";
      counts.update(status, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Widget _buildStatusScrollList(Map<String, int> statusCounts,
      String currentUid, String assignmentType) {
    List<String> sortedStatuses = statusCounts.keys.toList()
      ..sort((a, b) => _getStatusOrder(a).compareTo(_getStatusOrder(b)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: sortedStatuses.map((status) {
          return Padding(
            padding: const EdgeInsets.only(right: 11.0),
            child: _buildStatusPill(
              status,
              statusCounts[status]!,
              statusColors[status] ?? Colors.blueGrey,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        WorksListPage(
                          userRole: widget.userRole,
                          uid: currentUid,
                          initialStatusFilter: status,
                          // Pass assignmentType to the filter page if it supports it
                          assignmentTypeFilter: assignmentType,
                        ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Helper to define a sorting order for statuses (optional, for consistent display)
  int _getStatusOrder(String status) {
    switch (status) {
      case "Failed":
        return 0;
      case "Pending":
        return 1;
      case "In Progress":
        return 2;
      case "Rework":
        return 3;
      case "Cancelled":
        return 4;
      case "Paid":
        return 5;
      case "Completed":
        return 6;
      default:
        return 99;
    }
  }


  /// 🔹 Helper for Status Pills (More Attractive Design)
  Widget _buildStatusPill(String status, int count, Color color,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // The bottom margin you requested to separate from the next element
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Original unchanged logic ---

  /// 🔹 Fetch statistics — compute total payment amounts from completed works
  Future<Map<String, int>> _fetchStats(String uid) async {
    double totalMoneyOut = 0;
    double totalMoneyIn = 0;

    // ✅ Money Out: sum of all completed tasks assigned by current user
    var assignedByMe = await _firestore
        .collection("tasks")
        .where("assignedBy", isEqualTo: uid)
        .where("status", isEqualTo: "Completed")
        .get();

    for (var doc in assignedByMe.docs) {
      var data = doc.data();
      totalMoneyOut += (data["price"] ?? 0).toDouble(); // ✅ use 'price'
    }

    // ✅ Money In: sum of all completed tasks assigned to current user
    var assignedToMe = await _firestore
        .collection("tasks")
        .where("assignedTo", isEqualTo: uid)
        .where("status", isEqualTo: "Completed")
        .get();

    for (var doc in assignedToMe.docs) {
      var data = doc.data();
      totalMoneyIn += (data["price"] ?? 0).toDouble(); // ✅ use 'price'
    }

    // ✅ Also keep counts for workload
    var allAssignedByMe = await _firestore
        .collection("tasks")
        .where("assignedBy", isEqualTo: uid)
        .get();
    var allAssignedToMe = await _firestore
        .collection("tasks")
        .where("assignedTo", isEqualTo: uid)
        .get();

    return {
      "assignedByMe": allAssignedByMe.docs.length,
      "assignedToMe": allAssignedToMe.docs.length,
      "paymentsToPay": totalMoneyOut.round(), // total ₹ for Money Out
      "paymentsReceived": totalMoneyIn.round(), // total ₹ for Money In
    };
  }
}