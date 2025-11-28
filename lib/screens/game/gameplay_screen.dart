// lib/screens/gameplay_screen.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naija_whot_trail/services/game_service.dart';
import 'package:naija_whot_trail/services/lobby_service.dart';

import '../../controllers/countdown_state.dart';
import '../../providers/game_proider.dart';
import '../../providers/providers.dart';
import '../../providers/ring_provider.dart';
import '../../services/sound_service.dart';
import '../../widgets/image_background.dart';

class GamePlayScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String myUid;
  final double amount;
 

  const GamePlayScreen({
    Key? key,
    required this.gameId,
    required this.myUid,
    required this.amount
    
  }) : super(key: key);

  @override
 ConsumerState <GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _gameStream;
  bool _initializing = false;
  bool _winDialogShown = false; // prevent multiple dialogs
  // bool isReady = false;

  SoundService _soundService = SoundService();

  @override
  void initState() {
   if(mounted){
    // showFullScreenLoader(context);
   }

   

 
    
   _soundService.playBackground();
    
    
    super.initState();
    

     

    // Force landscape on mobile only
    // if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    //   SystemChrome.setPreferredOrientations([
    //     DeviceOrientation.landscapeLeft,
    //     DeviceOrientation.landscapeRight,
    //   ]);
    // }  
    try{
       _gameStream = _firestore.collection('games').doc(widget.gameId).snapshots();
    LobbyService _lobbyService = LobbyService();
   _lobbyService.removePlayerFromLobby(widget.myUid);

    }catch(e){
      print(e);
    }
   
  }

  stopCountDown(){
    ref.read(turnCountdownProvider.notifier).stop();
  }

  String _normalizeCard(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw.toLowerCase();
    if (raw is Map) {
      final shape = raw['shape'] ?? '';
      final number = raw['number'] ?? '';
      return '$shape-$number'.toLowerCase();
    }
    return raw.toString().toLowerCase();
  }

  List<String> _playersFromData(Map<String, dynamic>? data) {
    if (data == null) return [];
    final raw = data['players'];
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is Map) return raw.keys.map((k) => k.toString()).toList();
    return [raw.toString()];
  }


  Future<void> _transactionalInitIfNeeded() async {
    if (_initializing) return;
    _initializing = true;
    final gameRef = _firestore.collection('games').doc(widget.gameId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(gameRef);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final players = _playersFromData(data);

        List<String> deck = [];
        if (data['deck'] is List) deck = (data['deck'] as List).map<String>(_normalizeCard).toList();

        Map<String, List<String>> hands = {};
        if (data['hands'] is Map) {
          hands = (data['hands'] as Map).map(
            (k, v) => MapEntry(k.toString(), (v as List).map(_normalizeCard).toList()),
          );
        }

        if (hands.isEmpty && deck.length >= players.length * 5) {
          for (var pid in players) {
            hands[pid] = deck.sublist(0, 5).map(_normalizeCard).toList();
            deck.removeRange(0, 5);
          }
        }

        String topCard = _normalizeCard(data['topCard']);
        if (topCard.isEmpty && deck.isNotEmpty) {
          topCard = _normalizeCard(deck.removeLast());
        }

        final existingRequired = data['requiredCard'];
        final requiredCardToWrite = existingRequired == null ? '' : existingRequired;

        tx.update(gameRef, {
          'deck': deck,
          'hands': hands,
          'topCard': topCard,
          'shapeInPlay': topCard.isNotEmpty ? topCard.split('-').first : '',
          'requiredCard': requiredCardToWrite,
          'turn': data['turn'] ?? (players.isNotEmpty ? players.first : null),
          'status': data['status'] ?? 'active',
        });
      });
    } catch (e) {
      debugPrint('Init error: $e');
    } finally {
      _initializing = false;
    }
  }

  bool _isWhot(String card) => card.toLowerCase().contains('whot');

  bool _cardAllowed(String card, String topCard, String requiredCard) {
    final c = card.toLowerCase();
    final top = topCard.toLowerCase();
    final required = requiredCard.toLowerCase();

    if (required.isNotEmpty) {
      if (_isWhot(c)) return true;
      final parts = c.split('-');
      if (parts.isEmpty) return false;
      final shape = parts[0];
      return shape == required;
    }

    if (_isWhot(c)) return true;
    if (top.isEmpty) return true;
    if (_isWhot(top)) return false;

    final pc = c.split('-');
    final pt = top.split('-');
    if (pc.length < 2 || pt.length < 2) return false;
    return pc[0] == pt[0] || pc[1] == pt[1];
  }

  Future<void> updateRinged(bool ringed)async{
    final docRef = FirebaseFirestore.instance
    .collection('games')
    .doc(widget.gameId);

// Clear opponent's hand
await docRef.update({
  // set opponent's hand to empty
  'ringed': ringed,       // mark game as ended
 // optional: store loser
});
  }

  Future<void> winByTime(opponentId)async{
    final docRef = FirebaseFirestore.instance
    .collection('games')
    .doc(widget.gameId);

// Clear opponent's hand
await docRef.update({
  'hands.$opponentId': [], // set opponent's hand to empty
  'status': 'ended',       // mark game as ended
  'winner': opponentId,    // optional: store winner
  'loser': widget.myUid,   // optional: store loser
});
  }

Future<void> playCard(String rawCard) async {
  stopCountDown();
  
 // print(myHand);



  _soundService.playEffect("play.mp3");

  final card = _normalizeCard(rawCard);
  final gameRef = _firestore.collection('games').doc(widget.gameId);

  // If there is a pending forced pick for this player, they cannot play
  await _firestore.runTransaction((tx) async {
    final checkSnap = await tx.get(gameRef);
    if (!checkSnap.exists) return;
    final checkData = checkSnap.data() ?? {};
    final pending = checkData['pendingAction'];
    if (pending != null && pending['type'] == 'force_pick') {
      final target = pending['target']?.toString();
      // If current player is the one who must pick, disallow playing a card
      if (target == widget.myUid) {
        return; // ignore attempt to play while forced-pick pending
      }
    }
  });

  // 🟩 --- WHOT CARD LOGIC ---
  if (_isWhot(card)) {
    final chosen = await chooseShapeDialog(context);
    if (chosen.isEmpty) return;

    final chosenShape = chosen.toLowerCase();

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(gameRef);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final turn = (data['turn'] ?? '').toString();
      if (turn != widget.myUid) return;

      final hands = Map<String, dynamic>.from(data['hands'] ?? {});
      final myHand = List<String>.from((hands[widget.myUid] ?? []).map(_normalizeCard));
      // Remove one instance of the WHOT card
      bool removed = false;
      for (int i = 0; i < myHand.length; i++) {
        if (myHand[i] == card) {
          myHand.removeAt(i);
          removed = true;
          break;
        }
      }
      if (!removed) return;
      hands[widget.myUid] = myHand;

      final players = _playersFromData(data);
      final next = players.firstWhere((p) => p != widget.myUid, orElse: () => widget.myUid);

      tx.update(gameRef, {
        'hands': hands,
        'topCard': 'whot', // keep whot visible
        'requiredCard': chosenShape,
        'shapeInPlay': chosenShape,
        'turn': next,
        'pendingAction': null,
      });
    });
    return;
  }

  // 🟨 --- NORMAL CARD LOGIC ---
  await _firestore.runTransaction((tx) async {
    final snap = await tx.get(gameRef);
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    final turn = (data['turn'] ?? '').toString();
    if (turn != widget.myUid) return;

    // If there is a pending forced pick targeting someone else, disallow other plays
    final pending = data['pendingAction'];
    if (pending != null && pending['type'] == 'force_pick') {
      final target = pending['target']?.toString();
      // If pending exists but target is not the current player (someone else), disallow new plays
      // (This stops other players from interfering while a forced pick is outstanding)
      if (target != widget.myUid) {
        return;
      }
    }


    final topCard = _normalizeCard(data['topCard']);
    final requiredCard = (data['requiredCard'] ?? '').toString().toLowerCase();

    if (!_cardAllowed(card, topCard, requiredCard)) return;

    final hands = Map<String, dynamic>.from(data['hands'] ?? {});
    final myHand = List<String>.from((hands[widget.myUid] ?? []).map(_normalizeCard));
    // Remove the played card (one instance)
    bool removed = false;
    for (int i = 0; i < myHand.length; i++) {
      if (myHand[i] == card) {
        myHand.removeAt(i);
        removed = true;
        break;
      }
    }
    if (!removed) return;
    hands[widget.myUid] = myHand;

    final players = _playersFromData(data);
    final opponent = players.firstWhere((p) => p != widget.myUid, orElse: () => widget.myUid);

    final cardNumber = int.tryParse(card.split('-')[1]) ?? 0;
    final updates = <String, dynamic>{
      'hands': hands,
      'topCard': card,
      'shapeInPlay': card.split('-')[0],
      'requiredCard': '',
      'pendingAction': null,
    };

    String nextTurn = opponent;

    // 🟥 --- APPLY NAIJA WHOT RULES ---
    switch (cardNumber) {
      case 1: // Hold On
       ref.read(turnCountdownProvider.notifier).start();
        nextTurn = widget.myUid; // player plays again
        break;

      case 2: // Pick Two - opponent must draw 2 (and cannot play until done)
        nextTurn = opponent;
        updates['pendingAction'] = {
          'type': 'force_pick',
          'count': 2,
          'target': opponent,
          'from': widget.myUid,
        };
        break;

      case 8: // Suspension - skip opponent
       ref.read(turnCountdownProvider.notifier).start();
        nextTurn = widget.myUid;
        break;

      case 14: // General Market - opponent must draw 1 (and cannot play until done)
        nextTurn = opponent;
        updates['pendingAction'] = {
          'type': 'force_pick',
          'count': 1,
          'target': opponent,
          'from': widget.myUid,
        };
        break;
    }

    updates['turn'] = nextTurn;
    tx.update(gameRef, updates);
  });
}


// Future<void> playCardss(String rawCard) async {
//   final card = _normalizeCard(rawCard);
//   final gameRef = _firestore.collection('games').doc(widget.gameId);

//   // 🟩 --- WHOT CARD LOGIC ---
//   if (_isWhot(card)) {
//     final chosen = await chooseShapeDialog(context);
//     if (chosen.isEmpty) return;

//     final chosenShape = chosen.toLowerCase();

//     await _firestore.runTransaction((tx) async {
//       final snap = await tx.get(gameRef);
//       if (!snap.exists) return;
//       final data = snap.data() ?? {};
//       final turn = (data['turn'] ?? '').toString();
//       if (turn != widget.myUid) return;

//       final hands = Map<String, dynamic>.from(data['hands'] ?? {});
//       final myHand = List<String>.from((hands[widget.myUid] ?? []).map(_normalizeCard));
//       myHand.remove(card);
//       hands[widget.myUid] = myHand;

//       final players = _playersFromData(data);
//       final next = players.firstWhere((p) => p != widget.myUid, orElse: () => widget.myUid);

//       tx.update(gameRef, {
//         'hands': hands,
//         'topCard': 'whot',
//         'requiredCard': chosenShape,
//         'shapeInPlay': chosenShape,
//         'turn': next,
//         'pendingAction': null,
//       });
//     });
//     return;
//   }

//   // 🟨 --- NORMAL CARD LOGIC ---
//   await _firestore.runTransaction((tx) async {
//     final snap = await tx.get(gameRef);
//     if (!snap.exists) return;
//     final data = snap.data() ?? {};
//     final turn = (data['turn'] ?? '').toString();
//     if (turn != widget.myUid) return;

//     final topCard = _normalizeCard(data['topCard']);
//     final requiredCard = (data['requiredCard'] ?? '').toString().toLowerCase();

//     if (!_cardAllowed(card, topCard, requiredCard)) return;

//     final hands = Map<String, dynamic>.from(data['hands'] ?? {});
//     final myHand = List<String>.from((hands[widget.myUid] ?? []).map(_normalizeCard));
//     myHand.remove(card);
//     hands[widget.myUid] = myHand;

//     final players = _playersFromData(data);
//     final opponent = players.firstWhere((p) => p != widget.myUid, orElse: () => widget.myUid);

//     final cardNumber = int.tryParse(card.split('-')[1]) ?? 0;
//     final updates = <String, dynamic>{
//       'hands': hands,
//       'topCard': card,
//       'shapeInPlay': card.split('-')[0],
//       'requiredCard': '',
//       'pendingAction': null,
//     };

//     String nextTurn = opponent;

//     // 🟥 --- APPLY NAIJA WHOT RULES ---
//     switch (cardNumber) {
//       case 1: // Hold On
//         nextTurn = widget.myUid;
//         break;

//       case 2: // Pick Two
//         updates['pendingAction'] = {
//           'type': 'force_pick',
//           'count': 2,
//           'target': opponent,
//           'from': widget.myUid,
//         };
//         break;

//       case 8: // Suspension
//         nextTurn = widget.myUid;
//         break;

//       case 14: // General Market
//         updates['pendingAction'] = {
//           'type': 'force_pick',
//           'count': 1,
//           'target': opponent,
//           'from': widget.myUid,
//         };
//         break;
//     }

//     updates['turn'] = nextTurn;
//     tx.update(gameRef, updates);
//   });
// }



  Future<String> chooseShapeDialog(BuildContext context) async {
    String chosen = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Choose Shape'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['circle', 'cross', 'triangle', 'square', 'star']
              .map((s) => ListTile(
                    title: Text(s.toUpperCase()),
                    onTap: () {
                      chosen = s;
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
    return chosen;
  }
  Future<void> pickCard(String playerId) async {
    stopCountDown();
      _soundService.playEffect("play.mp3");
  final ref = _firestore.collection('games').doc(widget.gameId);
  await _firestore.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    final turn = data['turn'];
    if (turn != playerId) return; // not this player's turn

    final hands = Map<String, dynamic>.from(data['hands'] ?? {});
    final myHand = List<String>.from((hands[playerId] ?? []).map(_normalizeCard));

    List<String> deck = [];
    if (data['deck'] is List) deck = (data['deck'] as List).map<String>(_normalizeCard).toList();
    ///market is empty
   
    if (deck.isEmpty) return;

    ///deck remain one 
     if(deck.length == 2){
     LobbyService  lobbyService = LobbyService();
     lobbyService.createNewDeck(widget.gameId);
      
     }
   

    final pending = data['pendingAction'];
    if (pending != null && pending['type'] == 'force_pick' && pending['target'] == playerId) {
      // This is a forced pick resolution. Draw `pending['count']` cards (or as many available)
      int toDraw = (pending['count'] ?? 0) as int;
      if (toDraw <= 0) {
        // nothing to draw, clear pending and return turn to origin
        tx.update(ref, {
          'pendingAction': null,
          'turn': pending['from'],
        });
        return;
      }

      final drawn = <String>[];
      for (int i = 0; i < toDraw && deck.isNotEmpty; i++) {
        drawn.add(deck.removeLast());
      }

      // Insert drawn cards at front of hand (you requested this behavior earlier)
      for (var d in drawn.reversed) {
        myHand.insert(0, d);
      }
      hands[playerId] = myHand;

      // After drawing, clear pendingAction and return turn to original player (from)
      tx.update(ref, {
        'deck': deck,
        'hands': hands,
        'pendingAction': null,
        'turn': pending['from'],
        'lastAction': {
          'by': playerId,
          'type': 'forced_draw',
          'count': drawn.length,
          'ts': FieldValue.serverTimestamp(),
        }
      });
      return;
    }

    // Normal draw (player voluntarily picks 1 card because they had no playable card or by choice)
    final newCard = deck.removeLast();
    myHand.insert(0, newCard); // insert at front
    hands[playerId] = myHand;

    final players = _playersFromData(data);
    final next = players.firstWhere((p) => p != playerId, orElse: () => playerId);

    tx.update(ref, {
      'deck': deck,
      'hands': hands,
      'turn': next,
      'lastAction': {
        'by': playerId,
        'type': 'draw',
        'count': 1,
        'ts': FieldValue.serverTimestamp(),
      }
    });
  });
}


  Widget _cardWidget(String card, {bool playable = true, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: showCard( card,playable)
      // child: Container(

      //  // margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      //   width: 72,
      //   height: 100,
      //   decoration: BoxDecoration(
      //     image: DecorationImage(image: AssetImage(GameService().showCardImage(card)),
      //     fit: BoxFit.cover, repeat: ImageRepeat.repeat),
      //     color: playable ? Colors.grey.shade700 : Colors.grey.shade700,
      //     borderRadius: BorderRadius.circular(10),
          
      //     border: Border.all(color: playable ? Colors.yellow : Colors.black26, width: 2),
      //   ),
      //   child: Center(
      //     child: Text(
      //       card.toUpperCase(),
      //       textAlign: TextAlign.center,
      //       style: const TextStyle(fontWeight: FontWeight.bold),
      //     ),
      //   ),
      // ),
    );
  }

  Widget showCard(String card, bool playable){
    return Container(
        margin: EdgeInsets.symmetric(horizontal: 5),
        height: 100,
        width: 100,
        //color: Colors.black,
        decoration: BoxDecoration(
          border: Border.all(
            width:  playable ?3:0,
            color:  playable ? Colors.red : Colors.grey.shade700,
          )
        ),
        child: Stack(children: [

          Image.asset(GameService().showCardImage(card), 
          height: 100,
        width: 100,fit: BoxFit.fill,),
        Container(
          
          margin: EdgeInsets.all(5),
          child: 
              Text(GameService().showCardNumber(card),style: TextStyle(color: Colors.black),)

          
        ),

        Container(
          alignment: Alignment.bottomRight,
          margin: EdgeInsets.all(5),
          child:
              Text(GameService().showCardNumber(card),style: TextStyle(color: Colors.black),)

          
        )

        ],),

      );
  }

  Future<void> _showWinDialog(String winnerId,String username) async {
    if (_winDialogShown) return;
    _winDialogShown = true;

    await _firestore.collection('games').doc(widget.gameId).update({'status': 'ended'});
    if(winnerId == widget.myUid){
      ref.read(authControllerProvider.notifier).payWinner(widget.amount);
    }
    

     await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF5B2020),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // WIN IMAGE (only for winner)
              if (winnerId == widget.myUid)
                Image.asset(
                  "assets/images/win.webp",
                  width: 100,
                  height: 100,
                ),

              const SizedBox(height: 15),

              Text(
                winnerId == widget.myUid ? "🎉 You Won!" : "😔 You Lost",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                winnerId == widget.myUid
                    ? "Congratulations champ! You beat Your Opponent ."
                    : "Opponent defeated you.\nBetter luck next game!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 25),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF5B2020),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // exit game screen
                },
                child: const Text(
                  "OK",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            ],
          ),
        ),
      );
    },
  );

 
     
     //showDialog(
    //   context: context,
    //   barrierDismissible: false,
    //   builder: (_) => AlertDialog(
    //     title: const Text('🏆 Game Over'),
    //     content: Text(winnerId == widget.myUid
    //         ? 'Congratulations! You won the game.'
    //         : '$username has won the game!'),
    //     actions: [
    //       TextButton(
    //         onPressed: () {
    //           Navigator.pop(context);
    //           Navigator.pop(context);
    //         },
    //         child: const Text('OK'),
    //       ),
    //     ],
    //   ),
    // );
  }

  @override
  void dispose() {
    SoundService().stopBackground();
    // Restore portrait when exiting
   
    super.dispose();
  }



    Future<bool> showExitMatchDialog(BuildContext context) async {
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
                "Cancel Game?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),

              Text(
                "Do you want to quit this game?",
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

  @override
  Widget build(BuildContext context) {
 
    
    final authState = ref.read(authControllerProvider);
    final orientation = MediaQuery.of(context).orientation;
    final countdownState = ref.watch(turnCountdownProvider);
    final hasRinger = ref.watch(hasRingerProvider);  
       ref.listen<String>(
      turnProvider(widget.gameId),
      (prev, next) {
        final notifier = ref.read(turnCountdownProvider.notifier);
       

        if (next == widget.myUid) {
          if(!hasRinger){

            _soundService.playEffect("play.mp3");
            ref.read(hasRingerProvider.notifier).set(true);
            
          }
          
          notifier.start();   // My turn → start countdown
        } else {
          ref.read(hasRingerProvider.notifier).set(false);
          
          notifier.stop();    // Opponent turn → stop countdown
        }
      },
    );

   
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (b,c){

        showExitMatchDialog(context);


      },
      child: Scaffold(
        appBar: orientation == Orientation.portrait? 
        AppBar(
          automaticallyImplyLeading: false,
          title:Row(
    children: [
      Text("Staked: ₦${widget.amount}"),
      SizedBox(width: 20),
      Text(
        "⏳ ${countdownState.secondsLeft}",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: countdownState.secondsLeft <= 3 ? Colors.red : Colors.white,
        ),
      ),
    ],
  ),
          actions: [
            // Container(
            //   margin: EdgeInsets.all(10),
            //   child: Icon(Icons.settings,color: Colors.white,))
          ],
        ):null,
        backgroundColor: Colors.green.shade900,
        body: ImageBackground(
          image: "assets/images/bg_3.jpg",
          child:
          Container(
              alignment: Alignment.center,
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _gameStream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}', 
                    style: const TextStyle(color: Colors.white)));
                  }
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              
                  final doc = snap.data!;
                
              
                  final data = doc.data() ?? {};
                 if (data.isEmpty || data.entries.length < 2) return const Center(child: CircularProgressIndicator());
              
                  _transactionalInitIfNeeded();
              
                  final players = _playersFromData(data);
                 
                
                  if (players.isEmpty || players.length < 2) {
                    return const Center(child: Text('Waiting for opponent...', style: TextStyle(color: Colors.white)));
                  }
              
                  final myUid = widget.myUid;
                  final opponentId = players.firstWhere((p) => p != myUid, orElse: () => '');
                  final hands = Map<String, dynamic>.from(data['hands'] ?? {});
                  final myHand = List<String>.from((hands[myUid] ?? []).map(_normalizeCard));
                  if(hands.length < 2){
                    return Center(child: CircularProgressIndicator(),);
                  }
                  final opponentHand = List<String>.from((hands[opponentId] ?? []).map(_normalizeCard));
                
                  // WIN CHECK
              final handsExist = hands.isNotEmpty && hands[widget.myUid] != null && hands[opponentId] != null;
                
              
              
              if ( handsExist && !_winDialogShown) {
                if (myHand.isEmpty) {
                  Future.microtask(() => _showWinDialog(widget.myUid, authState.user!.username));
                } else if (opponentId.isNotEmpty && opponentHand.isEmpty) {
                  Future.microtask(() => _showWinDialog(opponentId,authState.user!.username));
                }
              }
              
                  final topCard = _normalizeCard(data['topCard']);
                  final requiredCard = (data['requiredCard'] ?? '').toString().toLowerCase();
                  final currentTurn = (data['turn'] ?? '').toString();
                  final hasRinged = (data['ringed'] ?? false);
                  final deck = (data['deck'] is List)
                      ? (data['deck'] as List).map<String>(_normalizeCard).toList()
                      : [];
              
                  // --- NEW: read pendingAction and compute blocked state ---
                  final pending = data['pendingAction'];
                  final bool hasPendingForcePick = pending != null && pending['type'] == 'force_pick';
                  final bool blockedByForcedPick = hasPendingForcePick && pending['target'] == myUid;
                  final int forcedPickCount = (pending != null && pending['count'] != null) ? (pending['count'] as int) : 0;
                  if(blockedByForcedPick){
                    _soundService.playEffect("play.mp3");
                  }
                  // -------------------------------------------------------
              
                  final isMyTurn = currentTurn == myUid;
                  final myHandPlayability = myHand.map((c) => _cardAllowed(c, topCard, requiredCard)).toList();
                 // final countdown = ref.read(turnCountdownProvider.notifier);

                  // if(isMyTurn && !hasRinged ){
                  //   updateRinged(true);

                    
                  //   _soundService.playEffect("play.mp3");
                  // }else{
                  //   updateRinged(false);
                  // }

                  if(handsExist && countdownState.secondsLeft==0 && isMyTurn){
                    winByTime(opponentId);
                    //opponnents wins
                     //Future.microtask(() => _showWinDialog(opponentId,authState.user!.username));
                  }
              
                  return SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Padding(
                        //   padding: const EdgeInsets.all(12),
                        //   child: Row(
                        //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //     children: [
                        //       Text(opponentId.isNotEmpty ? opponentId : 'Opponent', style: const TextStyle(color: Colors.white, fontSize: 16)),
                        //       Text(myUid, style: const TextStyle(color: Colors.yellowAccent, fontSize: 16)),
                        //     ],
                        //   ),
                        // ),
              
                        // Opponent
                        Column(
                          children: [
                            Text("Opponent (${opponentHand.length} cards)", style: const TextStyle(color: Colors.white)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                opponentHand.length,
                                (i) => Container(
                                  margin: const EdgeInsets.all(2),
                                  width: 36,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    
                                    color: Colors.grey.shade700,
                                    borderRadius: BorderRadius.circular(12),image: DecorationImage(image: AssetImage("assets/images/card_back.jpeg")),
              
                                   ),
                                ),
                              ),
                            ),
                          ],
                        ),
              
                        // Center cards + info
                        Column(
                          children: [
                            Text(topCard.isNotEmpty ? "Top: ${topCard.toUpperCase()}" : "Top: -", 
                            style: const TextStyle(color: Colors.yellow, fontSize: 18)),
                            if (requiredCard.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text("Required: ${requiredCard.toUpperCase()}", 
                                style: const TextStyle(color: Colors.redAccent)),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  // allow picking if it's my turn OR if I'm the forced target (my turn will also be set to me in the current logic)
                                  onTap: isMyTurn ? () => pickCard(myUid) : null,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(width: 80, height: 120,
                                       decoration: BoxDecoration(color: Colors.blueGrey.shade700,
                                        borderRadius: BorderRadius.circular(12),image: DecorationImage(image: AssetImage("assets/images/card_back.jpeg")))),
                                      Text("MARKET\n(${deck.length})",
                                       textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Container(
                                  width: 100,
                                  height: 140,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(image: AssetImage(GameService().showCardImage(topCard))),
                                    //color: Colors.white,
                                   borderRadius: BorderRadius.circular(12)),
                                  //child: Text(topCard.isNotEmpty ? topCard.toUpperCase() : '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  child: Stack(children: [
              
                  Image.asset(GameService().showCardImage(topCard), 
                  height: 100,
                width: 100,fit: BoxFit.fill,),
                Container(
                  margin: EdgeInsets.all(5),
                  child: 
                      Text(GameService().showCardNumber(topCard),
                      style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold)
                      )
              
                  
                ),
              
                Container(
                  alignment: Alignment.bottomRight,
                  margin: EdgeInsets.only(bottom: 50),
                  child:
                      Text(GameService().showCardNumber(topCard),
                      style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold),)
              
                  
                )
              
                ],),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // show forced-pick hint when blocked
                            if (blockedByForcedPick)
                            
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Text(
                                  "You must pick $forcedPickCount card${forcedPickCount > 1 ? 's' : ''} from MARKET",
                                  style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            Text(isMyTurn ? "Your Turn" : 
                            // authState.user!.username,
                           "Opponent's Turn", 
                            style: TextStyle(color: isMyTurn ? Colors.lightGreenAccent : Colors.white, fontSize: 16)),

                            isMyTurn? Text(
        "Time ${countdownState.secondsLeft} s",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: countdownState.secondsLeft <= 3 ? Colors.red : Colors.white,
        ),
      ):SizedBox.shrink(),
                          ],
                        ),
              
                        // My Hand
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: List.generate(myHand.length, (i) {
                              final c = myHand[i];
                             
                              // IMPORTANT: prevent card play when blocked by forced pick
                              final playable = myHandPlayability[i] && isMyTurn && !blockedByForcedPick;
              
                              return _cardWidget(c, playable: playable, onTap: playable ? () {
                              

                                playCard(c) ;
                              } : null);
                            }),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          
          
          

          
        ),
      ),
    );
  }

 

}
