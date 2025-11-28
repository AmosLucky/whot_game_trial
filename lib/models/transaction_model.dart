// 2. TransactionService (createTransaction)
// 3. Riverpod Provider
// 4. Helper for generating unique references
// 5. Example usage


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';


// -----------------------------------------------------------
// 1. MODEL
// -----------------------------------------------------------
class TransactionModel {
final String id;
final String userId;
final double amount;
final String reference;
final DateTime createdAt;
final String status;
String type;


TransactionModel({
required this.id,
required this.userId,
required this.amount,
required this.reference,
required this.createdAt,
required this.status,
required this.type,
});


Map<String, dynamic> toMap() {
return {
'id': id,
'userId': userId,
'amount': amount,
'reference': reference,
'type': type,
'status': status,
'createdAt': createdAt.toIso8601String(),
};
}


static TransactionModel fromMap(Map<String, dynamic> map) {
return TransactionModel(
id: map['id'],
userId: map['userId'],
amount: map['amount'],
type: map['type'],
status: map['status'],
reference: map['reference'],
createdAt: DateTime.parse(map['createdAt']),
);
}
}