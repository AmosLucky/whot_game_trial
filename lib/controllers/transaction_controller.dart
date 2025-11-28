// Transaction Controller
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:naija_whot_trail/providers/providers.dart';

import '../models/transaction_model.dart';
import '../providers/transaction_providers.dart';
import '../states/transaction_state.dart';

class TransactionController extends StateNotifier<TransactionState> {
final Ref ref;
TransactionController(this.ref) : super(TransactionState());


// CREATE
Future<void> create({ required String userId, 
required double amount, required String reference ,required String  status,required String type}) async {
try {
state = state.copyWith(loading: true);
await ref.read(transactionServiceProvider).createTransaction(
userId: userId,
amount: amount,
status: status,
type: type,
reference: reference

);
await fetch(userId: userId);
} catch (e) {
state = state.copyWith(error: e.toString());
} finally {
state = state.copyWith(loading: false);
}
}


// FETCH
Future<void> fetch({ required String userId }) async {
try {
state = state.copyWith(loading: true);
final snap = await FirebaseFirestore.instance
.collection('transactions')
.where('userId', isEqualTo: userId)
.orderBy('createdAt', descending: true)
.get();


final list = snap.docs.map((e) => TransactionModel.fromMap(e.data())).toList();


state = state.copyWith(transactions: list);
} catch (e) {
state = state.copyWith(error: e.toString());
} finally {
state = state.copyWith(loading: false);
}
}


// UPDATE STATUS
Future<void> updateStatus({ required String id, required TransactionStatus status }) async {
try {
await FirebaseFirestore.instance
.collection('transactions')
.doc(id)
.update({ 'status': status.name });
} catch (e) {
state = state.copyWith(error: e.toString());
}
}


  Future<void> withdrawAmount({
    required double amount,
    required String accountNumber,
    required String bankName,
  }) async {
    state = state.copyWith(loading: true, error: null);

    final uid = ref.read(authControllerProvider).user!.uid;
    final response = await ref.read(transactionServiceProvider).withdraw(uid, amount);


    if (response.success) {
      await ref.read(authControllerProvider.notifier).refreshUser(); // update balance in state
      state = state.copyWith(loading: false);
    } else {
      state = state.copyWith(loading: false, error: response.message);
    }
  }


}