import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_paystack/flutter_paystack.dart';

import '../providers/providers.dart';

class FundWalletPage extends ConsumerStatefulWidget {
  const FundWalletPage({super.key});

  @override
  ConsumerState<FundWalletPage> createState() => _FundWalletPageState();
}

class _FundWalletPageState extends ConsumerState<FundWalletPage> {
  final TextEditingController amountController = TextEditingController();
  final PaystackPlugin _paystack = PaystackPlugin();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _paystack.initialize(publicKey: "pk_test_4da922bb1353fb60640cc9ece6f6bca489c74525");
  }

  Future<void> fundWallet() async {
    final email = ref.read(authControllerProvider).user!.email;
    final userId = ref.read(authControllerProvider).user!.uid;

    int amount = int.tryParse(amountController.text.trim()) ?? 0;

    if (amount < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimum fund amount is ₦500")),
      );
      return;
    }

    setState(() => isLoading = true);

    // Convert to Kobo
    int chargeAmount = amount * 100;

    Charge charge = Charge()
      ..amount = chargeAmount
      ..email = email
      ..reference = "FUND_${DateTime.now().millisecondsSinceEpoch}";

    CheckoutResponse response = await _paystack.checkout(
      context,
      method: CheckoutMethod.card,
      charge: charge,
    );

    if (response.status == true) {
      // Update user balance
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId.toString())
          .update({
        "balance": FieldValue.increment(amount),
      });

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Wallet Funded Successfully 🎉",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text("₦$amount has been added to your wallet."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, "/home");
              },
              child: const Text("OK"),
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment failed or cancelled")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1b1b1d),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Fund Wallet"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // CARD UI
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 3,
                  )
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    "Enter Amount to Fund",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "₦500 minimum",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Pay Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : fundWallet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Add Funds",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              "All payments are securely processed by Paystack.",
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
