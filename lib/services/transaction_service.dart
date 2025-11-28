// -----------------------------------------------------------
// 2. SERVICE
// -----------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:naija_whot_trail/models/transaction_model.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';

class TransactionService {
final FirebaseFirestore _db = FirebaseFirestore.instance;


/// Creates a transaction in Firebase
Future<void> createTransaction({
required String userId,
required double amount,
required reference,
required type,
required status
}) async {
final id = _db.collection('transactions').doc().id;
//final reference = _genRef();
final now = DateTime.now();


final tx = TransactionModel(
id: id,
userId: userId,
amount: amount,
reference: reference,
createdAt: now,
type:type,
status:status

);


await _db.collection('transactions').doc(id).set(tx.toMap());
}


//AUTO GENERATE UNIQUE REFERENCE (e.g., TXN-2398JD02)
String _genRef() {
final uuid = const Uuid().v4().substring(0, 8).toUpperCase();
return "TXN-$uuid";
}



 Future<AuthResult> withdraw(String uid, double amount) async {
    try {
      final docRef = _db.collection('users').doc(uid);
      final snapshot = await docRef.get();
      final currentBalance = snapshot.data()?['balance'] ?? 0.0;

      if (amount <= 0) return AuthResult(success: false, message: "Invalid amount");
      if (amount > currentBalance) return AuthResult(success: false, message: "Insufficient balance");
      createTransaction(
        reference: _genRef,
        userId: uid,
        amount: amount,
        type: "withdrawal",
        status: "pending"

      );


      await docRef.update({'balance': currentBalance - amount});
      return AuthResult(success: true, uid: uid);
    } catch (e) {
      return AuthResult(success: false, message: e.toString(), uid: uid);
    }
  }


}