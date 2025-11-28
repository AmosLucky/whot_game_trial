import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naija_whot_trail/states/auth_state.dart';

import '../../providers/providers.dart';

// ------------- EDIT PROFILE PAGE -----------------
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late TextEditingController fullName;
  late TextEditingController username;
  late TextEditingController phone;
  late TextEditingController email;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user!;
    fullName = TextEditingController(text: user.displayName);
    username = TextEditingController(text: user.username);
    phone = TextEditingController(text: user.phone);
    email = TextEditingController(text: user.email);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.read(authControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: Colors.brown.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProfileCard(
              fullName: fullName.text,
              username: username.text,
              email: email.text,
            ),
            const SizedBox(height: 20),
            CustomField(controller: fullName, label: "Full Name"),
            CustomField(controller: username, label: "Username"),
            CustomField(controller: phone, label: "Phone Number"),
            CustomField(controller: email, label: "Email"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).updateUser({
                  "fullName": fullName.text,
                  "username": username.text,
                  "phone": phone.text,
                  //"email": email.text,
                });
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.brown.shade800,
              ),
              child:
                  authState.isLoading
                      ? CircularProgressIndicator()
                      : Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const CustomField({super.key, required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class ProfileCard extends StatelessWidget {
  final String fullName;
  final String username;
  final String email;
  const ProfileCard({
    super.key,
    required this.fullName,
    required this.username,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 30)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text("@$username", style: const TextStyle(color: Colors.grey)),
                Text(email, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
