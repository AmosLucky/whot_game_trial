// lib/screens/matching_screen.dart

import 'package:flutter/material.dart';

class MatchingScreen extends StatelessWidget {
  final String opponentName;
  const MatchingScreen({super.key, required this.opponentName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Matching...")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Waiting for $opponentName to accept your invite..."),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
