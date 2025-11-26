// -----------------------------------------------------------
// 2. SERVICE
// -----------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:naija_whot_trail/models/transaction_model.dart';

class TransactionService {
final FirebaseFirestore _db = FirebaseFirestore.instance;


/// Creates a transaction in Firebase
Future<void> createTransaction({
required String userId,
required int amount,
required reference
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
);


await _db.collection('transactions').doc(id).set(tx.toMap());
}


/// AUTO GENERATE UNIQUE REFERENCE (e.g., TXN-2398JD02)
// String _genRef() {
// final uuid = const Uuid().v4().substring(0, 8).toUpperCase();
// return "TXN-$uuid";
// }
}