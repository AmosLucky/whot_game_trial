// lib/services/game_service.dart
//
// Full, rewritten GameService for Naija Whot
// - Uses Firestore for authoritative game state (games/{gameId})
// - Handles createGame (deduct entry fee atomically), playCard transaction with rule validation,
//   forced draws (pick2/general market), WHOT shape selection, reshuffle logic, and winner detection.
// - Enforces "pick2 must be completed before another pick2" by using a pendingPick field.
// - Exposes awardWinnerCoins for post-game coin awarding (and optional MySQL sync callback).
//
// IMPORTANT:
// - This file assumes you have `CardModel` in lib/models/card_model.dart
//   and `RuleEngine` in lib/utils/rule_engine.dart (both used here).
// - Keep Cloud Functions in mind later for server-side validation for production security.

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/card_model.dart';
import '../utils/rule_engine.dart';

class GameService {
  final FirebaseFirestore firestore;
  final RuleEngine rules;

  /// Default entry fee (coins) required to enter a match.
  final int entryFee;

  /// Default initial hand size per player.
  final int initialHandSize;

  GameService({
    FirebaseFirestore? firestoreInstance,
    RuleEngine? ruleEngine,
    this.entryFee = 50,
    this.initialHandSize = 5,
  })  : firestore = firestoreInstance ?? FirebaseFirestore.instance,
        rules = ruleEngine ?? RuleEngine();

  // ------------------ Deck helpers ------------------

 

  // ------------------ Utility ------------------

  List<String> _toStringList(dynamic maybeList) {
    if (maybeList == null) return <String>[];
    if (maybeList is List) return maybeList.map((e) => e.toString()).toList();
    return <String>[];
  }

  Map<String, dynamic> _mapFrom(dynamic maybeMap) {
    if (maybeMap == null) return {};
    if (maybeMap is Map<String, dynamic>) return maybeMap;
    if (maybeMap is Map) return Map<String, dynamic>.from(maybeMap);
    return {};
  }

  // ------------------ Create Game (with entry fee deduction) ------------------

  /// Create a game between two players (hostUid and opponentUid)
  /// - checks balances and atomically deducts entryFee from both players
  /// - deals initialHandSize to each player
  /// - creates games/{gameId} doc with deck, discard, pileTop, hands, turn, and meta
  ///
  /// Returns the new gameId on success.
  Future<String> createGameAndDeduct({
    //not in use//
    required String hostUid,
    required String opponentUid,
    int? overrideFee,
  }) async {
    final int fee = overrideFee ?? entryFee;
    final usersRef = firestore.collection('users');
    final hostRef = usersRef.doc(hostUid);
    final oppRef = usersRef.doc(opponentUid);
    final gameRef = firestore.collection('games').doc();
    final gameId = gameRef.id;

    await firestore.runTransaction((tx) async {
      // Load both user docs
      final hostSnap = await tx.get(hostRef);
      final oppSnap = await tx.get(oppRef);

      if (!hostSnap.exists || !oppSnap.exists) {
        throw Exception('One or both users not found');
      }

      final hostData = hostSnap.data()!;
      final oppData = oppSnap.data()!;
      final int hostBal = (hostData['balance'] ?? 0) as int;
      final int oppBal = (oppData['balance'] ?? 0) as int;

      if (hostBal < fee) throw Exception('Host has insufficient balance');
      if (oppBal < fee) throw Exception('Opponent has insufficient balance');

      // Deduct fee and set currentGameId (atomic)
      tx.update(hostRef, {
        'balance': hostBal - fee,
        'currentGameId': gameId,
      });
      tx.update(oppRef, {
        'balance': oppBal - fee,
        'currentGameId': gameId,
      });

      // Build and deal deck
      final deck = generateDeck();
      final hostHand = deck.sublist(0, initialHandSize);
      final oppHand = deck.sublist(initialHandSize, initialHandSize * 2);
      final remaining = deck.sublist(initialHandSize * 2);

      // Initialize discard/pileTop by taking one card from remaining if available
      final List<String> discard = [];
      String? pileTop;
      String? whotChosen;

      if (remaining.isNotEmpty) {
        discard.add(remaining.removeAt(0));
        pileTop = discard.last;
        // If pileTop is a whot, we do not set whotChosen yet (will be set when someone plays whot)
        if (CardModel.deserialize(pileTop).shape == 'whot') {
          whotChosen = null;
        }
      }

      final Map<String, dynamic> gameDoc = {
        'status': 'playing',
        'players': {
          hostUid: {
            'name': hostData['displayName'] ?? hostData['username'] ?? hostUid,
            'photoUrl': hostData['photoUrl'] ?? null,
            'balanceSnapshot': (hostBal - fee),
          },
          opponentUid: {
            'name': oppData['displayName'] ?? oppData['username'] ?? opponentUid,
            'photoUrl': oppData['photoUrl'] ?? null,
            'balanceSnapshot': (oppBal - fee),
          }
        },
        'hands': {
          hostUid: hostHand,
          opponentUid: oppHand,
        },
        'deck': remaining,
        'discard': discard,
        'pileTop': pileTop,
        'whotChosen': whotChosen,
        'turn': hostUid,
        // pendingPick is used to enforce pick2/general-market completion before other pick2s
        'pendingPick': 0, // number of cards currently pending to be picked (0 if none)
        'pendingPickOwner': null, // which player must complete the pending picks
        'lastAction': null,
        'createdAt': FieldValue.serverTimestamp(),
        'winner': null,
      };

      tx.set(gameRef, gameDoc);
    });

    return gameId;
  }

  // ------------------ Draw Cards Helper (transactional) ------------------

  /// Draw [count] cards for [playerId] inside a transaction (internal helper).
  /// - reshuffles discard into deck when deck is empty (preserves pileTop)
  /// - returns updated deck, discard, and hands as Map for caller to write
  Future<Map<String, dynamic>> _drawInsideTransaction({
    required Transaction tx,
    required DocumentReference gameRef,
    required Map<String, dynamic> currentData,
    required String targetPlayerId,
    required int count,
  }) async {
    final deck = List<String>.from(_toStringList(currentData['deck']));
    final discard = List<String>.from(_toStringList(currentData['discard']));
    final hands = Map<String, dynamic>.from(currentData['hands'] ?? {});
    final targetHand = List<String>.from(_toStringList(hands[targetPlayerId] ?? []));

    for (int i = 0; i < count; i++) {
      if (deck.isEmpty) {
        // reshuffle discard excluding top (last) into deck
        if (discard.length <= 1) {
          // nothing to reshuffle
          break;
        }
        final last = discard.removeLast();
        deck.addAll(discard);
        deck.shuffle(Random(DateTime.now().microsecondsSinceEpoch));
        discard.clear();
        discard.add(last);
      }
      if (deck.isEmpty) break;
      // pop last for convenience
      final card = deck.removeLast();
      targetHand.add(card);
    }

    hands[targetPlayerId] = targetHand;

    return {
      'deck': deck,
      'discard': discard,
      'hands': hands,
    };
  }

  // ------------------ Play Card (transactional) ------------------

  /// Main entry for a player playing a card.
  /// - Validates it's player's turn
  /// - Validates card exists in player's hand
  /// - Validates play via rules (unless whot)
  /// - Removes card from hand, appends to discard, updates pileTop (with whotChosen if applicable)
  /// - Handles special effects: pick2, general market, holdOn, suspension
  /// - Enforces pendingPick behavior: if there is a pendingPick for some player, other pick2 cannot be played
  Future<void> playCardr({
    required String gameId,
    required String playerId,
    required String cardStr, // "shape|number"
    String? whotChosenShape, // required if cardStr is whot
  }) async {
    final gameRef = firestore.collection('games').doc(gameId);

    await firestore.runTransaction((tx) async {
      final snap = await tx.get(gameRef);
      if (!snap.exists) throw Exception('Game not found');
      final data = snap.data()!;

      final currentTurn = data['turn'] as String?;
      if (currentTurn != playerId) throw Exception('Not your turn');

      // Get player hand
      final hands = Map<String, dynamic>.from(data['hands'] ?? {});
      final playerHand = List<String>.from(_toStringList(hands[playerId] ?? []));
      if (!playerHand.contains(cardStr)) throw Exception('Card not in hand');

      // Pending pick enforcement: if there is a pendingPick for someone else, they must complete it first.
      final int pendingPick = (data['pendingPick'] ?? 0) as int;
      final String? pendingPickOwner = data['pendingPickOwner'] as String?;
      final CardModel playedCard = CardModel.deserialize(cardStr);

      if (pendingPick > 0) {
        // If there is a pending pick, only allow the required victim to draw or a response allowed by house rules.
        // For now: disallow playing another pick card if pendingPick > 0 and the current player is NOT the victim.
        if (pendingPickOwner != playerId) {
          throw Exception('You must resolve pending pick of $pendingPick cards before other moves.');
        }
        // Otherwise, allow the victim to finish picking via drawCards path below.
      }

      // Determine pileTop (may be null on early games)
      final String? pileTopStr = data['pileTop'] as String?;
      final CardModel pileTop = pileTopStr != null
          ? CardModel.deserialize(pileTopStr)
          : CardModel(shape: 'none', number: -1);

      // Validation: WHOT can always be played; other cards must pass rules.validatePlay
      if (playedCard.shape != 'whot' && !rules.validatePlay(pileTop, playedCard)) {
        throw Exception('Invalid play according to rules.');
      }

      // Remove from player's hand
      playerHand.remove(cardStr);
      hands[playerId] = playerHand;

      // Update discard and pileTop
      final List<String> discard = List<String>.from(_toStringList(data['discard']));
      discard.add(cardStr);
      String newPileTop = cardStr;
      String? newWhotChosen = null;

      if (playedCard.shape == 'whot' || playedCard.number == rules.whotNumber) {
        // WHOT requires whotChosenShape provided by UI
        if (whotChosenShape == null || whotChosenShape.isEmpty) {
          throw Exception('WHOT played: a shape must be chosen.');
        }
        newPileTop = '${whotChosenShape}|20';
        newWhotChosen = whotChosenShape;
      } else {
        newWhotChosen = null;
      }

      // Determine players order
      final playersMap = _mapFrom(data['players']);
      final List<String> playersOrder = playersMap.keys.toList();
      final NextAction nextAction = rules.determineNext(
        playersOrder: playersOrder,
        currentPlayerId: playerId,
        played: playedCard,
      );

      // Prepare updated deck/hands variables
      List<String> deck = List<String>.from(_toStringList(data['deck']));
      Map<String, dynamic> newHands = Map<String, dynamic>.from(hands);

      // Handle special effects that force draws (pick2, generalMarket)
      if (nextAction.effect == SpecialEffect.pick2 && nextAction.pickCount > 0) {
        final victim = nextAction.nextPlayerId;
        // Enforce that while these picks are pending, other pick2s cannot be played
        // Perform draws here
        final drawResult = await _drawInsideTransaction(
          tx: tx,
          gameRef: gameRef,
          currentData: {
            'deck': deck,
            'discard': discard,
            'hands': newHands,
          },
          targetPlayerId: victim,
          count: nextAction.pickCount,
        );
        deck = List<String>.from(drawResult['deck']);
        discard.clear();
        discard.addAll(List<String>.from(drawResult['discard']));
        newHands = Map<String, dynamic>.from(drawResult['hands']);

        // Clear pendingPick fields (we executed them immediately)
        // Note: depending on rules you might instead set pendingPick and require victim to draw via UI action.
      } else if (nextAction.effect == SpecialEffect.generalMarket && nextAction.pickCount > 0) {
        final victim = nextAction.nextPlayerId;
        final drawResult = await _drawInsideTransaction(
          tx: tx,
          gameRef: gameRef,
          currentData: {
            'deck': deck,
            'discard': discard,
            'hands': newHands,
          },
          targetPlayerId: victim,
          count: nextAction.pickCount,
        );
        deck = List<String>.from(drawResult['deck']);
        discard.clear();
        discard.addAll(List<String>.from(drawResult['discard']));
        newHands = Map<String, dynamic>.from(drawResult['hands']);
      }

      // Determine next turn based on nextAction and special rules
      String newTurn = nextAction.nextPlayerId;
      if (nextAction.effect == SpecialEffect.holdOn) {
        // same player goes again
        newTurn = playerId;
      } else if (nextAction.effect == SpecialEffect.suspension) {
        // suspension skip handled by determineNext (it returns the correct nextPlayerId)
        // newTurn already set
      } else if (nextAction.effect == SpecialEffect.whot) {
        // Next player is already set by determineNext; whotChosen stored above
      } else {
        // default already set
      }

      // Winner check
      String? winner;
      if ((newHands[playerId] as List).isEmpty) {
        winner = playerId;
      }

      // Build update payload
      final updatePayload = <String, dynamic>{
        'hands': newHands,
        'deck': deck,
        'discard': discard,
        'pileTop': newPileTop,
        'whotChosen': newWhotChosen,
        'turn': newTurn,
        'pendingPick': 0,
        'pendingPickOwner': null,
        'lastAction': {
          'by': playerId,
          'type': 'play',
          'card': cardStr,
          'ts': FieldValue.serverTimestamp(),
        },
      };

      if (winner != null) {
        updatePayload['winner'] = winner;
        updatePayload['status'] = 'finished';
      }

      tx.update(gameRef, updatePayload);
    });
  }

  // ------------------ Allow player to explicitly draw (e.g., when they have no valid card) ------------------

  /// Allows a player to draw N cards (useful for "draw" action if they cannot play)
  // Future<void> drawCards({
  //   required String gameId,
  //   required String playerId,
  //   required int count,
  // }) async {
  //   final gameRef = firestore.collection('games').doc(gameId);

  //   await firestore.runTransaction((tx) async {
  //     final snap = await tx.get(gameRef);
  //     if (!snap.exists) throw Exception('Game not found');
  //     final data = snap.data()!;

  //     final hands = Map<String, dynamic>.from(data['hands'] ?? {});
  //     final deck = List<String>.from(_toStringList(data['deck']));
  //     final discard = List<String>.from(_toStringList(data['discard']));

  //     final result = await _drawInsideTransaction(
  //       tx: tx,
  //       gameRef: gameRef,
  //       currentData: {
  //         'deck': deck,
  //         'discard': discard,
  //         'hands': hands,
  //       },
  //       targetPlayerId: playerId,
  //       count: count,
  //     );

  //     tx.update(gameRef, {
  //       'deck': result['deck'],
  //       'discard': result['discard'],
  //       'hands': result['hands'],
  //       'lastAction': {
  //         'by': playerId,
  //         'type': 'draw',
  //         'count': count,
  //         'ts': FieldValue.serverTimestamp(),
  //       }
  //     });
  //   });
  // }
//   Future<void> drawCards({
//   required String gameId,
//   required String playerId,
//   required int count,
// }) async {
//   final gameRef = firestore.collection('games').doc(gameId);

//   await firestore.runTransaction((tx) async {
//     final snap = await tx.get(gameRef);
//     if (!snap.exists) throw Exception('Game not found');
//     final data = snap.data()!;

//     final hands = Map<String, dynamic>.from(data['hands'] ?? {});
//     final deck = List<String>.from(_toStringList(data['deck']));
//     final discard = List<String>.from(_toStringList(data['discard']));
//     final pending = data['pendingAction'];

//     // 🔹 Perform the actual draw
//     final result = await _drawInsideTransaction(
//       tx: tx,
//       gameRef: gameRef,
//       currentData: {
//         'deck': deck,
//         'discard': discard,
//         'hands': hands,
//       },
//       targetPlayerId: playerId,
//       count: count,
//     );

//     final updates = {
//       'deck': result['deck'],
//       'discard': result['discard'],
//       'hands': result['hands'],
//       'lastAction': {
//         'by': playerId,
//         'type': 'draw',
//         'count': count,
//         'ts': FieldValue.serverTimestamp(),
//       },
//     };

//     // 🔹 Handle "Pick Two" or "General Market" resolution
//     if (pending != null && pending['type'] == 'pick') {
//       final from = pending['from'];
//       final pendingCount = pending['count'];

//       // Check if this draw resolves the pending pick
//       if (count >= pendingCount) {
//         updates['turn'] = from;
//         updates['pendingAction'] = null;
//       }
//     }

//     tx.update(gameRef, updates);
//   });
// }




Future<void> drawCards({
  required String gameId,
  required String playerId,
  required int count,
}) async {
  final gameRef = firestore.collection('games').doc(gameId);

  await firestore.runTransaction((tx) async {
    final snap = await tx.get(gameRef);
    if (!snap.exists) throw Exception('Game not found');
    final data = snap.data()!;

    final hands = Map<String, dynamic>.from(data['hands'] ?? {});
    final deck = List<String>.from(_toStringList(data['deck']));
    final discard = List<String>.from(_toStringList(data['discard']));
    final forcedDraw = data['forcedDraw'];

    int actualCount = count;
    String nextTurn = data['currentTurn'];

    if (forcedDraw != null && forcedDraw['playerId'] == playerId) {
      // This player is forced to draw cards (from 2 or 14)
      actualCount = forcedDraw['count'];
      nextTurn = data['players'].firstWhere((p) => p != playerId);
    }

    final result = await _drawInsideTransaction(
      tx: tx,
      gameRef: gameRef,
      currentData: {
        'deck': deck,
        'discard': discard,
        'hands': hands,
      },
      targetPlayerId: playerId,
      count: actualCount,
    );

    tx.update(gameRef, {
      'deck': result['deck'],
      'discard': result['discard'],
      'hands': result['hands'],
      'currentTurn': nextTurn,
      'forcedDraw': null,
      'lastAction': {
        'by': playerId,
        'type': 'draw',
        'count': actualCount,
        'ts': FieldValue.serverTimestamp(),
      }
    });
  });
}


  // ------------------ Check winner and award coins (non-transactional across external systems) ------------------

  /// Award coins to winner and clear currentGameId for both players.
  /// mysqlSyncCallback is optional and will be called (best-effort) after Firestore updates to mirror balance to MySQL.
  Future<void> awardWinnerCoins({
    required String gameId,
    required String winnerUid,
    required int amount,
    Future<void> Function(String uid, int newBalance)? mysqlSyncCallback,
  }) async {
    final gameRef = firestore.collection('games').doc(gameId);
    final usersRef = firestore.collection('users');

    // We'll perform Firestore updates in a transaction (award coins, clear currentGameId)
    await firestore.runTransaction((tx) async {
      final gameSnap = await tx.get(gameRef);
      if (!gameSnap.exists) throw Exception('Game not found');

      final gameData = gameSnap.data()!;
      final playersMap = _mapFrom(gameData['players']);
      final List<String> playerUids = playersMap.keys.toList();

      // Update winner balance and clear currentGameId for both players
      for (final uid in playerUids) {
        final userRef = usersRef.doc(uid);
        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) continue;
        final userData = userSnap.data()!;
        final int curBal = (userData['balance'] ?? 0) as int;
        final int newBal = (uid == winnerUid) ? (curBal + amount) : curBal;
        tx.update(userRef, {
          'balance': newBal,
          'currentGameId': null,
        });
      }

      // Update game status to closed (redundant if already closed)
      tx.update(gameRef, {
        'status': 'finished',
        'rewardGiven': true,
        'rewardAmount': amount,
        'rewardTs': FieldValue.serverTimestamp(),
      });
    });

    // After transaction completes, call mysqlSyncCallback for each player (best-effort)
    if (mysqlSyncCallback != null) {
      try {
        final gameSnap = await gameRef.get();
        final gameData = gameSnap.data()!;
        final playersMap = _mapFrom(gameData['players']);
        for (final uid in playersMap.keys) {
          final userSnap = await firestore.collection('users').doc(uid).get();
          final newBal = (userSnap.data()?['balance'] ?? 0) as int;
          await mysqlSyncCallback(uid, newBal);
        }
      } catch (e) {
        // best-effort; do not fail if mysql sync fails
      }
    }
  }

  // ------------------ Utility: Stream game doc ------------------

  /// Stream a game's document snapshots for UI
  Stream<DocumentSnapshot<Map<String, dynamic>>> gameStream(String gameId) {
    return firestore.collection('games').doc(gameId).snapshots();
  }

  // ------------------ Optional: Force end game (e.g., for disconnect/timeouts) ------------------

  /// Forcefully end a game and mark winner (used for disconnect or admin)
  Future<void> forceEndGame({
    required String gameId,
    required String winnerUid,
  }) async {
    final gameRef = firestore.collection('games').doc(gameId);
    await gameRef.update({
      'status': 'finished',
      'winner': winnerUid,
      'endedBy': 'force',
      'endedAt': FieldValue.serverTimestamp(),
    });

    // Optionally award coins (call awardWinnerCoins externally)
  }


  // 🟩 Generate 50 cards (1–14), excluding Whot (20)
// Each number appears multiple times to reach 50 total
List<String> generateDeck() {
 
  List<String> shapes = ['circle', 'cross', 'triangle', 'square'];
  List<String> deck = [];



  // 🔹 Generate numbers 1–14 for each shape (no Whot)
  for (var shape in shapes) {
    for (int number = 1; number <= 14; number++) {
      deck.add('$shape-$number');
    }
  }

  // 🔹 Optional: Uncomment if you ever want to add Whot cards later
  // for (int i = 0; i < 2; i++) {
  //   deck.add('whot-20');
  // }

  // 🔹 Shuffle deck
  deck.shuffle();

  // 🔹 Ensure exactly 50 cards (slice down if needed)
  deck = deck.take(50).toList();

  print('Generated deck count: ${deck.length}');
  print('First few cards: ${deck.take(5).toList()}');

  return deck;
}

  


  /// Creates a new game session between two players
/// - [players] is a list of two user IDs [player1, player2]
/// - [hostUid] is the user who initiated the match
/// This function also deducts 50 coins from both players before starting.
Future<String> createGame(List<String> players, String hostUid) async {
  if (players.length != 2) {
    throw Exception("createGame() requires exactly 2 players.");
  }

  final player1 = players[0];
  final player2 = players[1];
  final opponentUid = hostUid == player1 ? player2 : player1;

  final firestore = FirebaseFirestore.instance;
  final userRef = firestore.collection('users');

  // Fetch both users
  final user1Snap = await userRef.doc(player1).get();
  final user2Snap = await userRef.doc(player2).get();

  if (!user1Snap.exists || !user2Snap.exists) {
    throw Exception("One or both users do not exist.");
  }

  final user1 = user1Snap.data()!;
  final user2 = user2Snap.data()!;

  // Check balance
  if (user1['balance'] < 50 || user2['balance'] < 50) {
    throw Exception("One of the players has insufficient coins.");
  }

  // Deduct 50 coins from each
  await firestore.runTransaction((transaction) async {
    transaction.update(userRef.doc(player1), {'balance': user1['balance'] - 50});
    transaction.update(userRef.doc(player2), {'balance': user2['balance'] - 50});
  });

  // Build a fresh Whot deck
  //final deck = _buildDeck();
  final deck = generateDeck();
  

  // Deal 5 cards each
  final player1Hand = deck.sublist(0, 5);
  final player2Hand = deck.sublist(5, 10);
  final remainingDeck = deck.sublist(10);

  // Set the first card on table
  final currentCard = remainingDeck.removeAt(0);

  // Create game document
  final gameDoc = await firestore.collection('games').add({
    'players': [player1, player2],
    'hands': {
      player1: player1Hand,
      player2: player2Hand,
    },
    'deck': remainingDeck,
    'currentCard': currentCard,
    'turn': hostUid,
    'winner': null,
    'status': 'active',
    'createdAt': FieldValue.serverTimestamp(),
  });

  return gameDoc.id;
}

/// Builds a Whot deck with the standard Naija Whot cards.


}
