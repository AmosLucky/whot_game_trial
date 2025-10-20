// lib/app.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:naija_whot_trail/screens/home_screen.dart';
import 'package:naija_whot_trail/screens/login_screen.dart';
import 'package:naija_whot_trail/screens/register_screen.dart';
import 'package:naija_whot_trail/services/auth_service.dart';
import 'package:naija_whot_trail/services/lobby_service.dart';
import 'package:provider/provider.dart';

// We'll add providers/services later (AuthService, GameService)
class NaijaWhotApp extends StatelessWidget {
  const NaijaWhotApp({super.key});

  @override
  Widget build(BuildContext context) {
   final authService = AuthService(mysqlSyncEndpoint: "");
   final lobbyService =  LobbyService();

    return MaterialApp(
      routes: {
       // '/': (context) =>  SplashPage(authService: authService,),
        '/register': (context) => RegisterScreen(authService: authService),
        '/login': (context) => LoginScreen(authService: authService),
        '/home': (context) =>  HomeScreen(lobbyService: lobbyService,authService: authService,),
      },
      title: 'Naija Whot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: SplashPage(authService: authService),
    );
  }
}

/// Minimal splash page while other screens are added.
class SplashPage extends StatefulWidget {
  final AuthService authService;
    SplashPage({super.key, required this.authService});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    
    

    // Simulate loading then navigate to auth (we'll replace with real logic)
    Future.delayed(const Duration(seconds: 2), () {
      final user = FirebaseAuth.instance.currentUser;
  Future.delayed(const Duration(seconds: 3), () {
    if (user != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/register');
    }
  });
      //  Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(
      //     builder: (_) => RegisterScreen(authService: widget.authService),
      //   ),
      // );
      // push to registration/login screen later
      // For now we'll stay, or you can navigate to '/home' after adding HomeScreen
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Naija Whot',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
