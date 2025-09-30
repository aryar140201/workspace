import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/login_page.dart';
import 'auth/auth_wrapper.dart'; // 👈 AuthWrapper import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _navigate();
  }

  // /// 🔥 Save FCM Token to Firestore
  // Future<void> _saveFcmToken(String uid) async {
  //   try {
  //     String? token = await FirebaseMessaging.instance.getToken();
  //     if (token != null) {
  //       await FirebaseFirestore.instance.collection("users").doc(uid).update({
  //         "fcmToken": token,
  //       });
  //
  //       // 🔄 Keep token fresh
  //       FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
  //         await FirebaseFirestore.instance
  //             .collection("users")
  //             .doc(uid)
  //             .update({"fcmToken": newToken});
  //       });
  //     }
  //   } catch (e) {
  //     debugPrint("❌ Error saving FCM token: $e");
  //   }
  // }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2)); // splash delay
    final user = _auth.currentUser;

    if (user == null) {
      // 🔹 Not logged in → LoginPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      // await _saveFcmToken(user.uid);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6A11CB),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ App Logo
              Image.asset(
                "assets/freelenia_splash.png",
                height: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              const Text(
                "Freelenia",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
