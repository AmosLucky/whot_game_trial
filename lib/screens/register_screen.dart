// lib/screens/register_screen.dart
//
// Registration screen UI that collects fullname, username, email, phone, avatar (choose default), password.
// Uses AuthService to create user, creates Firestore doc and attempts MySQL sync via the server.
//
// NOTE: Update the AuthService instance provider or construct it with your MySQL endpoint.

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService authService;
  const RegisterScreen({super.key, required this.authService});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullnameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  String _error = '';

  // You can replace this default avatar with any free image url or local asset.
  final String _defaultAvatarUrl = 'https://i.imgur.com/BoN9kdC.png';

  @override
  void dispose() {
    _fullnameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = '';
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final fullname = _fullnameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;

    final result = await widget.authService.registerWithEmail(
      fullname: fullname,
      username: username,
      email: email,
      phone: phone,
      password: password,
      avatarUrl: _defaultAvatarUrl,
    );

    setState(() => _isLoading = false);

    if (result.success) {
      // Registration successful - navigate to home screen
      // Replace with your route logic; you might want to pushReplacement to home.
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _error = result.message ?? 'Registration failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register - Naija Whot'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: NetworkImage(_defaultAvatarUrl),
            ),
            const SizedBox(height: 12),
            Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _fullnameCtrl,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter full name' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter username' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter email';
                        if (!v.contains('@')) return 'Enter valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter phone' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 6) ? 'Password min 6 chars' : null,
                    ),
                    const SizedBox(height: 16),
                    if (_error.isNotEmpty)
                      Text(_error, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading ? const CircularProgressIndicator() : const Text('Register'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
                      child: const Text('Already have an account? Login'),
                    )
                  ],
                )),
          ],
        ),
      ),
    );
  }
}
