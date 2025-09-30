import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../dashboard/Dashboard.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _extraController = TextEditingController();

  String _role = "Freelancer";
  String _message = "";
  bool _loading = false;

  /// 🔑 Unique ID Generator
  String generateUniqueId(String role) {
    String prefix = role.substring(0, 3).toUpperCase();
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    String randomPart = List.generate(
      6,
          (i) => chars[(DateTime.now().millisecondsSinceEpoch + i) % chars.length],
    ).join();
    return "$prefix-$randomPart";
  }

  /// 🔥 Save FCM Token
  Future<void> _saveFcmToken(String uid) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection("users").doc(uid).update({
          "fcmToken": token,
        });

        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          await _firestore.collection("users").doc(uid).update({
            "fcmToken": newToken,
          });
        });
      }
    } catch (e) {
      debugPrint("Error saving FCM token: $e");
    }
  }

  /// ✅ Password Validator
  bool _isPasswordValid(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*[\d!@#\$&*~]).{6,}$');
    return regex.hasMatch(password);
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _message = "";
    });

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      setState(() {
        _message = "Passwords do not match";
        _loading = false;
      });
      return;
    }

    if (!_isPasswordValid(_passwordController.text.trim())) {
      setState(() {
        _message =
        "Password must contain:\n- 1 uppercase\n- 1 lowercase\n- 1 number/symbol\n- min 6 characters";
        _loading = false;
      });
      return;
    }

    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String newId = generateUniqueId(_role);

      await _firestore.collection("users").doc(userCred.user!.uid).set({
        "uid": userCred.user!.uid,
        "uniqueId": newId,
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "role": _role,
        "extraInfo": _extraController.text.trim(),
        "connections": [],
        "fcmToken": null,
      });

      await _saveFcmToken(userCred.user!.uid);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Dashboard(userRole: _role),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _message = "${e.message}");
    } catch (e) {
      setState(() => _message = "Unexpected error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.deepPurple),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 6,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_alt_1,
                      size: 60, color: Colors.deepPurple),
                  const SizedBox(height: 10),
                  const Text(
                    "Create Your Account",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 25),

                  TextField(
                    controller: _nameController,
                    decoration: _inputDecoration("Full Name", Icons.person),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: _inputDecoration("Email", Icons.email),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _inputDecoration("Password", Icons.lock),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration:
                    _inputDecoration("Confirm Password", Icons.lock_outline),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _role,
                    items: ["Freelancer", "Company"]
                        .map((r) =>
                        DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) => setState(() => _role = val!),
                    decoration: _inputDecoration("Select Role", Icons.work),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _extraController,
                    decoration: _inputDecoration(
                        _role == "Company" ? "Company Name" : "Skills",
                        Icons.info),
                  ),
                  const SizedBox(height: 20),

                  // Gradient Button
                  // 🔹 Gradient Button
                  _loading
                      ? const CircularProgressIndicator()
                      : Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.deepPurple, Colors.purpleAccent],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white, // ✅ Text & icon color to white
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 20,
                        ),
                      ),
                      onPressed: _register,
                      child: const Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // ✅ ensure text stays white
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (_message.isNotEmpty)
                    Text(
                      _message,
                      style: TextStyle(
                        color: _message.startsWith("✅")
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
