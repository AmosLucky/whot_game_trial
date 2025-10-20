import 'package:flutter/material.dart';

class CardWidget extends StatelessWidget {
  final Map<String, dynamic> card;

  const CardWidget({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Card(
        color: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Image.asset(
            "assets/images/${card['image']}",
            width: 70,
          ),
        ),
      ),
    );
  }
}
