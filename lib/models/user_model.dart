// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String username;
  final String email;
  final String phone;
  final String photoUrl;
  final double balance;
  final bool isOnline;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.balance,
    required this.isOnline,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: data['uid'],
      displayName: data['displayName'] ?? '',
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      balance: (data['balance'] ?? 0).toDouble(),
      isOnline: data['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'balance': balance,
      'isOnline': isOnline,
    };
  }

  /// 🔥 Added copyWith method
  AppUser copyWith({
    String? uid,
    String? displayName,
    String? username,
    String? email,
    String? phone,
    String? photoUrl,
    double? balance,
    bool? isOnline,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      balance: balance ?? this.balance,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
