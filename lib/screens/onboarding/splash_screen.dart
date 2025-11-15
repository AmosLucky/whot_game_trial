import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../states/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async{
        await Future.delayed(const Duration(seconds: 2),(){
          ref.read(authControllerProvider.notifier).autoLogin();
          
        }); // ⏳ delay 2 seconds

     // ✅ safe now
  });

    // Navigate after 3 seconds
   
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final authState = ref.read(authControllerProvider);
    //ref.read(authControllerProvider.notifier).reset();
    
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    

    if (next.isSuccess) {
      ref.read(authControllerProvider.notifier).reset();
      // Navigate to home screen after success
      Navigator.pushReplacementNamed(context, '/home');
    } else if(!next.isLoading && !next.isSuccess && next.isFailure) {
      ref.read(authControllerProvider.notifier).reset();
      Navigator.pushReplacementNamed(context, '/register');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(next.error!)));
    }
    
  });

    return Scaffold(
      backgroundColor: const Color(0xFF5B2020),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fadeAnim,
              child: Text(
                "Naija Whot",
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'StackSans',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _fadeAnim,
              child: Text(
                "The Ultimate Card Challenge",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontFamily: 'StackSans',
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
