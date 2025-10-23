// class Trash{
//     Future<String?> tryMatchPlayers1(String myUid) async {
//   final lobbyRef = _firestore.collection('lobby');
//   final gamesRef = _firestore.collection('games');

//   // 1️⃣ First, check if the user is already waiting
//   final myLobbyDoc = await lobbyRef.doc(myUid).get();
//   if (myLobbyDoc.exists) {
//     throw Exception('You are already waiting for a match.');
//   }

//   // 2️⃣ Get a waiting opponent (done outside transaction)
//   final waitingQuery = await lobbyRef
//       .where('status', isEqualTo: 'waiting')
//       .limit(1)
//       .get();

//   if (waitingQuery.docs.isEmpty) {
//     // 🟡 No opponent found → mark myself as waiting
//     await lobbyRef.doc(myUid).set({
//       'uid': myUid,
//       'status': 'waiting',
//       'timestamp': FieldValue.serverTimestamp(),
//     });
//     return null;
//   }

//   final opponentDoc = waitingQuery.docs.first;
//   final opponentUid = opponentDoc['uid'];

//   if (opponentUid == myUid) {
//     // Shouldn't happen, but safety check
//     throw Exception('Matching conflict: same user found.');
//   }

//   // 3️⃣ Run transaction to safely pair and create game
//   return await _firestore.runTransaction<String?>((transaction) async {
//     final myLobbyRef = lobbyRef.doc(myUid);
//     final opponentLobbyRef = opponentDoc.reference;

//     // Double-check opponent is still waiting
//     final opponentSnap = await transaction.get(opponentLobbyRef);
//     if (!opponentSnap.exists || opponentSnap['status'] != 'waiting') {
//       throw Exception('Opponent no longer available.');
//     }

//     // Create the game document atomically
//     final newGameRef = gamesRef.doc();
//     transaction.set(newGameRef, {
//       'players': [myUid, opponentUid],
//       'turn': myUid,
//       'status': 'active',
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     // Remove both from lobby
//     transaction.delete(opponentLobbyRef);
//     transaction.delete(myLobbyRef);

//     return newGameRef.id;
//   }).then((gameId) async {
//     // 4️⃣ Non-transaction setup
//     await updatePlayerStatus(myUid, 'in_game');
//     await updatePlayerStatus(opponentUid, 'in_game');
//     await initializeGameCards(gameId!, [myUid, opponentUid]);
//     return gameId;
//   });
// }





// Future<String?> tryMatchPlayers2(String myUid) async {
//   final usersRef = _firestore.collection('users');
//   final lobbyRef = _firestore.collection('lobby');
//   final gamesRef = _firestore.collection('games');

//   // 1️⃣ Check if user is already in an active game
//   final activeGame = await gamesRef
//       .where('players', arrayContains: myUid)
//       .where('status', isEqualTo: 'active')
//       .limit(1)
//       .get();

//   if (activeGame.docs.isNotEmpty) {
//     final existingGameId = activeGame.docs.first.id;
//     print('User is already in a game: $existingGameId');
//     return existingGameId; // 🔒 prevent starting another game
//   }

//   // 2️⃣ Check if user is already waiting
//   final myLobbyDoc = await lobbyRef.doc(myUid).get();
//   if (myLobbyDoc.exists) {
//     throw Exception('You are already waiting for a match.');
//   }

//   // 3️⃣ Find an opponent waiting
//   final waitingQuery = await lobbyRef
//       .where('status', isEqualTo: 'waiting')
//       .limit(1)
//       .get();

//   if (waitingQuery.docs.isEmpty) {
//     // No opponent → mark self as waiting
//     await lobbyRef.doc(myUid).set({
//       'uid': myUid,
//       'status': 'waiting',
//       'timestamp': FieldValue.serverTimestamp(),
//     });
//     return null;
//   }

//   final opponentDoc = waitingQuery.docs.first;
//   final opponentUid = opponentDoc['uid'];

//   // 4️⃣ Safe match in transaction
//   return await _firestore.runTransaction<String?>((transaction) async {
//     final myLobbyRef = lobbyRef.doc(myUid);
//     final opponentLobbyRef = opponentDoc.reference;

//     final opponentSnap = await transaction.get(opponentLobbyRef);
//     if (!opponentSnap.exists || opponentSnap['status'] != 'waiting') {
//       throw Exception('Opponent no longer available.');
//     }

//     // Double-check opponent isn't in a game
//     final oppActive = await gamesRef
//         .where('players', arrayContains: opponentUid)
//         .where('status', isEqualTo: 'active')
//         .limit(1)
//         .get();
//     if (oppActive.docs.isNotEmpty) {
//       throw Exception('Opponent is already in a game.');
//     }

//     // Create one new game
//     final newGameRef = gamesRef.doc();
//     transaction.set(newGameRef, {
//       'players': [myUid, opponentUid],
//       'turn': myUid,
//       'status': 'active',
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     // Remove both from lobby
//     transaction.delete(opponentLobbyRef);
//     transaction.delete(myLobbyRef);

//     return newGameRef.id;
//   }).then((gameId) async {
//     // 5️⃣ Mark both as in_game
//     await updatePlayerStatus(myUid, 'in_game');
//     await updatePlayerStatus(opponentUid, 'in_game');

//     // 6️⃣ Initialize cards
//     await initializeGameCards(gameId!, [myUid, opponentUid]);

//     return gameId;
//   });
// }




// Future<String?> tryMatchPlayers3(String myUid) async {
//   final usersRef = _firestore.collection('users');
//   final lobbyRef = _firestore.collection('lobby');
//   final gamesRef = _firestore.collection('games');

//   // 1️⃣ Double-check: user shouldn't be currently marked "in_game"
//   final myUserDoc = await usersRef.doc(myUid).get();
//   if (myUserDoc.exists && myUserDoc['status'] == 'in_game') {
//     // Verify if that game is really active or stale
//     final activeGames = await gamesRef
//         .where('players', arrayContains: myUid)
//         .where('status', isEqualTo: 'active')
//         .get();

//     if (activeGames.docs.isNotEmpty) {
//       final existingGame = activeGames.docs.first;
//       final createdAt = (existingGame['createdAt'] as Timestamp).toDate();
//       final age = DateTime.now().difference(createdAt);

//       // 🕒 if game is too old (stale), mark it finished and continue matching
//       if (age.inMinutes > 10) {
//         await gamesRef.doc(existingGame.id).update({'status': 'finished'});
//         await usersRef.doc(myUid).update({'status': 'idle'});
//       } else {
//         print('Already in active game: ${existingGame.id}');
//         return existingGame.id; // stay in same game only if truly active & fresh
//       }
//     } else {
//       // no actual game found, reset user status
//       await usersRef.doc(myUid).update({'status': 'idle'});
//     }
//   }

//   // 2️⃣ Check if user is already waiting
//   final myLobbyDoc = await lobbyRef.doc(myUid).get();
//   if (myLobbyDoc.exists) {
//     throw Exception('You are already waiting for a match.');
//   }

//   // 3️⃣ Find opponent waiting
//   final waitingQuery = await lobbyRef
//       .where('status', isEqualTo: 'waiting')
//       .limit(1)
//       .get();

//   if (waitingQuery.docs.isEmpty) {
//     // No opponent → mark self waiting
//     await lobbyRef.doc(myUid).set({
//       'uid': myUid,
//       'status': 'waiting',
//       'timestamp': FieldValue.serverTimestamp(),
//     });
//     await usersRef.doc(myUid).update({'status': 'waiting'});
//     return null;
//   }

//   final opponentDoc = waitingQuery.docs.first;
//   final opponentUid = opponentDoc['uid'];

//   // 4️⃣ Run a safe transaction
//   return await _firestore.runTransaction<String?>((transaction) async {
//     final myLobbyRef = lobbyRef.doc(myUid);
//     final opponentLobbyRef = opponentDoc.reference;

//     final opponentSnap = await transaction.get(opponentLobbyRef);
//     if (!opponentSnap.exists || opponentSnap['status'] != 'waiting') {
//       throw Exception('Opponent no longer available.');
//     }

//     // Verify opponent not already in game
//     final oppActive = await gamesRef
//         .where('players', arrayContains: opponentUid)
//         .where('status', isEqualTo: 'active')
//         .limit(1)
//         .get();
//     if (oppActive.docs.isNotEmpty) {
//       throw Exception('Opponent is already in another game.');
//     }

//     // ✅ Create new game doc
//     final newGameRef = gamesRef.doc();
//     transaction.set(newGameRef, {
//       'players': [myUid, opponentUid],
//       'turn': myUid,
//       'status': 'active',
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     // Remove both from lobby
//     transaction.delete(opponentLobbyRef);
//     transaction.delete(myLobbyRef);

//     return newGameRef.id;
//   }).then((gameId) async {
//     // 5️⃣ Mark both users as in_game
//     await usersRef.doc(myUid).update({'status': 'in_game', 'currentGame': gameId});
//     await usersRef.doc(opponentUid).update({'status': 'in_game', 'currentGame': gameId});

//     // 6️⃣ Initialize cards and setup
//     await initializeGameCards(gameId!, [myUid, opponentUid]);

//     return gameId;
//   });
// }



// Future<String?> tryMatchPlayers4(String myUid) async {
//   final playerRef = _firestore.collection('users').doc(myUid);

//   // 1️⃣ Get player data safely
//   final playerSnap = await playerRef.get();
//   final playerData = playerSnap.data() ?? {};
//   final playerStatus = playerData['status'] ?? 'idle';

//   // Prevent player already in a game from rejoining
//   // if (playerStatus == 'in_game') {
//   //   print('Player $myUid is already in a game');
//   //   return null;
//   // }

//   // 2️⃣ Add player to lobby if not already there
//   final lobbyRef = _firestore.collection('lobby').doc(myUid);
//   final lobbySnap = await lobbyRef.get();
//   if (!lobbySnap.exists) {
//     await lobbyRef.set({'joinedAt': FieldValue.serverTimestamp()});
//   }

//   // 3️⃣ Fetch lobby players (waiting ones)
//   final lobbySnapshot = await _firestore.collection('lobby').get();
//   final waitingPlayers = lobbySnapshot.docs.map((e) => e.id).where((id) => id != myUid).toList();

//   if (waitingPlayers.isEmpty) {
//     print('No opponents available, waiting...');
//     return null;
//   }

//   // 4️⃣ Select opponent who’s not in another game
//   String? opponentUid;
//   for (final uid in waitingPlayers) {
//     final oppRef = _firestore.collection('users').doc(uid);
//     final oppSnap = await oppRef.get();
//     final oppData = oppSnap.data() ?? {};
//     final oppStatus = oppData['status'] ?? 'idle';
//     if (oppStatus == 'idle') {
//       opponentUid = uid;
//       break;
//     }
//   }

//   if (opponentUid == null) {
//     print('No valid opponent found.');
//     return null;
//   }

//   // 5️⃣ Create a single shared game (atomic transaction)
//   final gameRef = await _firestore.collection('games').add({
//     'players': [myUid, opponentUid],
//     'turn': myUid,
//     'status': 'active',
//     'createdAt': FieldValue.serverTimestamp(),
//   });

//   // 6️⃣ Remove both from lobby
//   await _firestore.collection('lobby').doc(myUid).delete();
//   await _firestore.collection('lobby').doc(opponentUid).delete();

//   // 7️⃣ Update both statuses to "in_game"
//   await _firestore.collection('users').doc(myUid).update({'status': 'in_game', 'currentGame': gameRef.id});
//   await _firestore.collection('users').doc(opponentUid).update({'status': 'in_game', 'currentGame': gameRef.id});

//   // 8️⃣ Initialize game cards
//   await initializeGameCards(gameRef.id, [myUid, opponentUid]);

//   print('✅ Game created between $myUid and $opponentUid → ${gameRef.id}');
//   return gameRef.id;
// }


// Future<String?> tryMatchPlayers5(String myUid) async {
//   final playerRef = _firestore.collection('users').doc(myUid);

//   // 1️⃣ Get player data safely
//   final playerSnap = await playerRef.get();
//   final playerData = playerSnap.data() ?? {};
//   final playerStatus = playerData['status'] ?? 'idle';

//   // Prevent player already in a game from rejoining
//   if (playerStatus == 'in_game') {
//     print('Player $myUid is already in a game');
//     return null;
//   }

//   // 2️⃣ Add player to lobby if not already there
//   final lobbyRef = _firestore.collection('lobby').doc(myUid);
//   final lobbySnap = await lobbyRef.get();
//   if (!lobbySnap.exists) {
//     await lobbyRef.set({'joinedAt': FieldValue.serverTimestamp()});
//   }

//   // 3️⃣ Fetch lobby players (waiting ones)
//   final lobbySnapshot = await _firestore.collection('lobby').get();
//   final waitingPlayers = lobbySnapshot.docs.map((e) => e.id).where((id) => id != myUid).toList();

//   if (waitingPlayers.isEmpty) {
//     print('No opponents available, waiting...');
//     return null;
//   }

//   // 4️⃣ Select opponent who’s not in another game
//   String? opponentUid;
//   for (final uid in waitingPlayers) {
//     final oppRef = _firestore.collection('users').doc(uid);
//     final oppSnap = await oppRef.get();
//     final oppData = oppSnap.data() ?? {};
//     final oppStatus = oppData['status'] ?? 'idle';
//     if (oppStatus == 'idle') {
//       opponentUid = uid;
//       break;
//     }
//   }

//   if (opponentUid == null) {
//     print('No valid opponent found.');
//     return null;
//   }

//   // 5️⃣ Create a single shared game (atomic transaction)
//   final gameRef = await _firestore.collection('games').add({
//     'players': [myUid, opponentUid],
//     'turn': myUid,
//     'status': 'active',
//     'createdAt': FieldValue.serverTimestamp(),
//   });

//   // 6️⃣ Remove both from lobby
//   await _firestore.collection('lobby').doc(myUid).delete();
//   await _firestore.collection('lobby').doc(opponentUid).delete();

//   // 7️⃣ Update both statuses to "in_game"
//   await _firestore.collection('users').doc(myUid).update({'status': 'in_game', 'currentGame': gameRef.id});
//   await _firestore.collection('users').doc(opponentUid).update({'status': 'in_game', 'currentGame': gameRef.id});

//   // 8️⃣ Initialize game cards
//   await initializeGameCards(gameRef.id, [myUid, opponentUid]);

//   print('✅ Game created between $myUid and $opponentUid → ${gameRef.id}');
//   return gameRef.id;
// }



// Future<String?> tryMatchPlayers6(String myUid) async {
//   final firestore = FirebaseFirestore.instance;

//   // 🔹 Ensure player is in lobby
//   final myLobbyRef = firestore.collection('lobby').doc(myUid);
//   final myLobbyDoc = await myLobbyRef.get();
//   if (!myLobbyDoc.exists) {
//     await myLobbyRef.set({'joinedAt': FieldValue.serverTimestamp()});
//   }

//   // 🔹 Get all players currently waiting
//   final lobbySnapshot = await firestore.collection('lobby').get();
//   final waitingPlayers = lobbySnapshot.docs.map((e) => e.id).where((id) => id != myUid).toList();

//   if (waitingPlayers.isEmpty) {
//     print('⚪ Waiting for opponent...');
//     return null;
//   }

//   // 🔹 Pick the first available opponent
//   final opponentUid = waitingPlayers.first;

//   // 🔹 Double-check both are still in lobby (to avoid double match)
//   final myCheck = await firestore.collection('lobby').doc(myUid).get();
//   final oppCheck = await firestore.collection('lobby').doc(opponentUid).get();

//   if (!myCheck.exists || !oppCheck.exists) {
//     print('❌ One of the players already matched.');
//     return null;
//   }

//   // 🔹 Create one shared game for both
//   final gameDoc = await firestore.collection('games').add({
//     'players': [myUid, opponentUid],
//     'turn': myUid,
//     'status': 'active',
//     'createdAt': FieldValue.serverTimestamp(),
//   });

//   // 🔹 Remove both from lobby immediately
//   await firestore.collection('lobby').doc(myUid).delete();
//   await firestore.collection('lobby').doc(opponentUid).delete();

//   // 🔹 Initialize cards or setup game state
//   await initializeGameCards(gameDoc.id, [myUid, opponentUid]);

//   print('✅ Game created: ${gameDoc.id} between $myUid and $opponentUid');
//   return gameDoc.id;
// }




// Future<String?> tryMatchPlayers7(String myUid) async {
//   final firestore = FirebaseFirestore.instance;

//   // 🟢 Step 1: Ensure current player is in lobby
//   final myLobbyRef = firestore.collection('lobby').doc(myUid);
//   final myLobbyDoc = await myLobbyRef.get();
//   if (!myLobbyDoc.exists) {
//     await myLobbyRef.set({'joinedAt': FieldValue.serverTimestamp()});
//   }

//   // 🟢 Step 2: Fetch all players waiting in lobby (excluding self)
//   final lobbySnapshot = await firestore.collection('lobby').get();
//   final waitingPlayers = lobbySnapshot.docs.map((e) => e.id).where((id) => id != myUid).toList();

//   if (waitingPlayers.isEmpty) {
//     print('⚪ Waiting for opponent...');
//     return null;
//   }

//   // 🟢 Step 3: Pick the first available opponent
//   final opponentUid = waitingPlayers.first;

//   // 🛡️ Step 4: Use transaction to prevent duplicate matches
//   return await firestore.runTransaction((transaction) async {
//     final myLobbySnap = await transaction.get(firestore.collection('lobby').doc(myUid));
//     final oppLobbySnap = await transaction.get(firestore.collection('lobby').doc(opponentUid));

//     // Make sure both are still in lobby
//     if (!myLobbySnap.exists || !oppLobbySnap.exists) {
//       print('❌ One of the players already matched or left lobby.');
//       return null;
//     }

//     // 🚀 Step 5: Create a new game (always fresh)
//     final gameRef = firestore.collection('games').doc();
//     transaction.set(gameRef, {
//       'players': [myUid, opponentUid],
//       'turn': myUid,
//       'status': 'active',
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     // 🧹 Step 6: Remove both from lobby inside the same transaction
//     transaction.delete(firestore.collection('lobby').doc(myUid));
//     transaction.delete(firestore.collection('lobby').doc(opponentUid));

//     // 🧭 Step 7: Clear any old game references (so they always get new game)
//     transaction.update(firestore.collection('users').doc(myUid), {
//       'status': 'in_game',
//       'currentGame': gameRef.id,
//     });
//     transaction.update(firestore.collection('users').doc(opponentUid), {
//       'status': 'in_game',
//       'currentGame': gameRef.id,
//     });

//     print('✅ Created new game ${gameRef.id} between $myUid and $opponentUid');
//     return gameRef.id;
//   }).then((gameId) async {
//     if (gameId != null) {
//       // Initialize game cards AFTER transaction is complete
//       await initializeGameCards(gameId, [myUid, opponentUid]);
//     }
//     return gameId;
//   });
// }


//  Future<String?> tryMatchPlayers(String myUid) async {
//     final lobbySnapshot = await _firestore.collection('lobby').get();
//     final waitingPlayers = lobbySnapshot.docs.map((e) => e.id).toList();

//     final opponent = waitingPlayers.firstWhere(
//       (uid) => uid != myUid,
//       orElse: () => '',
//     );

//     if (opponent.isNotEmpty) {
//       final gameDoc = await _firestore.collection('games').add({
//         'players': [myUid, opponent],
//         'turn': myUid,
//         'status': 'active',
//         'createdAt': FieldValue.serverTimestamp(),
//       });

//       // remove from lobby
//       await _firestore.collection('lobby').doc(myUid).delete();
//       await _firestore.collection('lobby').doc(opponent).delete();

//       // update status
//       await updatePlayerStatus(myUid, 'in_game');
//       await updatePlayerStatus(opponent, 'in_game');

//       // initialize deck and hands
//       await initializeGameCards(gameDoc.id, [myUid, opponent]);

//       return gameDoc.id;
//     }

//     return null;
//   }

// }