import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:naija_whot_trail/screens/home_screen.dart';
import 'package:pay_with_paystack/pay_with_paystack.dart';

import '../../providers/providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/image_background.dart';

class FundWalletPage extends ConsumerStatefulWidget {
  const FundWalletPage({super.key});

  @override
  ConsumerState<FundWalletPage> createState() => _FundWalletPageState();
}

class _FundWalletPageState extends ConsumerState<FundWalletPage> {
  final TextEditingController amountController = TextEditingController();
  //final PaystackPlugin _paystack = PaystackPlugin();
  bool isLoading = false;
  int vat = 0;

  @override
  void initState() {
    super.initState();
    // _paystack.initialize(publicKey: "pk_test_4da922bb1353fb60640cc9ece6f6bca489c74525");
  }

  Future<void> fundWallet() async {
    final email = ref.read(authControllerProvider).user!.email;
    final userId = ref.read(authControllerProvider).user!.uid;
    

    int amount = int.tryParse(amountController.text.trim()) ?? 0;
    var percent = (amount * 0.017).round();

    if (amount < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimum fund amount is ₦500")),
      );
      return;
    }

    //setState(() => isLoading = true);

    // Convert to Kobo
    
    int chargeAmount =  (amount +percent) * 100 ;

    final uniqueTransref = uniqueTransRef();

    PayWithPayStack().now(
      context: context,
      secretKey: "sk_test_9e9889fc89a77e9a534bf45443462a26ecdd563e",
      customerEmail: email,
      reference: uniqueTransref,
      currency: "NGN",
      amount: chargeAmount.toDouble(),
      callbackUrl: "https://google.com",
      transactionCompleted: (p) async {
          
        ref.read(authControllerProvider.notifier).updateBalance(amount.toDouble());
      
        await showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
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
                  ),
                ],
              ),
        );
      },
      transactionNotCompleted: (p) {
        //print("failure");
        //debugPrint("==> Transaction failed reason ");
        //showPaymentFailureDialog(context);
         Navigator.pushReplacementNamed(context, "/failedPayment");
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment failed or cancelled")),
        );
      },
    );
  }



  void showPaymentFailureDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // user cannot close by tapping outside
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: const [
            Icon(Icons.error, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text(
              "Payment Failed",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "Your payment was not completed. Please try again.",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
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
              "Cancel",
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
            },
            child: const Text("Retry"),
          ),
        ],
      );
    },
  );
}


  String uniqueTransRef() {
     const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random();
  final code = List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();

  return "TXN_${DateTime.now().millisecondsSinceEpoch}_$code";
  }
  String percent(){
     int amount = int.tryParse(amountController.text.trim()) ?? 0;
    var percent = (amount * 0.017).round();
    vat = percent;
    setState(() {
      
    });
    return percent.toString();
  }

  @override
  Widget build(BuildContext context) {
     final userState = ref.read(authControllerProvider);
     //.user!.email;
    //final userId = ref.read(authControllerProvider).user!.uid;
    return Scaffold(
      backgroundColor: const Color(0xff1b1b1d),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Fund Wallet"),
      ),
      body: ImageBackground(
        image: "assets/images/bg_1.jpg",
        child: SingleChildScrollView(
          child: Padding(
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
                      ),
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
                        onChanged: (v){
                          percent();
                        },
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
                     vat > 0? Text('VAT: N${ vat}'):
                     SizedBox.shrink(),
          
                      const SizedBox(height: 50),
          
                      // Pay Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : (){
                           // fundWallet();


                           int amount = int.tryParse(amountController.text.trim()) ?? 0;
                            var percent = (amount * 0.017).round();
                            int chargeAmount =  (amount ) + percent ;

                           final uniqueTransRef =
                                      PayWithPayStack().generateUuidV4();
                                    //  String amount = widget.booking.amount.toString();

                                  PayWithPayStack().now(
                                      context: context,
                                      secretKey:
                                          "sk_test_9e9889fc89a77e9a534bf45443462a26ecdd563e",
                                      customerEmail: userState. user!.email,
                                      reference: uniqueTransRef,
                                      currency: "NGN",
                                      amount: 
                                          ((chargeAmount.toDouble())),
                                      callbackUrl: "https://akaoru.com",
                                      transactionCompleted: (paymentinfo)  async{
                                        //showCancelPaymentDialog(context);
                                        
                                       
                                        ref.read(authControllerProvider.notifier).updateBalance(amount.toDouble());
                                        ref.read(authControllerProvider.notifier).refreshUser();
                                        ref.read(transactionControllerProvider.notifier).create(
                                          userId: userState.user!.uid,
                                           amount: amount.toDouble(),
                                           reference: paymentinfo.reference!,
                                           status: "success",
                                           type: "wallet_funding"
                                           );
                                        
                                          Navigator.pushReplacement(
                                 context,
                                MaterialPageRoute(
                                  builder: (context) => HomeScreen(
                                    
                                  ),
                                ),
                              );
                                       
                                      },
                                      transactionNotCompleted: (string) {
                                        showCancelPaymentDialog(context);
                                  
                                              var route = MaterialPageRoute(builder: (c)=>HomeScreen());
                                  Navigator.push(context, route);
                                        
                                      });

                           
    

                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child:
                              isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
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
        ),
      ),
    );
  }

   void showCancelPaymentDialog(BuildContext context ) {
  showDialog(
    context: context,
    barrierDismissible: false, // cannot dismiss by tapping outside
    barrierColor: Color(0xFF5B2020), // background not dimmed
    builder: (context) {
      return PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: Colors.white,
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Cancel Payment?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'You have canceled the payment !!!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // ElevatedButton(
                          //   onPressed: () {
                          //     Navigator.pop(context); // close dialog
                          //     Navigator.pushReplacement(
                          //       context,
                          //       MaterialPageRoute(
                          //         builder: (context) => ScheduleItemWidget(
                          //           index: index,
                          //           booking: booking,
                          //         ),
                          //       ),
                          //     );
                          //   },
                          //   style: ElevatedButton.styleFrom(
                          //     backgroundColor: Colors.green,
                          //     padding: const EdgeInsets.symmetric(
                          //         horizontal: 24, vertical: 12),
                          //     shape: RoundedRectangleBorder(
                          //       borderRadius: BorderRadius.circular(8),
                          //     ),
                          //   ),
                          //   child: const Text('Continue'),
                          // ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // close dialog
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const HomeScreen()),
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Back to Home', style: TextStyle(color: Colors.white),),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

}
