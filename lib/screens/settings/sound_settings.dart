import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/sound_controller.dart';

class SoundSettingsPage extends ConsumerWidget {
  const SoundSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundState = ref.watch(soundControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sound Settings"),
        backgroundColor: Colors.brown.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                title: const Text("Background Music"),
                value: soundState.musicOn,
                onChanged: (val) => ref.read(soundControllerProvider.notifier).toggleMusic(val),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                title: const Text("Sound Effects"),
                value: soundState.effectsOn,
                onChanged: (val) => ref.read(soundControllerProvider.notifier).toggleEffects(val),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade800,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                // Example effect sound
                await ref.read(soundControllerProvider.notifier).playEffect("clap.mp3");
              },
              child: const Text("Play Effect Sound"),
            ),
          ],
        ),
      ),
    );
  }
}
