import 'package:flutter/material.dart';

class WinDialog extends StatelessWidget {
  final String winnerName;
  final VoidCallback onClose;

  const WinDialog({super.key, required this.winnerName, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("🎉 Game Over!"),
      content: Text(
        "$winnerName won the game!",
        style: const TextStyle(fontSize: 18),
      ),
      actions: [
        TextButton(
          onPressed: onClose,
          child: const Text("OK"),
        ),
      ],
    );
  }
}
