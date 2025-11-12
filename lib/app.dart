// lib/app.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:naija_whot_trail/screens/home_screen.dart';
import 'package:naija_whot_trail/screens/auth/login_screen.dart';
import 'package:naija_whot_trail/screens/auth/register_screen.dart';
import 'package:naija_whot_trail/services/auth_service.dart';
import 'package:naija_whot_trail/services/lobby_service.dart';

import 'screens/onboarding/splash_screen.dart';

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
        '/register': (context) => RegisterScreen(
          
          ///authService: authService
          ),
        '/login': (context) => LoginScreen(),
        '/home': (context) =>  HomeScreen(lobbyService: lobbyService,authService: authService,),
      },
      title: 'Naija Whot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: SplashScreen(),
    );
  }
}

/// Minimal splash page while other screens are added.
