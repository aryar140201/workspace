import 'package:flutter/material.dart';


class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  bool pushNotif = true;
  bool emailNotif = false;
  bool smsNotif = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notification Preferences"),
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
        children: [
          SwitchListTile(
            title: const Text("Push Notifications"),
            value: pushNotif,
            onChanged: (val) => setState(() => pushNotif = val),
          ),
          SwitchListTile(
            title: const Text("Email Notifications"),
            value: emailNotif,
            onChanged: (val) => setState(() => emailNotif = val),
          ),
          SwitchListTile(
            title: const Text("SMS Notifications"),
            value: smsNotif,
            onChanged: (val) => setState(() => smsNotif = val),
          ),
        ],
      ),
    );
  }
}
