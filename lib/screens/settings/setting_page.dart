// ---------------- SETTINGS PAGE -----------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../payment/withdraw_page.dart';
import 'change_password_page.dart';
import 'edit_profile.dart';
import 'sound_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.brown.shade800,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          
          SettingsTile(title: "Edit Profile", icon: Icons.person, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage()))),
SettingsTile(title: "Change Password", icon: Icons.lock, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()))),
SettingsTile(title: "Sound Settings", icon: Icons.volume_up, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoundSettingsPage()))),
SettingsTile(title: "Withdraw", icon: Icons.account_balance_wallet, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WithdrawPage()))),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
final String title;
final IconData icon;
//final IconData icon;
final VoidCallback onTap;
const SettingsTile({super.key, required this.title, required this.icon, required this.onTap}); 
//final String title;
//final VoidCallback onTap;
//const SettingsTile({super.key, required this.title, required this.onTap});


@override
Widget build(BuildContext context) {
return Card(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
elevation: 3,
child: ListTile(
leading: Icon(icon, color: Colors.brown.shade700, size: 26),
title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
trailing: const Icon(Icons.arrow_forward_ios, size: 18),
onTap: onTap,
),
);
}
}
