// lib/utils/rule_engine.dart
import '../models/card_model.dart';

/// Special effects we support.
enum SpecialEffect { none, pick2, generalMarket, suspension, holdOn, whot }

/// Result of determining the next action after a played card.
class NextAction {
  final String nextPlayerId; // uid of the player who should play next
  final SpecialEffect effect;
  final int pickCount; // how many cards must be drawn if effect is pick2/generalMarket

  NextAction({
    required this.nextPlayerId,
    this.effect = SpecialEffect.none,
    this.pickCount = 0,
  });
}

/// RuleEngine validates plays and maps special numbers to effects.
/// Keep this file as the single place for game rule changes.
class RuleEngine {
  RuleEngine({
    // configuration defaults (tweak as needed)
    this.pick2Number = 2,
    this.generalMarketNumber = 14,
    this.suspensionNumber = 8,
    this.holdOnNumber = 1,
    this.whotNumber = 20,
    this.generalMarketPickCount = 1,
  });

  final int pick2Number; // number representing Pick 2 if used
  final int generalMarketNumber; // 14 -> general market
  final int suspensionNumber; // 8 -> suspension
  final int holdOnNumber; // 1 -> hold on
  final int whotNumber; // 20 -> whot
  final int generalMarketPickCount; // how many cards general market forces by default

  /// Validate if playing [played] on top of [pileTop] is legal.
  /// Rules:
  /// - allowed if shapes match OR numbers match OR played is WHOT
  bool validatePlay(CardModel pileTop, CardModel played) {
    // whot can always be played
    if (played.shape == 'whot' || played.number == whotNumber) return true;

    if (played.shape == pileTop.shape) return true;
    if (played.number == pileTop.number) return true;

    return false;
  }

  /// Determine the next player and any special effects after [played].
  /// [playersOrder] should be a list of player uids in playing order (e.g., [p1, p2]).
  /// [currentPlayerId] is the uid of who just played.
  NextAction determineNext({
    required List<String> playersOrder,
    required String currentPlayerId,
    required CardModel played,
  }) {
    // Find index of current player and compute next.
    final idx = playersOrder.indexOf(currentPlayerId);
    if (idx == -1) {
      // fallback: choose first player
      return NextAction(nextPlayerId: playersOrder.first);
    }

    // next index in circular order
    int nextIdx = (idx + 1) % playersOrder.length;
    String nextPlayer = playersOrder[nextIdx];

    // Map special numbers to effects
    if (played.number == pick2Number) {
      // pick 2 applied to next player
      return NextAction(nextPlayerId: nextPlayer, effect: SpecialEffect.pick2, pickCount: 2);
    } else if (played.number == generalMarketNumber) {
      // apply general market (default pick count)
      return NextAction(nextPlayerId: nextPlayer, effect: SpecialEffect.generalMarket, pickCount: generalMarketPickCount);
    } else if (played.number == suspensionNumber) {
      // skip next player - for 2 players that means return to current player
      // Implementation: skip next => advance one more
      int skipIdx = (nextIdx + 1) % playersOrder.length;
      return NextAction(nextPlayerId: playersOrder[skipIdx], effect: SpecialEffect.suspension);
    } else if (played.number == holdOnNumber) {
      // same player plays again
      return NextAction(nextPlayerId: currentPlayerId, effect: SpecialEffect.holdOn);
    } else if (played.number == whotNumber || played.shape == 'whot') {
      // whot: next player is next but we will also store chosen shape
      return NextAction(nextPlayerId: nextPlayer, effect: SpecialEffect.whot);
    }

    // default: normal play
    return NextAction(nextPlayerId: nextPlayer, effect: SpecialEffect.none);
  }
}
