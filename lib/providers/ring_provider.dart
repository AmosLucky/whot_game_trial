import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// 1. StateNotifier to manage the bool
class HasRingerNotifier extends StateNotifier<bool> {
  HasRingerNotifier() : super(false); // initial value

  // Toggle the value
  void toggle() => state = !state;

  // Optional: set a specific value
  void set(bool value) => state = value;
}

// 2. Create a provider for the notifier
final hasRingerProvider =
    StateNotifierProvider<HasRingerNotifier, bool>((ref) {
  return HasRingerNotifier();
});
