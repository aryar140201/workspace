import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentsPage extends StatelessWidget {
  final String userRole;
  const PaymentsPage({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("💰 Payments"),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("tasks").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var tasks =
          snapshot.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();

          double total = 0;
          Map<String, double> breakdown = {};

          for (var task in tasks) {
            if (task["status"] == "Completed") {
              // use correct field (price instead of amount)
              double amt = (task["price"] ?? 0).toDouble();

              if (userRole == "Freelancer" && task["assignedTo"] == uid) {
                total += amt;
                String company = task["assignedBy"];
                breakdown[company] = (breakdown[company] ?? 0) + amt;
              } else if ((userRole == "Company" || userRole == "Vendor") &&
                  task["assignedBy"] == uid) {
                total += amt;
                String freelancer = task["assignedTo"];
                breakdown[freelancer] = (breakdown[freelancer] ?? 0) + amt;
              }
            }
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Summary Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                    ),
                    title: Text(
                      userRole == "Freelancer"
                          ? "Total Earnings"
                          : "Total Payments Due",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      "₹${total.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 🔹 Breakdown header
                Text(
                  userRole == "Freelancer"
                      ? "Breakdown by Company/Vendor"
                      : "Breakdown by Freelancer",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),

                // 🔹 Breakdown List
                Expanded(
                  child: breakdown.isEmpty
                      ? const Center(
                    child: Text("No completed payments yet."),
                  )
                      : ListView(
                    children: breakdown.entries.map((entry) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection("users")
                            .doc(entry.key)
                            .get(),
                        builder: (context, userSnap) {
                          String name = entry.key;
                          if (userSnap.hasData && userSnap.data!.exists) {
                            var uData = userSnap.data!.data() as Map<String, dynamic>;
                            name = uData["name"] ?? entry.key;
                          }
                          return Card(
                            margin:
                            const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                            elevation: 2,
                            child: ListTile(
                              leading: const Icon(Icons.person, color: Colors.blue),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              trailing: Text(
                                "₹${entry.value.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
