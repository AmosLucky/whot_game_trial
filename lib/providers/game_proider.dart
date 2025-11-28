import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final gameDocProvider = StreamProvider.family.autoDispose(
  (ref, String gameId) {
    return FirebaseFirestore.instance
        .collection("games")
        .doc(gameId)
        .snapshots();
  },
);
final turnProvider = Provider.autoDispose.family<String, String>((ref, gameId) {
  final doc = ref.watch(gameDocProvider(gameId)).asData?.value;
  if (doc == null) return "";
  return (doc['turn'] ?? '').toString();
});
