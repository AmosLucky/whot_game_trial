// -----------------------------
// File: lib/services/audio_manager.dart
// -----------------------------
import 'package:audioplayers/audioplayers.dart';


class AudioManager {
static final AudioPlayer _bgPlayer = AudioPlayer();
static final AudioPlayer _effectPlayer = AudioPlayer();


/// Start looping background music (non-blocking)
static Future<void> playBg() async {
try {
await _bgPlayer.setReleaseMode(ReleaseMode.loop);
await _bgPlayer.play(AssetSource('music/bg.mp3'));
} catch (e) {
// ignore errors in dev; log if you want
}
}


static Future<void> stopBg() async {
try {
await _bgPlayer.stop();
} catch (e) {}
}


static Future<void> playEffect(String fileName) async {
try {
await _effectPlayer.play(AssetSource('music/$fileName'));
} catch (e) {}
}


static Future<void> setBgVolume(double volume) async {
try {
await _bgPlayer.setVolume(volume);
} catch (e) {}
}
}