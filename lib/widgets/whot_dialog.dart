import 'package:flutter/material.dart';

class WhotDialog extends StatelessWidget {
  final Function(String) onSelect;

  const WhotDialog({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final shapes = ["circle", "triangle", "star", "cross", "square"];

    return AlertDialog(
      title: const Text("Call Shape"),
      content: Wrap(
        spacing: 10,
        children: shapes.map((shape) {
          return GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onSelect(shape);
            },
            child: Image.asset(
              "assets/images/$shape.png",
              width: 50,
            ),
          );
        }).toList(),
      ),
    );
  }
}
