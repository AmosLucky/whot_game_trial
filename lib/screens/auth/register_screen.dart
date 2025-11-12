import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naija_whot_trail/screens/auth/login_screen.dart';
import 'package:naija_whot_trail/widgets/image_background.dart';

import '../../controllers/auth_controller.dart';
import '../../providers/providers.dart';
import '../../states/auth_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullnameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();


  @override
  void dispose() {
    _fullnameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    //Here you can call your Riverpod provider to handle registration
    //Example:
    ref.read(authControllerProvider.notifier).register(
    fullname:   _fullnameCtrl.text.trim(),
    username:   _usernameCtrl.text.trim(),
    email:   _emailCtrl.text.trim(),
     phone:  _phoneCtrl.text.trim(),
     password:  _passwordCtrl.text,
     avatarUrl:  "",
    );
  }

  @override
  Widget build(BuildContext context) {
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
      //backgroundColor: const Color(0xFF5B2020),
      body: ImageBackground(
        
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
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
                      // Logo on top
                      // Image.asset(
                      //   'assets/logo.png', // replace with your logo
                      //   height: 80,
                      // ),
                      const SizedBox(height: 16),
                      Text(
                        'Register',
                        style: TextStyle(
                          fontFamily: 'StackSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                          color:  Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildTextField(_fullnameCtrl, 'Full Name'),
                            _buildTextField(_usernameCtrl, 'Username'),
                            _buildTextField(_emailCtrl, 'Email',
                                keyboardType: TextInputType.emailAddress),
                            _buildTextField(_phoneCtrl, 'Phone',
                                keyboardType: TextInputType.phone),
                            _buildTextField(_passwordCtrl, 'Password',
                                obscureText: true),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: authState.isLoading?null: _submit,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: const Color(0xFF5B2020),
                                ),
                                child: authState.isLoading?
                                CircularProgressIndicator()
                                :
                                 Text(
                                  'Register',
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
                            InkWell(
                              onTap: () {
                                // Navigator.of(context)
                                //     .pushReplacementNamed('/login');
                                var route = MaterialPageRoute(builder: (_)=>LoginScreen());
                                Navigator.push(context, route);
                              },
                              child: const Text(
                                'Already have an account? Login',
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
          if (label == 'Password' && v.length < 6) return 'Password min 6 chars';
          if (label == 'Email' && !v.contains('@')) return 'Enter valid email';
          return null;
        },
      ),
    );
  }
}
