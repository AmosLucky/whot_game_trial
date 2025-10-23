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
   _listenForMatch();
  }

  Future<void> _enterLobby() async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    //OLD WORKING LOBBY / MATCH CODE WITH LITTLE ISSUES (double game id), 
    //USE AS BACKUP IF THE REST FAILS
    // await widget.lobbyService.addPlayerToLobby(user.uid);
    // _checkForMatch(user.uid);
  

     final gameId = await widget.lobbyService.tryMatchPlayers(user.uid);
     print("333");
     print(gameId);
     if(gameId != null){
       _navigateToGame(gameId);
     }else{
      print("No user in lobby ...................");
     }
  }




void _listenForMatch() async{
   final user = widget.authService.currentUser;
  FirebaseFirestore.instance
      .collection('lobby')
      .doc(user!.uid)
      .snapshots()
      .listen((snapshot)async {
    if (snapshot.exists) {
      print("its exists.............");
      final data = snapshot.data();
      if (data != null && data['status'] == 'matched' && data['gameId'] != null) {
        print(data['gameId']);
        final gameId = data['gameId'];
        print("pin pin1");

        final gameRef = FirebaseFirestore.instance.collection('games').doc(gameId);
      final gameSnap = await gameRef.get();
      print("pin pin2");
        
        if(gameSnap.exists){
          print("pin pin3");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GamePlayScreen(
              gameId: gameId,
              myUid: user.uid,
              myBalance: 0, // or fetch real balance if available
            ),
          ),
        );
        }
      }
    }
  });
}


  Future<void> _checkForMatch(String uid) async {
    final gameId = await widget.lobbyService.tryMatchPlayers(uid);
    print("oooo");
    print(gameId);

    if (gameId != null) {
      print("this");
      _navigateToGame(gameId);
    } else {
       print("that");
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
