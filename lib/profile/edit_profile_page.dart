import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart'; // ✅ our service

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _extraController = TextEditingController();

  String _email = "";
  String? _profileUrl;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    for (final c in [_nameController, _phoneController, _extraController]) {
      c.addListener(() => setState(() => _dirty = true));
    }
  }

  Future<void> _loadUser() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection("users").doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data["name"] ?? "";
      _phoneController.text = data["phone"] ?? "";
      _extraController.text = data["extraInfo"] ?? "";
      _email = data["email"] ?? _auth.currentUser?.email ?? "";
      _profileUrl = data["profilePic"];
    }
    setState(() => _loading = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    setState(() => _saving = true);

    final uid = _auth.currentUser!.uid;
    final file = File(picked.path);

    // ✅ Upload new + delete old
    final newUrl = await StorageService().uploadProfileImage(
      uid: uid,
      file: file,
      oldUrl: _profileUrl,
    );

    if (newUrl != null) {
      // 🔹 Save immediately in Firestore
      await _firestore.collection("users").doc(uid).update({
        "profilePic": newUrl,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      setState(() {
        _profileUrl = newUrl;
        _dirty = true; // now profile is updated
      });
    }

    setState(() => _saving = false);
  }

  Future<void> _removeProfileImage() async {
    if (_profileUrl == null) return;
    setState(() => _saving = true);

    final uid = _auth.currentUser!.uid;

    // ✅ Delete from Firebase Storage
    await StorageService().deleteFile(_profileUrl!);

    // ✅ Also clear in Firestore
    await _firestore.collection("users").doc(uid).update({
      "profilePic": FieldValue.delete(),
      "updatedAt": FieldValue.serverTimestamp(),
    });

    setState(() {
      _profileUrl = null;
      _dirty = true;
      _saving = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final uid = _auth.currentUser!.uid;

    await _firestore.collection("users").doc(uid).update({
      "name": _nameController.text.trim(),
      "phone": _phoneController.text.trim(),
      "extraInfo": _extraController.text.trim(),
      "profilePic": _profileUrl,
      "email": _email,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated ✅")),
    );
    Navigator.pop(context);
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text("Choose from Gallery"),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("Take a Photo"),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
          ),
          if (_profileUrl != null)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Remove Picture"),
              onTap: () {
                Navigator.pop(ctx);
                _removeProfileImage();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundImage: _profileUrl != null
                        ? NetworkImage(_profileUrl!)
                        : const AssetImage("assets/default_avatar.png")
                    as ImageProvider,
                    onBackgroundImageError: (_, __) {
                      setState(() => _profileUrl = null);
                    },
                    child: _profileUrl == null
                        ? const Icon(Icons.person,
                        size: 40, color: Colors.white70)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _showImagePickerSheet,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _field(_nameController, "Full Name", Icons.person),
                  const SizedBox(height: 15),
                  _field(_phoneController, "Phone", Icons.phone,
                      keyboard: TextInputType.phone),
                  const SizedBox(height: 15),
                  _readOnly("Email", _email, Icons.email),
                  const SizedBox(height: 15),
                  _field(_extraController, "Address / Skills", Icons.notes,
                      maxLines: 3),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_saving || !_dirty) ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)
                    : const Text("Save Changes",
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: (v) =>
      (v == null || v.trim().isEmpty) ? "Enter $label" : null,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _readOnly(String label, String value, IconData icon) {
    return TextFormField(
      readOnly: true,
      initialValue: value,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
