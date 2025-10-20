import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';
import 'game_service.dart';

class MatchmakingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final GameService _gameService = GameService();

  /// Add player to matchmaking lobby
  Future<String?> enterMatchmaking() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final player = await _userService.getUserData(user.uid);
    final coins = player['balance'] ?? 0;

    // Must have at least 50 coins
    if (coins < 50) {
      throw Exception('You need at least 50 coins to play.');
    }

    // Add player to matchmaking collection
    await _firestore.collection('matchmaking').doc(user.uid).set({
      'uid': user.uid,
      'username': player['username'],
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Try to find another player
    final snapshot = await _firestore.collection('matchmaking').get();

    for (var doc in snapshot.docs) {
      final opponent = doc.data();
      if (opponent['uid'] != user.uid) {
        // Found opponent, create game
        final gameId = await _gameService.createGame([user.uid,opponent['uid']], opponent['uid']);

        // Deduct coins
        await _userService.updateUserBalance(user.uid, coins - 50);
        await _userService.updateUserBalance(opponent['uid'], (await _userService.getUserData(opponent['uid']))['balance'] - 50);

        // Remove both from matchmaking
        await _firestore.collection('matchmaking').doc(user.uid).delete();
        await _firestore.collection('matchmaking').doc(opponent['uid']).delete();

        return gameId;
      }
    }

    // No match found yet
    return null;
  }

  /// Leave matchmaking (if waiting too long or canceled)
  Future<void> leaveMatchmaking() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('matchmaking').doc(user.uid).delete();
    }
  }
}
