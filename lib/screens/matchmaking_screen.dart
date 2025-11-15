// lib/screens/matchmaking_screen.dart
//
// Matchmaking screen (robust, race-safe)
// - Writes current user to `waiting_room/{uid}`
// - Searches for another waiting user and claims them via transaction
// - Deducts entry fee (50) before creating the game
// - Calls GameService.createGame([player1, player2], hostUid)
// - Navigates to GamePlayScreen(gameId: ..., myUid: ..., myBalance: ...)
//
// Assumptions:
// - UserService provides: getUserData(uid) -> Map, deductCoins(uid, amount) -> bool
// - GameService provides: createGame(List<String> players, String hostUid) -> Future<String>
//
// Note: Adjust collection names if you use different ones.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/user_service.dart';
import '../services/game_service.dart';
import 'gameplay_screen.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _userSvc = UserService();
  final _gameSvc = GameService();

  String? myUid;
  int myBalance = 0;
  bool _searching = false;
  String _status = "Initializing...";
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _waitingSub;

  static const int entryFee = 50;
  final String waitingCollection = 'waiting_room';

  @override
  void initState() {
    super.initState();
    _initAndStart();
  }

  @override
  void dispose() {
    _waitingSub?.cancel();
    super.dispose();
  }

  Future<void> _initAndStart() async {
    final user = _auth.currentUser;
    if (user == null) {
      // Not signed in - return to previous screen
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }
    myUid = user.uid;

    try {
      final data = await _userSvc.getUserData(myUid!);
      setState(() {
        myBalance = (data['balance'] ?? 0) as int;
        _status = "Ready to match";
      });
      // Start matchmaking automatically
      _startMatchmaking();
    } catch (e) {
      _showAlert("Error", "Failed to load user data: $e");
      setState(() => _status = "Error loading user");
    }
  }

  Future<void> _startMatchmaking() async {
    if (_searching) return;
    if (myUid == null) return;

    if (myBalance < entryFee) {
      _showAlert("Low Balance", "You need at least $entryFee coins to play.");
      return;
    }

    setState(() {
      _searching = true;
      _status = "Joining waiting room...";
    });

    // Put myself into waiting_room with a timestamp
    final myWaitingRef = _firestore.collection(waitingCollection).doc(myUid);
    try {
      await myWaitingRef.set({
        'uid': myUid,
        'ts': FieldValue.serverTimestamp(),
      });

      setState(() => _status = "Searching for opponent...");

      // Subscribe to waiting_room snapshot changes; this helps detect opponents fast
      _waitingSub = _firestore
          .collection(waitingCollection)
          .snapshots()
          .listen((snapshot) {
        if (!_searching) return;
        _tryClaimOpponent();
      });

      // Try once immediately (no need to wait for subscription)
      await _tryClaimOpponent();
    } catch (e) {
      _showAlert("Error", "Could not enter waiting room: $e");
      await _cleanupWaiting();
      setState(() {
        _searching = false;
        _status = "Failed to join waiting room";
      });
    }
  }

  /// Tries to find and atomically claim an opponent.
  /// This uses a short Firestore transaction to avoid race conditions where two clients
  /// try to claim the same opponent at the same time.
  Future<void> _tryClaimOpponent() async {
    if (myUid == null) return;

    // Query one opponent that is not me
    final q = await _firestore
        .collection(waitingCollection)
        .where('uid', isNotEqualTo: myUid)
        .orderBy('ts') // oldest waiting first
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      // no opponent yet; keep waiting
      setState(() => _status = "No opponent yet, still waiting...");
      return;
    }

    final opponentDoc = q.docs.first;
    final opponentUid = opponentDoc.data()['uid'] as String?;

    if (opponentUid == null || opponentUid.isEmpty) {
      // malformed doc - remove it
      await opponentDoc.reference.delete();
      return;
    }

    // Attempt to claim both users and create game in a transaction
    final gameRef = _firestore.collection('games').doc();

    try {
      await _firestore.runTransaction((tx) async {
        // Re-read both waiting docs inside transaction to ensure they still exist
        final oppSnap = await tx.get(opponentDoc.reference);
        final mySnap = await tx.get(_firestore.collection(waitingCollection).doc(myUid));

        if (!oppSnap.exists) {
          // opponent taken by someone else
          throw Exception("Opponent no longer available");
        }
        if (!mySnap.exists) {
          // we were removed from waiting_room - abort
          throw Exception("You are no longer in waiting room");
        }

        // Check both users still have enough balance (read user docs)
        final user1Snap = await tx.get(_firestore.collection('users').doc(myUid));
        final user2Snap = await tx.get(_firestore.collection('users').doc(opponentUid));

        if (!user1Snap.exists || !user2Snap.exists) {
          throw Exception("User records missing");
        }

        final int bal1 = (user1Snap.data()?['balance'] ?? 0) as int;
        final int bal2 = (user2Snap.data()?['balance'] ?? 0) as int;
        if (bal1 < entryFee) throw Exception("You have insufficient coins");
        if (bal2 < entryFee) throw Exception("Opponent has insufficient coins");

        // Deduct entry fee from both users' balances
        tx.update(_firestore.collection('users').doc(myUid), {'balance': bal1 - entryFee, 'currentGameId': gameRef.id});
        tx.update(_firestore.collection('users').doc(opponentUid), {'balance': bal2 - entryFee, 'currentGameId': gameRef.id});

        // Remove both from waiting room
        tx.delete(opponentDoc.reference);
        tx.delete(_firestore.collection(waitingCollection).doc(myUid));

        // Build deck and hands (simple serialized "shape|number" strings)
        final deck = _gameSvc.generateDeck(); //_buildDeck();
        // deck.shuffle();

        final int handSize = 5;
        final List<String> hand1 = deck.sublist(0, handSize);
        final List<String> hand2 = deck.sublist(handSize, handSize * 2);
        final List<String> remaining = deck.sublist(handSize * 2);

        // initial discard/pileTop
        String? pileTop;
        final List<String> discard = [];
        if (remaining.isNotEmpty) {
          discard.add(remaining.removeAt(0));
          pileTop = discard.last;
        }

        // Create the game document
        tx.set(gameRef, {
          'players': { myUid!: { 'joinedAt': FieldValue.serverTimestamp() }, opponentUid: { 'joinedAt': FieldValue.serverTimestamp() } },
          'hands': { myUid!: hand1, opponentUid: hand2 },
          'deck': remaining,
          'discard': discard,
          'pileTop': pileTop,
          'whotChosen': null,
          'turn': myUid, // host (you) start
          'pendingPick': 0,
          'pendingPickOwner': null,
          'status': 'playing',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      // Transaction succeeded and game doc created
      // navigate to gameplay screen
      if (!mounted) return;
      setState(() {
        _searching = false;
        _status = "Match found!";
      });

      final createdGame = await _firestore
          .collection('games')
          .where('players.${myUid!}', isGreaterThan: null)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      String gameId;
      if (createdGame.docs.isNotEmpty) {
        gameId = createdGame.docs.first.id;
      } else {
        // fallback: query games where currentGameId on user equals something
        final myDoc = await _firestore.collection('users').doc(myUid).get();
        gameId = (myDoc.data()?['currentGameId'] as String?) ?? '';
      }

      // fetch updated balance to pass to gameplay screen
      final updatedUser = await _firestore.collection('users').doc(myUid).get();
      final updatedBalance = (updatedUser.data()?['balance'] ?? 0) as int;

      if (gameId.isEmpty) {
        _showAlert("Error", "Could not find created game id.");
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GamePlayScreen(
            gameId: gameId,
            myUid: myUid!,
           
          ),
        ),
      );

    } catch (e) {
      // transaction failed (opponent claimed, insufficient balance, etc.)
      // keep searching but update UI
      setState(() {
        _status = "Retrying search (${e.toString()})";
      });
    }
  }

  /// Clean up waiting room entry if user leaves
  Future<void> _cleanupWaiting() async {
    if (myUid == null) return;
    try {
      final ref = _firestore.collection(waitingCollection).doc(myUid);
      final doc = await ref.get();
      if (doc.exists) await ref.delete();
    } catch (_) {}
  }

  /// Helper - build deck as List<String> "shape|number"


  /// Cancel matchmaking and go back
  Future<void> _cancel() async {
    await _cleanupWaiting();
    if (mounted) Navigator.pop(context);
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[800],
      appBar: AppBar(
        title: const Text('Matchmaking'),
        backgroundColor: Colors.green[900],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 20),
            _searching
                ? Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _cancel,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        child: const Text('Cancel'),
                      ),
                    ],
                  )
                : ElevatedButton(
                    onPressed: _startMatchmaking,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Start Search'),
                  ),
          ],
        ),
      ),
    );
  }
}
