import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/auth_controller.dart';
import '../../providers/providers.dart';
import '../../states/auth_state.dart';
import '../../widgets/image_background.dart';

// Simple Riverpod state for loading
// final loginLoadingProvider = StateProvider<bool>((ref) => false);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
  

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authControllerProvider.notifier).login(email: _emailCtrl.text, 
    password: _passwordCtrl.text);

   
  }

  @override
  Widget build(BuildContext context) {
    //final isLoading = ref.watch(loginLoadingProvider);
        final authState = ref.watch(authControllerProvider);

  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (next.isSuccess) {
      // Navigate to home screen after success
      Navigator.pushReplacementNamed(context, '/home');
    } else if (next.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(next.error!)));
    }
    ref.read(authControllerProvider.notifier).reset();
    
  });

    return Scaffold(
      // /backgroundColor: const Color(0xFF5B2020),
      body: ImageBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Card(
              color: Colors.white.withAlpha(90),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image.asset(
                    //   'assets/logo.png', // replace with your logo
                    //   height: 80,
                    // ),
                    const SizedBox(height: 16),
                    Text(
                      'Login',
                      style: TextStyle(
                        fontFamily: 'StackSans',
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(_emailCtrl, 'Email',
                              keyboardType: TextInputType.emailAddress),
                          _buildTextField(_passwordCtrl, 'Password',
                              obscureText: true),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: authState.isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5B2020),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: authState.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontFamily: 'StackSans',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context)
                                  .pushReplacementNamed('/register');
                            },
                            child: const Text(
                              'Don\'t have an account? Register',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'StackSans'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscureText = false,
      TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black, fontFamily: 'StackSans'),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: Color(0xFF5B2020), fontFamily: 'StackSans'),
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Enter $label';
          if (label == 'Email' && !v.contains('@')) return 'Enter valid email';
          if (label == 'Password' && v.length < 6) return 'Password min 6 chars';
          return null;
        },
      ),
    );
  }
}
