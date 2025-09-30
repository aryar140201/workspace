import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'notifications/notifications_page.dart';
import 'splash_screen.dart';
import 'core/notification_service.dart';
import 'chat/chat_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 🔹 FCM Background Handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint("📩 [Background] Message: ${message.data}");

  if (message.notification != null) {
    await NotificationService.showNotification(
      message.notification!.title ?? "New Notification",
      message.notification!.body ?? "",
      data: message.data,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  setupFcmListeners();

  // ✅ Handle notification when app launched from terminated state
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    Future.microtask(() => _handleMessage(initialMessage));
  }

  runApp(const MyApp());
}

/// 🔹 Custom Scroll Behavior
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode
          ? ThemeData.dark(useMaterial3: true).copyWith(
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      )
          : ThemeData.light(useMaterial3: true).copyWith(
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      scrollBehavior: MyCustomScrollBehavior(),
      home: const SplashScreen(),
    );
  }
}

/// 🔹 FCM Listeners
void setupFcmListeners() {
  // Foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint("📩 [Foreground] Message: ${message.data}");

    if (message.notification != null) {
      await NotificationService.showNotification(
        message.notification!.title ?? "New Notification",
        message.notification!.body ?? "",
        data: message.data,
      );
    }
  });

  // App opened via notification tap (background/resumed)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    debugPrint("📩 [OpenedApp] Message: ${message.data}");
    _handleMessage(message);
  });
}

/// 🔹 Centralized Message Handler
Future<void> _handleMessage(RemoteMessage message) async {
  try {
    final type = message.data["type"];
    final ctx = navigatorKey.currentContext;

    switch (type) {
      case "ConnectionRequest":
        final fromUser = message.data["fromUser"];
        final notifId = message.data["notifId"];
        if (fromUser == null || notifId == null) return;

        navigatorKey.currentState
            ?.push(MaterialPageRoute(builder: (_) => const NotificationsPage()))
            .then((_) async {
          await Future.delayed(const Duration(milliseconds: 300));
          if (ctx == null) return;

          showDialog(
            context: ctx,
            builder: (context) => AlertDialog(
              title: const Text("Connection Request"),
              content: const Text("Do you want to accept this connection?"),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      var conn = await FirebaseFirestore.instance
                          .collection("connections")
                          .where("userA", isEqualTo: fromUser)
                          .where("userB",
                          isEqualTo:
                          FirebaseAuth.instance.currentUser!.uid)
                          .where("status", isEqualTo: "Pending")
                          .get();

                      for (var doc in conn.docs) {
                        await doc.reference.update({"status": "Connected"});
                      }

                      await FirebaseFirestore.instance
                          .collection("notifications")
                          .doc(notifId)
                          .update({"status": "Accepted"});

                      Navigator.pop(context);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text("✅ Connection Accepted")),
                      );
                    } catch (e) {
                      debugPrint("❌ Error accepting request: $e");
                    }
                  },
                  child: const Text("Accept"),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      var conn = await FirebaseFirestore.instance
                          .collection("connections")
                          .where("userA", isEqualTo: fromUser)
                          .where("userB",
                          isEqualTo:
                          FirebaseAuth.instance.currentUser!.uid)
                          .where("status", isEqualTo: "Pending")
                          .get();

                      for (var doc in conn.docs) {
                        await doc.reference.update({"status": "Rejected"});
                      }

                      await FirebaseFirestore.instance
                          .collection("notifications")
                          .doc(notifId)
                          .update({"status": "Rejected"});

                      Navigator.pop(context);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text("❌ Connection Rejected")),
                      );
                    } catch (e) {
                      debugPrint("❌ Error rejecting request: $e");
                    }
                  },
                  child: const Text("Reject"),
                ),
              ],
            ),
          );
        });
        break;

      case "RemoveRequest":
        if (ctx == null) return;
        showDialog(
          context: ctx,
          builder: (_) => AlertDialog(
            title: const Text("Removal Request"),
            content: const Text("A user requested to remove your connection."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        break;

      case "NewMessage":
        final otherUserId = message.data["fromUser"];
        final otherUserName = message.data["fromName"] ?? "Unknown";

        if (otherUserId == null) return;

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ChatPage(
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              otherUserPic: message.data["fromPic"],
            ),
          ),
        );
        break;

      default:
        debugPrint("ℹ️ Unknown notification type: $type");
    }
  } catch (e) {
    debugPrint("❌ _handleMessage error: $e");
  }
}
