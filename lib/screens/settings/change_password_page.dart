import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import 'edit_profile.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final oldPassController = TextEditingController();
  final newPassController = TextEditingController();
  final confirmPassController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    oldPassController.dispose();
    newPassController.dispose();
    confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
        backgroundColor: Colors.brown.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CustomField(
                controller: oldPassController,
                label: "Old Password",
                obscureText: true,
                validator: (val) =>
                    val == null || val.isEmpty ? "Please enter old password" : null,
              ),
              CustomField(
                controller: newPassController,
                label: "New Password",
                obscureText: true,
                validator: (val) =>
                    val == null || val.isEmpty ? "Please enter new password" : null,
              ),
              CustomField(
                controller: confirmPassController,
                label: "Confirm Password",
                obscureText: true,
                validator: (val) {
                  if (val == null || val.isEmpty) return "Please confirm new password";
                  if (val != newPassController.text) return "Passwords do not match";
                  return null;
                },
              ),
              const SizedBox(height: 20),
              authState.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          await ref.read(authControllerProvider.notifier).changePassword(
                                oldPassword: oldPassController.text.trim(),
                                newPassword: newPassController.text.trim(),
                                confirmPassword: confirmPassController.text.trim(),
                              );

                          
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.brown.shade800,
                      ),
                      child: const Text("Update Password"),
                    ),
              if (authState.error != null) ...[
                const SizedBox(height: 16),
                Text(authState.error!, style: const TextStyle(color: Colors.red)),
              ]
            ],
          ),
        ),
      ),
    );
  }


}


class CustomField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final String? Function(String?)? validator;

  const CustomField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

