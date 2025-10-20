// lib/services/auth_service.dart
//
// AuthService handles registration, login, sign-out, and optional MySQL sync.
// Now includes:
// ✅ Persistent login using FirebaseAuth.authStateChanges()
// ✅ Getter for current user's display name or email
// ✅ Keeps isOnline status updated when logged in/out

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class AuthResult {
  final bool success;
  final String? message;
  final String? uid;
  AuthResult({required this.success, this.message, this.uid});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String mysqlSyncEndpoint;
  AuthService({required this.mysqlSyncEndpoint});

  /// ✅ Stream to listen for login/logout changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// ✅ Get currently logged in user
  User? get currentUser => _auth.currentUser;

  /// ✅ Get current user's name or email (for display)
  String get currentUserDisplayName {
    final user = _auth.currentUser;
    if (user == null) return "Guest";
    return user.displayName ?? user.email ?? "Player";
  }

  /// ✅ Register a new user
  Future<AuthResult> registerWithEmail({
    required String fullname,
    required String username,
    required String email,
    required String phone,
    required String password,
    String? avatarUrl,
  }) async {
    try {
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        return AuthResult(success: false, message: 'Failed to create Firebase user');
      }

      final uid = user.uid;
      await user.updateDisplayName(fullname.trim());

      final userDoc = {
        'uid': uid,
        'displayName': fullname.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'photoUrl': avatarUrl ?? 'https://example.com/default-avatar.png',
        'balance': 0,
        'isOnline': true,
        'currentGameId': null,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(uid).set(userDoc);

      return AuthResult(success: true, uid: uid);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: e.message ?? 'Firebase error');
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  /// ✅ Login existing user
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user?.uid;

      if (uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }

      return AuthResult(success: true, uid: uid);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: e.message ?? 'Login failed');
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  /// ✅ Logout user and mark offline
  Future<void> logout() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
    await _auth.signOut();
  }

  /// ✅ For testing — don't log out on refresh
  /// Just call this before showing HomeScreen
  Future<User?> ensureLoggedIn() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
    return user;
  }

  /// Optional: sync to MySQL (you can enable later)
  Future<bool> _syncUserToMySQL({
    required String idToken,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(mysqlSyncEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
