import 'package:flutter/material.dart';
import 'package:naija_whot_trail/services/lobby_service.dart';
import 'package:naija_whot_trail/services/auth_service.dart';
import 'package:naija_whot_trail/screens/lobby_screen.dart';

class HomeScreen extends StatelessWidget {
  final AuthService authService;
  final LobbyService lobbyService;

   HomeScreen({
    Key? key,
    required this.authService,
    required this.lobbyService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.green.shade900,
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        title: Column(
          children: [
            const Text("Naija Whot"),
            Text(
  "Welcome, ${user?.displayName ?? user?.email ?? 'Player'}",
  style: const TextStyle(color: Colors.white, fontSize: 16),
),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LobbyScreen(
                //   lobbyService: lobbyService,
                //  authService: authService, // You can fetch real balance later
                ),
              ),
            );
          },
          child: const Text(
            'PLAY',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
