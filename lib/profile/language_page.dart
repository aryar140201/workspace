import 'package:flutter/material.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  String _selectedLang = "English";

  final languages = ["English", "हिंदी", "Español", "Français"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Language"),
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
      body: ListView(
        children: languages.map((lang) {
          return RadioListTile(
            title: Text(lang),
            value: lang,
            groupValue: _selectedLang,
            onChanged: (val) {
              setState(() => _selectedLang = val.toString());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("✅ Language set to $val")),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
