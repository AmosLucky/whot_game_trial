import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _userKey = 'user_data';

  // Save user snapshot data
  Future<void> saveUserData(Map<String, dynamic> data) async {
    
   final cleanedData = <String, dynamic>{};

    data.forEach((key, value) {
      if (value == null) return; // skip nulls

      // Skip Firestore FieldValue and similar
      if (value is FieldValue) return;

      // Convert Firestore Timestamp to DateTime or String
      if (value is Timestamp) {
        cleanedData[key] = value.toDate().toIso8601String();
        return;
      }

      // For all normal values
      cleanedData[key] = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(cleanedData));
    
  }

  // Load user snapshot data
  Future<Map<String, dynamic>?> getUserData() async {
   
    
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userKey);
    if (jsonString == null) return null;
    
    return jsonDecode(jsonString);
  }

  // Clear user data (for logout)
  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // Check if user data exists
  Future<bool> hasUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_userKey);
  }
}
