// lib/screens/gameplay_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GamePlayScreen extends StatefulWidget {
  final String gameId;
  final String myUid;
  final int myBalance;

  const GamePlayScreen({
    Key? key,
    required this.gameId,
    required this.myUid,
    required this.myBalance,
  }) : super(key: key);

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _gameStream;
  bool _initializing = false;
  bool _winDialogShown = false; // prevent multiple dialogs

  @override
  void initState() {
    super.initState();
    _gameStream = _firestore.collection('games').doc(widget.gameId).snapshots();
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
//   Future<void> playCard({
//   required String gameId,
//   required String playerId,
//   required Map<String, dynamic> card,
// }) async {
//   final gameDoc = FirebaseFirestore.instance.collection('games').doc(gameId);
//   final snapshot = await gameDoc.get();
//   if (!snapshot.exists) return;

//   final gameData = snapshot.data()!;
//   final players = List<String>.from(gameData['players']);
//   final currentTurn = gameData['currentTurn'];
//   final nextPlayerId = players.firstWhere((p) => p != playerId);

//   // Add played card to discard pile
//   final discardPile = List<Map<String, dynamic>>.from(gameData['discardPile'] ?? []);
//   discardPile.add(card);

//   // Remove card from player's hand
//   final playerHands = Map<String, dynamic>.from(gameData['playerHands']);
//   final playerCards = List<Map<String, dynamic>>.from(playerHands[playerId]);
//   playerCards.removeWhere((c) => c['shape'] == card['shape'] && c['number'] == card['number']);
//   playerHands[playerId] = playerCards;

//   // Default next turn
//   String nextTurn = nextPlayerId;

//   // 🃏 Apply Whot Rules
//   switch (card['number']) {
//     case 1: // Hold On → same player plays again
//       nextTurn = playerId;
//       break;

//     case 2: // Pick 2 → opponent picks 2 cards, player continues
//       final opponentCards = List<Map<String, dynamic>>.from(playerHands[nextPlayerId]);
//       final deck = List<Map<String, dynamic>>.from(gameData['deck']);
//       for (var i = 0; i < 2 && deck.isNotEmpty; i++) {
//         opponentCards.add(deck.removeAt(0));
//       }
//       playerHands[nextPlayerId] = opponentCards;
//       nextTurn = playerId;
//       break;

//     case 8: // Suspension → opponent misses turn
//       nextTurn = playerId;
//       break;

//     case 14: // General Market → opponent picks one card, player continues
//       final opponentCards = List<Map<String, dynamic>>.from(playerHands[nextPlayerId]);
//       final deck = List<Map<String, dynamic>>.from(gameData['deck']);
//       if (deck.isNotEmpty) {
//         opponentCards.add(deck.removeAt(0));
//       }
//       playerHands[nextPlayerId] = opponentCards;
//       nextTurn = playerId;
//       break;

//     default:
//       // Normal play → next player's turn
//       nextTurn = nextPlayerId;
//   }

//   // Save game state
//   await gameDoc.update({
//     'playerHands': playerHands,
//     'discardPile': discardPile,
//     'deck': gameData['deck'],
//     'currentTurn': nextTurn,
//   });

//   // 🏆 Check for winner
//   if (playerHands[playerId].isEmpty) {
//     await gameDoc.update({
//       'winner': playerId,
//       'status': 'ended',
//     });
//   }
// }

// Future<void> playCard(String rawCard) async {
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

//     // 🟦 Default: Next player's turn
//     String nextTurn = opponent;
//     final updates = <String, dynamic>{
//       'hands': hands,
//       'topCard': card,
//       'shapeInPlay': card.split('-')[0],
//       'requiredCard': '',
//     };

//     // 🟥 --- APPLY NAIJA WHOT RULES ---
//     switch (cardNumber) {
//       case 1: // Hold On
//         nextTurn = widget.myUid; // play again
//         break;

//       case 2: // Pick Two
//         final oppHand = List<String>.from((hands[opponent] ?? []).map(_normalizeCard));
//         final deck = List<String>.from(data['deck'] ?? []);
//         if (deck.length >= 2) {
//           oppHand.insert(0, deck.removeAt(0));
//           oppHand.insert(0, deck.removeAt(0));
//         }
//         hands[opponent] = oppHand;
//         updates['deck'] = deck;
//         nextTurn = widget.myUid; // still your turn
//         break;

//       case 8: // Suspension
//         nextTurn = widget.myUid; // skip opponent
//         break;

//       case 14: // General Market
//         final oppHand2 = List<String>.from((hands[opponent] ?? []).map(_normalizeCard));
//         final deck2 = List<String>.from(data['deck'] ?? []);
//         if (deck2.isNotEmpty) {
//           oppHand2.insert(0, deck2.removeAt(0)); // opponent picks one
//         }
//         hands[opponent] = oppHand2;
//         updates['deck'] = deck2;
//         nextTurn = widget.myUid; // still your turn
//         break;
//     }

//     updates['turn'] = nextTurn;

//     tx.update(gameRef, updates);
//   });
// }



// Future<void> playCard(String rawCard) async {
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
//         nextTurn = widget.myUid; // player plays again
//         break;

//       case 2: // Pick Two
//         // opponent's turn but only to pick 2
//         nextTurn = opponent;
//         updates['pendingAction'] = {
//           'type': 'pick',
//           'count': 2,
//           'from': widget.myUid,
//         };
//         break;

//       case 8: // Suspension
//         // skip opponent
//         nextTurn = widget.myUid;
//         break;

//       case 14: // General Market
//         // opponent's turn but only to pick 1
//         nextTurn = opponent;
//         updates['pendingAction'] = {
//           'type': 'pick',
//           'count': 1,
//           'from': widget.myUid,
//         };
//         break;
//     }

//     updates['turn'] = nextTurn;
//     tx.update(gameRef, updates);
//   });


// }

Future<void> playCard(String rawCard) async {
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








Future<void> playCardss(String rawCard) async {
  final card = _normalizeCard(rawCard);
  final gameRef = _firestore.collection('games').doc(widget.gameId);

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
      myHand.remove(card);
      hands[widget.myUid] = myHand;

      final players = _playersFromData(data);
      final next = players.firstWhere((p) => p != widget.myUid, orElse: () => widget.myUid);

      tx.update(gameRef, {
        'hands': hands,
        'topCard': 'whot',
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

    final topCard = _normalizeCard(data['topCard']);
    final requiredCard = (data['requiredCard'] ?? '').toString().toLowerCase();

    if (!_cardAllowed(card, topCard, requiredCard)) return;

    final hands = Map<String, dynamic>.from(data['hands'] ?? {});
    final myHand = List<String>.from((hands[widget.myUid] ?? []).map(_normalizeCard));
    myHand.remove(card);
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
        nextTurn = widget.myUid;
        break;

      case 2: // Pick Two
        updates['pendingAction'] = {
          'type': 'force_pick',
          'count': 2,
          'target': opponent,
          'from': widget.myUid,
        };
        break;

      case 8: // Suspension
        nextTurn = widget.myUid;
        break;

      case 14: // General Market
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
    if (deck.isEmpty) return;

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


  // Future<void> pickCard(String playerId) async {
  //   final ref = _firestore.collection('games').doc(widget.gameId);
  //   await _firestore.runTransaction((tx) async {
  //     final snap = await tx.get(ref);
  //     if (!snap.exists) return;
  //     final data = snap.data() ?? {};
  //     final turn = data['turn'];
  //     if (turn != playerId) return;

  //     final hands = Map<String, dynamic>.from(data['hands'] ?? {});
  //     final myHand = List<String>.from((hands[playerId] ?? []).map(_normalizeCard));

  //     List<String> deck = [];
  //     if (data['deck'] is List) deck = (data['deck'] as List).map<String>(_normalizeCard).toList();
  //     if (deck.isEmpty) return;

  //     final newCard = deck.removeLast();
  //     myHand.insert(0, newCard); // insert to front
  //     hands[playerId] = myHand;

  //     final players = _playersFromData(data);
  //     final next = players.firstWhere((p) => p != playerId, orElse: () => playerId);

  //     tx.update(ref, {'deck': deck, 'hands': hands, 'turn': next});
  //   });
  // }

  Widget _cardWidget(String card, {bool playable = true, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        width: 72,
        height: 100,
        decoration: BoxDecoration(
          color: playable ? Colors.white : Colors.grey.shade700,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: playable ? Colors.yellow : Colors.black26, width: 2),
        ),
        child: Center(
          child: Text(
            card.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Future<void> _showWinDialog(String winnerId) async {
    if (_winDialogShown) return;
    _winDialogShown = true;

    await _firestore.collection('games').doc(widget.gameId).update({'status': 'ended'});

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('🏆 Game Over'),
        content: Text(winnerId == widget.myUid
            ? 'Congratulations! You won the game.'
            : '$winnerId has won the game!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade900,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _gameStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.white)));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final doc = snap.data!;
          final data = doc.data() ?? {};
          _transactionalInitIfNeeded();

          final players = _playersFromData(data);
          if (players.isEmpty) {
            return const Center(child: Text('Waiting for opponent...', style: TextStyle(color: Colors.white)));
          }

          final myUid = widget.myUid;
          final opponentId = players.firstWhere((p) => p != myUid, orElse: () => '');
          final hands = Map<String, dynamic>.from(data['hands'] ?? {});
          final myHand = List<String>.from((hands[myUid] ?? []).map(_normalizeCard));
          final opponentHand = List<String>.from((hands[opponentId] ?? []).map(_normalizeCard));

          // WIN CHECK
          // if (!_winDialogShown) {
          //   if (myHand.isEmpty) {
          //     Future.microtask(() => _showWinDialog(myUid));
          //   } else if (opponentId.isNotEmpty && opponentHand.isEmpty) {
          //     Future.microtask(() => _showWinDialog(opponentId));
          //   }
          // }

          // ✅ SAFE WIN CHECK FIX
final handsExist = hands.isNotEmpty && hands[widget.myUid] != null && hands[opponentId] != null;

// Ensure the game has actually started — topCard must exist and deck must not be empty
//final bool gameStarted = (topCard != null && topCard.toString().isNotEmpty && deck.isNotEmpty);
//if (gameStarted && handsExist && !_winDialogShown) {

if ( handsExist && !_winDialogShown) {
  if (myHand.isEmpty) {
    Future.microtask(() => _showWinDialog(widget.myUid));
  } else if (opponentId.isNotEmpty && opponentHand.isEmpty) {
    Future.microtask(() => _showWinDialog(opponentId));
  }
}

          final topCard = _normalizeCard(data['topCard']);
          final requiredCard = (data['requiredCard'] ?? '').toString().toLowerCase();
          final currentTurn = (data['turn'] ?? '').toString();
          final deck = (data['deck'] is List)
              ? (data['deck'] as List).map<String>(_normalizeCard).toList()
              : [];

          final isMyTurn = currentTurn == myUid;
          final myHandPlayability = myHand.map((c) => _cardAllowed(c, topCard, requiredCard)).toList();

          return SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(opponentId.isNotEmpty ? opponentId : 'Opponent', style: const TextStyle(color: Colors.white, fontSize: 16)),
                      Text(myUid, style: const TextStyle(color: Colors.yellowAccent, fontSize: 16)),
                    ],
                  ),
                ),

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
                          decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ),

                // Center cards + info
                Column(
                  children: [
                    Text(topCard.isNotEmpty ? "Top: ${topCard.toUpperCase()}" : "Top: -", style: const TextStyle(color: Colors.yellow, fontSize: 18)),
                    if (requiredCard.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text("Required: ${requiredCard.toUpperCase()}", style: const TextStyle(color: Colors.redAccent)),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: isMyTurn ? () => pickCard(myUid) : null,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(width: 80, height: 120, decoration: BoxDecoration(color: Colors.blueGrey.shade700, borderRadius: BorderRadius.circular(12))),
                              Text("MARKET\n(${deck.length})", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Container(
                          width: 100,
                          height: 140,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: Text(topCard.isNotEmpty ? topCard.toUpperCase() : '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(isMyTurn ? "Your Turn" : "Opponent's Turn", style: TextStyle(color: isMyTurn ? Colors.lightGreenAccent : Colors.white, fontSize: 16)),
                  ],
                ),

                // My Hand
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: List.generate(myHand.length, (i) {
                      final c = myHand[i];
                      final playable = myHandPlayability[i] && isMyTurn;
                      return _cardWidget(c, playable: playable, onTap: playable ? () => playCard(c) : null);
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
