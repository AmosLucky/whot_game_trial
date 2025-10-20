import 'package:flutter/material.dart';

class ActionPopup extends StatelessWidget {
  final String message;

  const ActionPopup({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
