import 'package:audioplayers/audioplayers.dart';

class SoundService {
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();

  Future<void> playBackground() async {
    await _bgPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgPlayer.play(AssetSource("music/bg3.mp3"));
  }

  Future<void> stopBackground() async {
    await _bgPlayer.stop();
  }

  Future<void> playEffect(String fileName) async {
    await _effectPlayer.play(AssetSource("music/$fileName"));
  }
}
