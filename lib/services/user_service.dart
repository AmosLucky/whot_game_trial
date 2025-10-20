import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Register a new user
  Future<User?> registerUser({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      // Create Firebase Auth user
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = cred.user;

      // Save user details in Firestore
      await _firestore.collection('users').doc(user!.uid).set({
        'uid': user.uid,
        'fullName': fullName,
        'username': username,
        'email': email,
        'phone': phone,
        'balance': 0, // starting balance
        'avatar': 'https://i.imgur.com/BoN9kdC.png', // default avatar
        'createdAt': FieldValue.serverTimestamp(),
      });

      return user;
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }

  /// Login existing user
  Future<User?> loginUser(String email, String password) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  /// Get the currently authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Fetch a user's Firestore data by ID
  Future<Map<String, dynamic>> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return doc.data() ?? {};
    } else {
      throw Exception('User not found.');
    }
  }

  /// Get current user's full data (shortcut)
  Future<Map<String, dynamic>?> getUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await getUserData(user.uid);
  }

  /// Update user's coin balance
  Future<void> updateUserBalance(String uid, int newBalance) async {
    await _firestore.collection('users').doc(uid).update({
      'balance': newBalance,
    });
  }

  /// Deduct coins safely (won't go negative)
  Future<bool> deductCoins(String uid, int amount) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return false;

    final currentBalance = userDoc.data()!['balance'] ?? 0;
    if (currentBalance < amount) return false;

    await userDoc.reference.update({'balance': currentBalance - amount});
    return true;
  }

  /// Logout user
  Future<void> logoutUser() async {
    await _auth.signOut();
  }
}
