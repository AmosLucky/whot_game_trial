import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naija_whot_trail/providers/providers.dart';

import 'gameplay_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  // final AuthService authService;
  // final LobbyService lobbyService;
  final int amount;

  const LobbyScreen({
    super.key,
    required this.amount,
    
    
  });

  @override
  ConsumerState <LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool isWaiting = true;
  bool matched = false;

  @override
  void initState() {
    super.initState();
    _enterLobby();
   _listenForMatch();
  }

  Future<void> _enterLobby() async {
    final user = ref.read(authControllerProvider).user;
    print(user!.toMap());
    

    //OLD WORKING LOBBY / MATCH CODE WITH LITTLE ISSUES (double game id), 
    //USE AS BACKUP IF THE REST FAILS
    // await widget.lobbyService.addPlayerToLobby(user.uid);
    // _checkForMatch(user.uid);
  

     final gameId = await ref.read(lobbyServiceProvider).tryMatchPlayers(user.uid,widget.amount);
     print("333========================");
     print(gameId);
     if(gameId != null){
      // ref.read(authControllerProvider.notifier).refreshUser();
      await Future.delayed(Duration(seconds: 5), () {
        _navigateToGame(gameId);
  
});

       
     }else{
      print("No user in lobby ...................");
     }
  }




void _listenForMatch() async{
   final user = ref.read(authControllerProvider).user;
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
          
        _navigateToGame(gameSnap.id);
  

          //  ref.read(authControllerProvider.notifier).refreshUser();

          // await Future.delayed(Duration(seconds: 5), () {

          //   Navigator.pushReplacement(
          // context,
          // MaterialPageRoute(
          //   builder: (context) => GamePlayScreen(
          //     gameId: gameId,
          //     myUid: user.uid,
             
          //   ),
          // ),
        //);
  
//});
         
        
        }
      }
    }
  });
}


  // Future<void> _checkForMatch4(String uid) async {
  //   final gameId = await ref.read(lobbyServiceProvider).tryMatchPlayers(uid);
  //   print("oooo");
  //   print(gameId);

  //   if (gameId != null) {
  //     print("this");
  //     _navigateToGame(gameId);
  //   } else {
  //      print("that");
  //     FirebaseFirestore.instance
  //         .collection('games')
  //         .where('players', arrayContains: uid)
  //         .snapshots()
  //         .listen((snapshot) {
  //       if (snapshot.docs.isNotEmpty && !matched) {
  //         matched = true;
  //         final game = snapshot.docs.first;
  //         _navigateToGame(game.id);
  //       }
  //     });
  //   }
  // }

  void _navigateToGame(String gameId) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    await ref.read(lobbyServiceProvider).updatePlayerStatus(user.uid, 'in_game');
    await ref.read(authControllerProvider.notifier).refreshUser();

    if (mounted) {
      //await Future.delayed(Duration(seconds: 0), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GamePlayScreen(
            gameId: gameId,
            myUid: user.uid,
            
          ),
        ),
      );
      //});
    }
  }

  @override
  void dispose() {
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
        final authState = ref.watch(authControllerProvider);
        final lobbyServiceCtr = ref.watch(lobbyServiceProvider);


    return PopScope(
      canPop: false,
      onPopInvoked: (t)async{
        await showExitMatchDialog(context,lobbyServiceCtr,authState.user);
        
      },
      child: Scaffold(
        //backgroundColor: Colors.green.shade900,
        body: Center(
          child: isWaiting
              ? Stack(
          children: [
            // 🔥 Background Image
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.9),
                  BlendMode.darken,
                ),
                child: Image.asset(
                  "assets/images/bg_2.jpg",
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // 🔥 Main Content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Matching GIF Loader
                  Image.asset(
                    "assets/images/matching2.gif",
                    width: 180,
                    height: 180,
                  ),

                  const SizedBox(height: 30),

                  // Searching Text
                  Text(
                    "Searching for opponent…",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 6,
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    "Please wait",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )])
              : const SizedBox(),
        ),
      ),
    );
  }



  Future<bool> showExitMatchDialog(BuildContext context, lobbyServic, user) async {
  return await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFF5B2020),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 60),

              SizedBox(height: 15),

              Text(
                "Cancel Matching?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),

              Text(
                "Do you want to stop searching for an opponent?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cancel button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      "No",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),

                  // Confirm button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      lobbyServic.removeFromLobby(user.uid);
                       Navigator.pushReplacementNamed(context, '/home');
                    },
                    child: Text(
                      "Yes, Exit",
                      style: TextStyle(
                        color: Color(0xFF5B2020),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
}
