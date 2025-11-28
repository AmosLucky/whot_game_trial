// lib/screens/game_screen.dart
//
// Full gameplay screen for Naija Whot
// - Subscribes to games/{gameId} document via GameService.gameStream
// - Renders opponent info, pile top, deck count, player's hand
// - Handles playing cards (including WHOT shape selection), drawing cards
// - Shows popups for special actions (Pick 2, General Market, Hold On, Suspension)
// - Plays sounds for card-play and win/lose
// - Shows a winner dialog and cleans up UI
//
// This file expects:
// - lib/services/game_service.dart (GameService class)
// - lib/models/card_model.dart (CardModel with serialize/deserialize)
// - lib/widgets/whot_dialog.dart (WhotDialog widget)
// - lib/widgets/action_popup.dart (ActionPopup widget)
// - lib/widgets/win_dialog.dart (WinDialog widget)
// - lib/widgets/card_widget.dart (CardWidget for visual card display)
// - lib/services/sound_service.dart (SoundService for sound effects)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/card_model.dart';
import '../../services/game_service.dart';
import '../../services/sound_service.dart';
import '../../widgets/whot_dialog.dart';
import '../../widgets/action_popup.dart';
import '../../widgets/win_dialog.dart';
import '../../widgets/card_widget.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String myUid;

  const GameScreen({super.key, required this.gameId, required this.myUid});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final GameService _gameService = GameService();
  final SoundService _sound = SoundService();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _gameSub;
  Map<String, dynamic>? _gameData;

  bool _isLoading = true;
  bool _showActionPopup = false;
  String _actionMessage = '';
  bool _isWinnerDialogShown = false;

  // simple animation controller for winner celebration
  late final AnimationController _celebrateController;

  @override
  void initState() {
    super.initState();
    _celebrateController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _start();
  }

  @override
  void dispose() {
    _gameSub?.cancel();
    _celebrateController.dispose();
    _sound.stopBackground();
    super.dispose();
  }

  Future<void> _start() async {
    // start background music (optional)
    try {
      await _sound.playBackground();
    } catch (_) {}

    // subscribe to game doc
    _gameSub = _gameService.gameStream(widget.gameId).listen((snap) {
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      setState(() {
        _gameData = Map<String, dynamic>.from(data);
        _isLoading = false;
      });

      // If winner is set and we haven't shown dialog, show it
      final winner = _gameData!['winner'] as String?;
      if (winner != null && !_isWinnerDialogShown) {
        _onGameFinished(winner);
      }
    }, onError: (err) {
      // handle stream error (network etc.)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Game stream error: $err')));
      }
    });
  }

  // ----------------- Helpers to read the game doc -----------------

  String? get _currentTurn => _gameData?['turn'] as String?;
  List<String> get _playersOrder {
    final playersMap = _gameData?['players'];
    if (playersMap is Map) {
      return playersMap.keys.cast<String>().toList();
    }
    if (_gameData?['players'] is List) {
      return List<String>.from(_gameData!['players'] as List);
    }
    return [];
  }

  Map<String, List<String>> get _hands {
    final raw = _gameData?['hands'];
    if (raw is Map) {
      final m = <String, List<String>>{};
      raw.forEach((k, v) {
        m[k] = List<String>.from(v ?? []);
      });
      return m;
    }
    return {};
  }

  String? get _pileTopRaw => _gameData?['pileTop'] as String?;
  CardModel? get _pileTop => _pileTopRaw != null ? CardModel.deserialize(_pileTopRaw!) : null;
  String? get _whotChosen => _gameData?['whotChosen'] as String?;
  int get _deckCount => (_gameData?['deck'] as List?)?.length ?? 0;
  int get _pendingPick => (_gameData?['pendingPick'] ?? 0) as int;

  // determine opponent uid (works for 2-player games)
  String? get _opponentUid {
    final players = _playersOrder;
    if (players.isEmpty) return null;
    return players.firstWhere((id) => id != widget.myUid, orElse: () => players.first);
  }

  // get opponent hand size (for display only)
  int get _opponentHandCount {
    final hands = _hands;
    final opp = _opponentUid;
    if (opp == null) return 0;
    return hands[opp]?.length ?? 0;
  }

  // my hand as list of CardModel
  List<CardModel> get _myHand {
    final hands = _hands;
    final myList = hands[widget.myUid] ?? <String>[];
    return myList.map((s) {
      try {
        return CardModel.deserialize(s);
      } catch (_) {
        return CardModel(shape: 'back', number: -1);
      }
    }).toList();
  }

  bool get _isMyTurn => _currentTurn == widget.myUid;

  // ----------------- UI actions -----------------

  Future<void> _onCardTap(CardModel card) async {
    if (!_isMyTurn) {
      _showTemporaryAction("Not your turn");
      return;
    }

    final cardStr = card.serialize();

    // If card is WHOT, show shape selection dialog
    String? chosenShape;
    if (card.shape == 'whot' || card.number == 20) {
      chosenShape = await showDialog<String>(
        context: context,
        builder: (_) => WhotDialog(
          onSelect: (shape) {
            // WhotDialog calls onSelect then pops itself (we follow same pattern)
            Navigator.of(context).pop(shape);
          },
        ),
      );
      if (chosenShape == null) {
        // user cancelled
        return;
      }
    }

    // Play card via GameService (transaction)
    try {
      // await _gameService.playCard(
      //   gameId: widget.gameId,
      //   playerId: widget.myUid,
      //   cardStr: cardStr,
      //   whotChosenShape: chosenShape,
      // );

      // Play effect sound
      try {
        await _sound.playEffect('card_play.mp3');
      } catch (_) {}

      // Show popups for special cards so player sees immediate feedback
      _displaySpecialActionPopup(card);
    } catch (e) {
      // show friendly error
      _showTemporaryAction(e.toString());
    }
  }

  // player requests to draw one card
  Future<void> _onDrawPressed() async {
    if (!_isMyTurn) {
      _showTemporaryAction('Not your turn');
      return;
    }

    try {
      await _gameService.drawCards(gameId: widget.gameId, playerId: widget.myUid, count: 1);
      await _sound.playEffect('card_play.mp3');
    } catch (e) {
      _showTemporaryAction('Draw failed: $e');
    }
  }

  // Show temporary central action popup message for 1.6s
  void _showTemporaryAction(String message) {
    setState(() {
      _actionMessage = message;
      _showActionPopup = true;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          _showActionPopup = false;
          _actionMessage = '';
        });
      }
    });
  }

  // Show longer popup for special actions (Pick2, General Market, HoldOn, Suspension)
  void _displaySpecialActionPopup(CardModel playedCard) {
    final int num = playedCard.number;
    if (playedCard.shape == 'whot' || num == 20) {
      _showTemporaryAction('WHOT — shape chosen!');
      return;
    }
    if (num == 2) {
      _showTemporaryAction('Pick 2 — Opponent draws 2');
      return;
    }
    if (num == 14) {
      _showTemporaryAction('General Market!');
      return;
    }
    if (num == 8) {
      _showTemporaryAction('Suspension — Opponent skipped');
      return;
    }
    if (num == 1) {
      _showTemporaryAction('Hold On — Play again');
      return;
    }
  }

  // ----------------- Game finished handler -----------------

  Future<void> _onGameFinished(String winnerUid) async {
    _isWinnerDialogShown = true;
    // stop background and play win/lose effect
    try {
      await _sound.stopBackground();
      if (winnerUid == widget.myUid) {
        await _sound.playEffect('win.mp3');
      } else {
        await _sound.playEffect('loose.mp3');
      }
    } catch (_) {}

    // small celebration animation if player won
    if (winnerUid == widget.myUid) {
      _celebrateController.forward().then((_) => _celebrateController.reverse());
    }

    // show dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WinDialog(
        winnerName: winnerUid == widget.myUid ? 'You' : 'Opponent',
        onClose: () {
          Navigator.of(context).pop(); // close dialog
          Navigator.of(context).pop(); // go back to home or list
        },
      ),
    );
  }

  // ----------------- Small UI building helpers -----------------

  Widget _buildTopArea() {
    final opponent = _opponentUid ?? 'Opponent';
    final oppCount = _opponentHandCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.green[900],
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white24,
            child: Text(opponent.substring(0, 2).toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(opponent, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Cards: $oppCount', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_isMyTurn ? "Your Turn" : "Waiting", style: const TextStyle(color: Colors.white)),
              Text('Deck: $_deckCount', style: const TextStyle(color: Colors.white70)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPileArea() {
    final pile = _pileTop;
    final whotChosen = _whotChosen;
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text("Pile Top", style: TextStyle(fontSize: 16, color: Colors.white70)),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: pile != null
              ? Column(
                  key: ValueKey(pile.serialize()),
                  children: [
                    Image.asset("assets/images/${pile.shape}.png", width: 100, height: 120),
                    const SizedBox(height: 6),
                    Text("${pile.shape.toUpperCase()}  ${pile.number}", style: const TextStyle(color: Colors.white)),
                    if (pile.shape != 'whot' && whotChosen != null)
                      const SizedBox(height: 6),
                    if (pile.shape == 'whot' || pile.number == 20)
                      // show chosen shape badge
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          children: [
                            const Text("WHOT called:", style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            Image.asset("assets/images/$whotChosen.png", width: 36, height: 36),
                          ],
                        ),
                      ),
                  ],
                )
              : Container(
                  key: const ValueKey('empty_pile'),
                  width: 100,
                  height: 120,
                  color: Colors.white12,
                ),
        ),
      ],
    );
  }

  Widget _buildMyHand() {
    final hand = _myHand;
    if (hand.isEmpty) {
      return Center(child: Text('No cards', style: TextStyle(color: Colors.white70)));
    }

    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemBuilder: (context, index) {
          final card = hand[index];
          // CardWidget expects Map in earlier version, but here we will render directly by image.
          // We keep CardWidget that accepts `card` Map if implemented; otherwise render simple Image.
          return GestureDetector(
            onTap: () => _onCardTap(card),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Image.asset("assets/images/${card.shape}.png", width: 80, height: 110),
                ),
                const SizedBox(height: 6),
                Text('${card.number}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemCount: hand.length,
      ),
    );
  }

  // ----------------- Main build -----------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.green,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // main scaffold showing top/opponent, pile, my hand and action bar
    return Scaffold(
      backgroundColor: Colors.green[800],
      appBar: AppBar(
        backgroundColor: Colors.green[900],
        title: const Text('Naija Whot'),
        actions: [
          // small indicator for pending picks if any
          if (_pendingPick > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text('Pending Pick: $_pendingPick', style: const TextStyle(color: Colors.white))),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopArea(),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPileArea(),
                    const SizedBox(height: 18),
                    // deck back image and draw button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Image.asset('assets/images/back.png', width: 70, height: 90),
                            Text('$_deckCount', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(width: 32),
                        ElevatedButton.icon(
                          onPressed: _isMyTurn ? _onDrawPressed : null,
                          icon: const Icon(Icons.download),
                          label: const Text('Draw'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // player's hand
                    _buildMyHand(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),

          // show temporary action popup in the center when triggered
          if (_showActionPopup)
            Center(
              child: ActionPopup(message: _actionMessage),
            ),

          // celebrate when win (small scale animation in top-right)
          Positioned(
            right: 12,
            top: 12,
            child: ScaleTransition(
              scale: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _celebrateController, curve: Curves.elasticOut)),
              child: Icon(Icons.celebration, color: Colors.yellowAccent, size: 36),
            ),
          ),
        ],
      ),
    );
  }
}
