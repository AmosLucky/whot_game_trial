import 'dart:ui';

import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

class TurnCountdownState {
  final int secondsLeft;
  final bool isRunning;

  TurnCountdownState({
    required this.secondsLeft,
    required this.isRunning,
  });

  TurnCountdownState copyWith({
    int? secondsLeft,
    bool? isRunning,
  }) {
    return TurnCountdownState(
      secondsLeft: secondsLeft ?? this.secondsLeft,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

class TurnCountdownNotifier extends StateNotifier<TurnCountdownState> {
  TurnCountdownNotifier()
      : super(TurnCountdownState(secondsLeft: 10, isRunning: false));

  Timer? _timer;

  /// Start countdown
  void start() {
    _timer?.cancel();
    //2 minuites
    state = TurnCountdownState(secondsLeft: 120, isRunning: true);

    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      final current = state.secondsLeft;

      if (current <= 1) {
        t.cancel();
        state = state.copyWith(secondsLeft: 0, isRunning: false);
        onExpired?.call();
      } else {
        state = state.copyWith(secondsLeft: current - 1);
      }
    });
  }

  /// Stop countdown
  void stop() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  /// Optional callback set by UI or game controller
  VoidCallback? onExpired;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final turnCountdownProvider =
    StateNotifierProvider<TurnCountdownNotifier, TurnCountdownState>(
        (ref) => TurnCountdownNotifier());
