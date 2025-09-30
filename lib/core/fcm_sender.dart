import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class FcmSender {
  static const String serviceAccountPath = 'assets/service_account.json';

  static String? _cachedAccessToken;
  static DateTime? _expiryTime;
  static String? _projectId;

  /// 🔑 Get OAuth2 access token (cached)
  static Future<String> _getAccessToken() async {
    if (_cachedAccessToken != null &&
        _expiryTime != null &&
        DateTime.now().isBefore(_expiryTime!)) {
      return _cachedAccessToken!;
    }

    final jsonString = await rootBundle.loadString(serviceAccountPath);
    final credentials =
    ServiceAccountCredentials.fromJson(json.decode(jsonString));
    const scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    final client = await clientViaServiceAccount(credentials, scopes);

    _cachedAccessToken = client.credentials.accessToken.data;
    _expiryTime = client.credentials.accessToken.expiry;
    _projectId = (json.decode(jsonString)["project_id"]).toString();

    client.close();
    return _cachedAccessToken!;
  }

  /// 📩 Send push notification
  static Future<bool> sendPushMessage({
    required String targetToken,
    required String title,
    required String body,
    required String notifId, // Firestore notification docId
    required String fromUser, // sender uid
    String type = "General", // e.g. ConnectionRequest, NewMessage
    String? connectionId,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final accessToken = await _getAccessToken();

      final url = Uri.parse(
        "https://fcm.googleapis.com/v1/projects/$_projectId/messages:send",
      );

      // 🔹 Data payload
      final payloadData = {
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "notifId": notifId,
        "fromUser": fromUser,
        "type": type,
        "title": title,
        "body": body,
        if (connectionId != null) "connectionId": connectionId,
        ...?extraData,
      };

      // Avoid reserved keys
      final reserved = {"from", "notification", "message_id"};
      for (final key in reserved) {
        if (payloadData.containsKey(key)) {
          final value = payloadData[key];
          payloadData.remove(key);
          payloadData["senderId"] = value;
        }
      }

      final message = {
        "message": {
          "token": targetToken,
          "notification": {
            "title": title,
            "body": body,
          },
          "data": payloadData,
          "android": {
            "priority": "high",
            "notification": {
              "click_action": "FLUTTER_NOTIFICATION_CLICK",
              "channel_id": "high_importance_channel",
              "sound": "default",
            }
          },
          "apns": {
            "payload": {
              "aps": {
                "alert": {"title": title, "body": body},
                "sound": "default",
                "badge": 1
              }
            }
          }
        }
      };

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        print("Push sent: ${response.body}");
        return true;
      } else {
        print("Push error: ${response.statusCode} ${response.body}");
        return false;
      }
    } catch (e) {
      print("Exception while sending push: $e");
      return false;
    }
  }
}
