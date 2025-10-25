// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';

FirebaseOptions firebaseOption = FirebaseOptions(
   
  apiKey: "AIzaSyAdPY_HOZ-FK2PCEy-8W8PJexleR_03iFQ",
  authDomain: "general-30e01.firebaseapp.com",
  databaseURL: "https://general-30e01-default-rtdb.firebaseio.com",
  projectId: "general-30e01",
  storageBucket: "general-30e01.appspot.com",
  messagingSenderId: "993480772447",
  appId: "1:993480772447:web:98f3e8f9a87228a08c04ea",
  measurementId: "G-40Y26NVDTR"


);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if(kIsWeb){
     await Firebase.initializeApp(options: firebaseOption); // requires google-services.json / plist set up

  }else{
     await Firebase.initializeApp(
      //options: DefaultFirebaseOptions.currentPlatform,
     );

  }
 
  runApp(const NaijaWhotApp());
}
