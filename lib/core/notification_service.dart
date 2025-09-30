import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import '../chat/chat_page.dart';
import '../main.dart';
import '../connections/connection_details.dart';
import '../connections/invitations_page.dart';
import '../core/fcm_sender.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  /// Initialize notifications
  static Future<void> init() async {
    const AndroidInitializationSettings initSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      "high_importance_channel",
      "High Importance Notifications",
      description: "Used for important notifications.",
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            _handleNavigation(Map<String, dynamic>.from(data));
          } catch (e) {
            debugPrint("❌ Payload parse error: $e");
          }
        }
      },
    );

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📩 Foreground: ${message.data}");

      final data = message.data;
      final title =
          data["title"] ?? message.notification?.title ?? "New Notification";
      final body =
          data["body"] ?? message.notification?.body ?? "You have a message";

      showNotification(title, body, data: data);
    });

    // Background / terminated tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📩 OpenedApp: ${message.data}");
      _handleNavigation(message.data);
    });

    // App opened from terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("📩 InitialMessage: ${initialMessage.data}");
      _handleNavigation(initialMessage.data);
    }
  }

  /// Show local popup
  static Future<void> showNotification(
      String title,
      String body, {
        Map<String, dynamic>? data,
      }) async {
    const androidDetails = AndroidNotificationDetails(
      "high_importance_channel",
      "High Importance Notifications",
      channelDescription: "Used for important notifications.",
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  /// 🔹 Central navigation handler
  static void _handleNavigation(Map<String, dynamic> data) async {
    if (data.isEmpty) return;

    debugPrint("➡️ Handling navigation for: $data");

    final type = data["type"];
    final connectionId = data["connectionId"];
    final requestId = data["notifId"] ?? data["requestId"];
    final fromUser = data["fromUser"];

    switch (type) {
      case "WorkAssigned":
        if (fromUser != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ConnectionDetailsPage(userId: fromUser),
            ),
          );
        }
        break;

      case "ConnectionRequest":
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const InvitationsPage()),
        );
        break;

      case "RemoveRequest":
        if (connectionId != null && requestId != null) {
          _showRemoveDialog(connectionId, requestId, fromUser ?? "");
        }
        break;

      case "RemoveApproved":
      case "RemoveRejected":
        _showInfoDialog(
          type == "RemoveApproved" ? "Connection Removed" : "Request Rejected",
          type == "RemoveApproved"
              ? "✅ Your connection removal request was approved."
              : "❌ Your connection removal request was rejected.",
        );
        break;

      case "NewMessage":
        final otherUserId = fromUser;
        final otherUserName = data["fromName"] ?? "Chat";
        final otherUserPic = data["fromPic"];

        if (otherUserId != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                otherUserId: otherUserId,
                otherUserName: otherUserName,
                otherUserPic: otherUserPic,
              ),
            ),
          );
        } else {
          _showInfoDialog("New Message", "💬 You received a new message.");
        }
        break;

      default:
        debugPrint("ℹ️ Unknown notification type: $type");
    }
  }

  /// Info dialog
  static void _showInfoDialog(String title, String message) {
    final ctx = navigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;

    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  /// Removal confirmation popup
  static void _showRemoveDialog(
      String connectionId,
      String requestId,
      String fromUser,
      ) {
    final ctx = navigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Remove Connection Request"),
        content: const Text(
          "The other user has requested to remove this connection. Do you agree?",
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _updateRemovalRequest(
                requestId,
                "rejected",
                fromUser,
                connectionId,
                notifyTitle: "Request Rejected",
                notifyBody: "❌ Your connection removal request was rejected.",
                notifyType: "RemoveRejected",
              );
              Navigator.of(context).pop();
            },
            child: const Text("Reject"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection("connections")
                    .doc(connectionId)
                    .delete();

                await _updateRemovalRequest(
                  requestId,
                  "approved",
                  fromUser,
                  connectionId,
                  notifyTitle: "Connection Removed",
                  notifyBody: "✅ Your removal request has been approved.",
                  notifyType: "RemoveApproved",
                );

                navigatorKey.currentState?.pushNamedAndRemoveUntil(
                  "/dashboard",
                      (route) => false,
                );
              } catch (e) {
                debugPrint("❌ Approve error: $e");
              } finally {
                Navigator.of(context).pop();
              }
            },
            child: const Text("Remove"),
          ),
        ],
      ),
    );
  }

  /// Update Firestore + notify requester
  static Future<void> _updateRemovalRequest(
      String requestId,
      String status,
      String fromUser,
      String connectionId, {
        required String notifyTitle,
        required String notifyBody,
        required String notifyType,
      }) async {
    try {
      await FirebaseFirestore.instance
          .collection("removalRequests")
          .doc(requestId)
          .update({"status": status});

      final requester =
      await FirebaseFirestore.instance.collection("users").doc(fromUser).get();

      final token = requester.data()?["fcmToken"];
      if (token != null && token.toString().isNotEmpty) {
        await FcmSender.sendPushMessage(
          targetToken: token,
          title: notifyTitle,
          body: notifyBody,
          notifId: requestId,
          fromUser: fromUser,
          type: notifyType,
          connectionId: connectionId,
        );
      }
    } catch (e) {
      debugPrint("❌ _updateRemovalRequest error: $e");
    }
  }

  /// Get FCM device token
  static Future<String?> getToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint("🔑 Device FCM Token: $token");
      return token;
    } catch (e) {
      debugPrint("❌ Error getting token: $e");
      return null;
    }
  }
}
