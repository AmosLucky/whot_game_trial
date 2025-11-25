import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naija_whot_trail/screens/fund_wallet_screen.dart';
import 'package:naija_whot_trail/widgets/image_background.dart';

import '../constants/app_constant.dart';
import '../providers/providers.dart';
import '../services/sound_service.dart';
import '../widgets/match_alert.dart';
import 'lobby_screen.dart';

class HomeScreen extends ConsumerWidget {
  HomeScreen({super.key});
  

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
     
    // print("pppppppppppppppppppppppp++++");
    // print(authState.user);
    return Scaffold(
      // backgroundColor: const Color(0xFF5B2020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B2020),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          "Naija Whot",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          // Settings Button
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white, size: 28),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),

          // Profile Avatar
          GestureDetector(
            onTap: () {
              // TODO: Navigate to profile screen
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(Icons.person),
                backgroundImage:
                    authState.user!.photoUrl.length > 3
                        ? NetworkImage(authState.user!.photoUrl)
                        : AssetImage("assets/images/logo.png"),
              ),
            ),
          ),
        ],
      ),

      body: ImageBackground(
        image: "assets/images/bg_1.jpg",
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,

              children: [
                // Username & Balance Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        authState.user!.username,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "Balance: ",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: "${authState.user!.balance} coins",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40),

                // Big PLAY Button
                GestureDetector(
                  onTap: ()async {
                     final minPayment = await showBetDialog(context);
                     print(minPayment);
                    if (authState.user!.balance >= minPayment!) {
                      //TODO: Go to matchmaking screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => LobbyScreen(
                                amount: minPayment,
                                
                              ),
                        ),
                      );
                    }else{

                      showInsufficientBalanceDialog(context);

                    }
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    padding: EdgeInsets.symmetric(vertical: 22),
                    decoration: BoxDecoration(
                      color: Color(0xFF5B2020),
                      border: Border.all(color: Colors.white, width: 5),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "PLAY GAME",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Fund Wallet Button
                GestureDetector(
                  onTap: () {
                    // TODO: Navigate to wallet page
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => FundWalletPage(
                                
                              ),
                        ),
                      );
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.5,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Color(0xFF5B2020),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(width: 5, color: Colors.white),
                    ),
                    child: Center(
                      child: Text(
                        "Fund Wallet",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Fund Wallet Button
                Visibility(
                  visible: false,
                  child: GestureDetector(
                    onTap: () {
                      // TODO: Navigate to wallet page
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Color(0xFF5B2020),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(width: 5, color: Colors.white),
                      ),
                      child: Center(
                        child: Text(
                          "Leaderboard",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Future<void> showInsufficientBalanceDialog(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xff1e1e1e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: const [
          Icon(Icons.warning_rounded, color: Colors.redAccent, size: 30),
          SizedBox(width: 10),
          Text(
            "Insufficient Balance",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: const Text(
        "You need a minimum of ₦500 to play this game.\n\nPlease fund your wallet to continue.",
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      actions: [
        // ➤ FUND WALLET BUTTON
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, "/fundwallet"); 
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "Fund Wallet",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // ➤ CLOSE BUTTON
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Close",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

}
