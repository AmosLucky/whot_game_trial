import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constant.dart';

class LobbyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add or update player presence
  Future<void> updatePlayerStatus(String uid, String status) async {
    await _firestore.collection('players').doc(uid).set({
      'uid': uid,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  Future<String?> findMatchAndStartGame(String myUid) async {
  final lobbyRef = FirebaseFirestore.instance.collection('lobby');
  final gamesRef = FirebaseFirestore.instance.collection('games');

  return await  FirebaseFirestore.instance.runTransaction((transaction) async {
    // 1️⃣ Check if this user is already in a game or waiting
    final existingLobbySnap = await transaction.get(lobbyRef.doc(myUid));
    if (existingLobbySnap.exists) {
      throw Exception('You are already waiting or in a game.');
    }

    // 2️⃣ Search for a waiting player (not you)
    final waitingSnapshot = await lobbyRef
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (waitingSnapshot.docs.isEmpty) {
      // 🟡 No waiting player → add yourself as waiting
      transaction.set(lobbyRef.doc(myUid), {
        'uid': myUid,
        'status': 'waiting',
        'timestamp': FieldValue.serverTimestamp(),
      });
      return null;
    }

    // 3️⃣ Found a waiting player
    final waitingPlayer = waitingSnapshot.docs.first;
    final waitingUid = waitingPlayer['uid'];

    // Prevent same user double-match
    if (waitingUid == myUid) {
      throw Exception('You are already waiting.');
    }

    // 4️⃣ Create a new game safely
    final gameDoc = gamesRef.doc();
    transaction.set(gameDoc, {
      'players': [myUid, waitingUid],
      'status': 'active',
      'turn': myUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 5️⃣ Remove both players from lobby
    transaction.delete(lobbyRef.doc(myUid));
    transaction.delete(waitingPlayer.reference);
     await initializeGameCards(gameDoc.id, [myUid, waitingUid]);

      return gameDoc.id;
  });

  
  
}


//   Future<String?> findMatchAndStartGame(String myUid) async {
//     print("1");
//   final lobbyRef = FirebaseFirestore.instance.collection('lobby');
//   final gamesRef = FirebaseFirestore.instance.collection('games');
//     print("2");

//   return FirebaseFirestore.instance.runTransaction((transaction) async {
//     // Step 1: Find one other waiting player (not me)
//     final waitingPlayers = await lobbyRef
//         .where('status', isEqualTo: 'waiting')
//         .limit(1)
//         .get();

//     if (waitingPlayers.docs.isEmpty) {
//       // No one waiting — add me to lobby
//       transaction.set(lobbyRef.doc(myUid), {
//         'uid': myUid,
//         'status': 'waiting',
//         'gameId': null,
//         'timestamp': FieldValue.serverTimestamp(),
//       });
//       return null; // wait for opponent
//     } else {
//       // Found someone waiting
//       final opponentDoc = waitingPlayers.docs.first;
//       final opponentUid = opponentDoc.id;

//       // Step 2: Create a new game document
//       final newGameRef = gamesRef.doc();
//       transaction.set(newGameRef, {
//         'gameId': newGameRef.id,
//         'players': [myUid, opponentUid],
//         'status': 'active',
//         'createdAt': FieldValue.serverTimestamp(),
//       });

//       // Step 3: Update both lobby records
//       transaction.update(lobbyRef.doc(opponentUid), {
//         'status': 'matched',
//         'gameId': newGameRef.id,
//       });
//       transaction.set(lobbyRef.doc(myUid), {
//         'status': 'matched',
//         'gameId': newGameRef.id,
//         'timestamp': FieldValue.serverTimestamp(),
//       });

//       // initialize deck and hands
//       await initializeGameCards(newGameRef.id, [myUid, opponentUid]);

//       return newGameRef.id;
//     }
//   });
// }


  /// Remove player from lobby list
  Future<void> removePlayerFromLobby(String uid) async {
    await _firestore.collection('lobby').doc(uid).delete().catchError((_) {});
   // await updatePlayerStatus(uid, 'offline');
  }

  /// Add player to lobby and mark as waiting
  Future<void> addPlayerToLobby(String uid) async {
    await _firestore.collection('lobby').doc(uid).set({
      'uid': uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await updatePlayerStatus(uid, 'lobby');
  }

  /// Try to match players in lobby
 
Future<String?> tryMatchPlayers(String myUid,int amount) async {
  print("09000");
  final firestore = FirebaseFirestore.instance;
  final lobbyRef = firestore.collection('lobby');
  final usersRef = firestore.collection('users');
  final gamesRef = firestore.collection('games');

  // ✅ Step 1: Put player in lobby if not there
  final myLobbyDoc = await lobbyRef.doc(myUid).get();
  //if (!myLobbyDoc.exists) {
    await lobbyRef.doc(myUid).set({
      'joinedAt': FieldValue.serverTimestamp(),
      'status':'waiting',
      'amount':amount,
      "id":myUid
    });
  //}

  //  final waitingQuery = await lobbyRef
  //     .where('status', isEqualTo: 'waiting')
  //     .limit(1)
  //     .get();
  

  // ✅ Step 2: Fetch all waiting players (excluding me)
  final lobbySnapshot = await lobbyRef.where('status', isEqualTo: 'waiting')
  .where( 'amount',isEqualTo: amount)
  .get();
  final waitingPlayers =
      lobbySnapshot.docs.map((e) => e.id).where((id) => id != myUid).toList();

  if (waitingPlayers.isEmpty) {
    print('⏳ No opponent yet, waiting...');
    return null;
  }
  

  // ✅ Step 3: Pick first opponent
  final opponentUid = waitingPlayers.first;

  // ✅ Step 4: Use Firestore transaction for perfect atomic safety
  return await firestore.runTransaction((transaction) async {
    final myLobbySnap = await transaction.get(lobbyRef.doc(myUid));
    final oppLobbySnap = await transaction.get(lobbyRef.doc(opponentUid));

    // 🧩 Ensure both still in lobby (avoid stale reads)
    if (!myLobbySnap.exists || !oppLobbySnap.exists) {
      print('❌ One player already matched.');
      return null;
    }

    

    // ✅ Step 5: Double-check neither player is already in a game
    final myUserSnap = await transaction.get(usersRef.doc(myUid));
    final oppUserSnap = await transaction.get(usersRef.doc(opponentUid));

    //check balance
  //   if (myUserSnap['balance'] < minPayment || oppUserSnap['balance'] < minPayment) {
  //    print('❌ One player Insufficient Balnce.');
  //     return null;
  // }

    final myData = myUserSnap.data() ?? {};
    final oppData = oppUserSnap.data() ?? {};

    // if ((myData['status'] == 'in_game') || (oppData['status'] == 'in_game')) {
    //   print('⚠️ One player is already in another game.');
    //   return null;
    // }

    // ✅ Step 6: Create NEW game (always fresh)
    final gameRef = gamesRef.doc();
    transaction.set(gameRef, {
      'players': [myUid, opponentUid],
      'turn': myUid,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    //Added step ///update the players Lobby


         transaction
    .set(lobbyRef.doc(myUid),{'status': 'matched', 'gameId': gameRef.id});
      transaction
    .set(lobbyRef.doc(opponentUid),{'status': 'matched', 'gameId': gameRef.id});
   


   


    // ✅ Step 7: Remove both from lobby inside the same transaction
    // transaction.delete(lobbyRef.doc(myUid));
    // transaction.delete(lobbyRef.doc(opponentUid));

    // ✅ Step 8: Update both users balance to "- minPayment"
    transaction.update(usersRef.doc(myUid), {
      'balance': myUserSnap['balance'] - amount,
      
    });
    transaction.update(usersRef.doc(opponentUid), {
      'balance': oppUserSnap['balance'] - amount,
    });

    print('🎮 New Game Created: ${gameRef.id} between $myUid and $opponentUid');
    return gameRef.id;
  }).then((gameId) async {
   // if (gameId != null) {
      // Initialize deck AFTER transaction succeeds
      await initializeGameCards(gameId!, [myUid, opponentUid]);
   // }
//     await lobbyRef
//     .doc(myUid)
//     .update({'status': 'matched', 'gameId': gameId});

// await lobbyRef
//     .doc(opponentUid)
//     .update({'status': 'matched', 'gameId': gameId});
    return gameId;
  });
}








  /// Initialize Whot deck, deal 5 cards to each player, set table card and deck
  Future<void> initializeGameCards(String gameId, List<String> players) async {
    final allCards = _generateWhotDeck();
    allCards.shuffle();

    final Map<String, List<Map<String, dynamic>>> hands = {};
    for (var player in players) {
      hands[player] = allCards.take(5).toList();
      allCards.removeRange(0, 5);
    }

    final topCard = allCards.removeAt(0); // initial table card

    await _firestore.collection('games').doc(gameId).update({
      'hands': hands,
      'deck': allCards,
      'tableCard': topCard,
      'turn': players.first,
      'status': 'active',
    });
  }



// List<Map<String, dynamic>> _generateWhotDeck() {
//   final shapes = ['circle', 'cross', 'triangle', 'square', 'star'];
//   final cards = <Map<String, dynamic>>[];

//   // Generate 70 cards (1–14 × 5 shapes)
//   for (var shape in shapes) {
//     for (var num = 1; num <= 14; num++) {
//       cards.add({'shape': shape, 'number': num});
//     }
//   }

//   // Shuffle the deck
//   cards.shuffle(Random());

//   // Take only 50 cards randomly
//   final selectedDeck = cards.take(50).toList();

//   // (Optional) Uncomment this line if you want to later include Whot (20)
//   // selectedDeck.add({'shape': 'whot', 'number': 20});

//   return selectedDeck;
// }


List<Map<String, dynamic>> _generateWhotDeck() {
  final deckRules = {
    'star':     [1, 2, 3, 4, 5, 7, 8],
    'cross':    [1, 2, 3, 5, 7, 10, 11, 13, 14],
    'square':   [1, 2, 3, 5, 7, 10, 11, 13, 14],
    'circle':   [1, 2, 3, 4, 5, 7, 8, 10, 11, 12, 13, 14],
    'triangle': [1, 2, 3, 4, 5, 7, 8, 10, 11, 12, 13, 14],
  };

  final cards = <Map<String, dynamic>>[];

  // Generate allowed cards only
  deckRules.forEach((shape, numbers) {
    for (var num in numbers) {
      cards.add({'shape': shape, 'number': num});
    }
  });

  // Shuffle the deck
  cards.shuffle(Random());

  // You can choose to remove or limit cards if needed:
  // final selectedDeck = cards.take(50).toList();
  // return selectedDeck;

  return cards; // return full correct Whot deck
}


createNewDeck(String gameId)async{
  final allCards = _generateWhotDeck();
  allCards.shuffle();

   await _firestore.collection('games').doc(gameId).update({
      
      'deck': allCards,
   });
}

Future<void> removeFromLobby(String userId) async {
  final lobbyRef =FirebaseFirestore.instance.collection("lobby").doc(userId);
  await lobbyRef.delete();
}







}
