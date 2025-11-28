import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naija_whot_trail/providers/transaction_providers.dart';

import '../../providers/providers.dart';
import '../settings/change_password_page.dart';

class WithdrawPage extends ConsumerStatefulWidget {
  const WithdrawPage({super.key});

  @override
  ConsumerState<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends ConsumerState<WithdrawPage> {
  final _formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final accountController = TextEditingController();
  final bankController = TextEditingController();

  @override
  void dispose() {
    amountController.dispose();
    accountController.dispose();
    bankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authControllerProvider);
    final user = userState.user!;

    return Scaffold(
      appBar: AppBar(title: const Text("Withdraw"), backgroundColor: Colors.brown.shade800),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Available Balance", style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text("₦${user.balance}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CustomField(
                controller: amountController,
                label: "Amount",
                validator: (val) {
                  if (val == null || val.isEmpty) return "Enter amount";
                  if (double.tryParse(val) == null) return "Enter valid number";
                  return null;
                },
              ),
              CustomField(
                controller: accountController,
                label: "Account Number",
                validator: (val) => val == null || val.isEmpty ? "Enter account number" : null,
              ),
              CustomField(
                controller: bankController,
                label: "Bank Name",
                validator: (val) => val == null || val.isEmpty ? "Enter bank name" : null,
              ),
              const SizedBox(height: 20),
              userState.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          await ref.read(transactionControllerProvider.notifier).withdrawAmount(
                                amount: double.parse(amountController.text.trim()),
                                accountNumber: accountController.text.trim(),
                                bankName: bankController.text.trim(),
                              );

                          if (mounted && userState.error == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Withdrawal successful")),
                            );
                            Navigator.pop(context);
                          } else if (userState.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(userState.error!)),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.brown.shade800,
                      ),
                      child: const Text("Withdraw"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
