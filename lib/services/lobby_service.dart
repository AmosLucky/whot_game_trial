import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Remove player from lobby list
  Future<void> removePlayerFromLobby(String uid) async {
    await _firestore.collection('lobby').doc(uid).delete().catchError((_) {});
    await updatePlayerStatus(uid, 'offline');
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
  Future<String?> tryMatchPlayers(String myUid) async {
    final lobbySnapshot = await _firestore.collection('lobby').get();
    final waitingPlayers = lobbySnapshot.docs.map((e) => e.id).toList();

    final opponent = waitingPlayers.firstWhere(
      (uid) => uid != myUid,
      orElse: () => '',
    );

    if (opponent.isNotEmpty) {
      final gameDoc = await _firestore.collection('games').add({
        'players': [myUid, opponent],
        'turn': myUid,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // remove from lobby
      await _firestore.collection('lobby').doc(myUid).delete();
      await _firestore.collection('lobby').doc(opponent).delete();

      // update status
      await updatePlayerStatus(myUid, 'in_game');
      await updatePlayerStatus(opponent, 'in_game');

      // initialize deck and hands
      await initializeGameCards(gameDoc.id, [myUid, opponent]);

      return gameDoc.id;
    }

    return null;
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

  /// Generate standard Whot deck
  List<Map<String, dynamic>> _generateWhotDeck() {
    final shapes = ['circle', 'cross', 'triangle', 'square', 'star'];
    final cards = <Map<String, dynamic>>[];

    for (var shape in shapes) {
      for (var num = 1; num <= 14; num++) {
        cards.add({'shape': shape, 'number': num});
      }
    }

    // Add Whot cards (20)
    for (var i = 0; i < 4; i++) {
      cards.add({'shape': 'whot', 'number': 20});
    }

    return cards;
  }
}
