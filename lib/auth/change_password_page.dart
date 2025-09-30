import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _auth = FirebaseAuth.instance;

  bool _loading = false;

  Future<void> _changePassword() async {
    setState(() => _loading = true);
    try {
      User? user = _auth.currentUser;

      if (user != null && user.email != null) {
        // ✅ Step 1: Reauthenticate
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _oldPassword.text.trim(),
        );

        await user.reauthenticateWithCredential(credential);

        // ✅ Step 2: Update Password
        await user.updatePassword(_newPassword.text.trim());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Password updated successfully")),
        );
        Navigator.pop(context); // go back
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _oldPassword,
              decoration: const InputDecoration(
                labelText: "Old Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPassword,
              decoration: const InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text("Update Password"),
            ),
          ],
        ),
      ),
    );
  }
}
