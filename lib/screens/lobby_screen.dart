import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/lobby_service.dart';
import '../services/auth_service.dart';
import 'gameplay_screen.dart';

class LobbyScreen extends StatefulWidget {
  final AuthService authService;
  final LobbyService lobbyService;

  const LobbyScreen({
    super.key,
    required this.authService,
    required this.lobbyService,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool isWaiting = true;
  bool matched = false;

  @override
  void initState() {
    super.initState();
    _enterLobby();
  }

  Future<void> _enterLobby() async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    await widget.lobbyService.addPlayerToLobby(user.uid);
    _checkForMatch(user.uid);
  }

  Future<void> _checkForMatch(String uid) async {
    final gameId = await widget.lobbyService.tryMatchPlayers(uid);

    if (gameId != null) {
      _navigateToGame(gameId);
    } else {
      FirebaseFirestore.instance
          .collection('games')
          .where('players', arrayContains: uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty && !matched) {
          matched = true;
          final game = snapshot.docs.first;
          _navigateToGame(game.id);
        }
      });
    }
  }

  void _navigateToGame(String gameId) async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    await widget.lobbyService.updatePlayerStatus(user.uid, 'in_game');

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GamePlayScreen(
            gameId: gameId,
            myUid: user.uid,
            myBalance: 0,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    final user = widget.authService.currentUser;
    if (user != null) {
      widget.lobbyService.removePlayerFromLobby(user.uid);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade900,
      body: Center(
        child: isWaiting
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    "Waiting for another player...",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              )
            : const SizedBox(),
      ),
    );
  }
}
