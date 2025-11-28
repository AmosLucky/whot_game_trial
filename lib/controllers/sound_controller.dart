import 'package:flutter_riverpod/legacy.dart';
import '../services/sound_service.dart';

class SoundState {
  final bool musicOn;
  final bool effectsOn;

  SoundState({required this.musicOn, required this.effectsOn});

  SoundState copyWith({bool? musicOn, bool? effectsOn}) {
    return SoundState(
      musicOn: musicOn ?? this.musicOn,
      effectsOn: effectsOn ?? this.effectsOn,
    );
  }
}

class SoundController extends StateNotifier<SoundState> {
  final SoundService soundService;

  SoundController({required this.soundService})
      : super(SoundState(musicOn: true, effectsOn: true)) {
    if (state.musicOn) soundService.playBackground();
  }

  void toggleMusic(bool value) {
    state = state.copyWith(musicOn: value);
    if (value) {
      soundService.playBackground();
    } else {
      soundService.stopBackground();
    }
  }

  void toggleEffects(bool value) {
    state = state.copyWith(effectsOn: value);
  }

  Future<void> playEffect(String fileName) async {
    if (state.effectsOn) {
      await soundService.playEffect(fileName);
    }
  }
}

// <--- THIS IS THE PROVIDER YOU CAN USE IN UI --->
final soundControllerProvider =
    StateNotifierProvider<SoundController, SoundState>((ref) {
  return SoundController(soundService: SoundService());
});
