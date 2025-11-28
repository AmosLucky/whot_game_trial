import 'package:flutter/material.dart';

class FailedPayment extends StatefulWidget {
  const FailedPayment({super.key});

  @override
  State<FailedPayment> createState() => _FailedPaymentState();
}

class _FailedPaymentState extends State<FailedPayment> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
    canPop: false,
      child: Scaffold(
        appBar: AppBar(),
        body:Column(children: [
            Row(
            children: const [
              Icon(Icons.error, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Text(
                "Payment Failed",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
           const Text(
            "Your payment was not completed. Please try again.",
            style: TextStyle(fontSize: 15),
          ),
      
      
          TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  "/home",
                  (route) => false,
                );
              },
              child: const Text(
                "Back To Dashboard",
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],) ,
      ),
    );
  }
}