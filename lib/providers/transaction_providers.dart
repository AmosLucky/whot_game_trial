import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../controllers/transaction_controller.dart';
import '../services/transaction_service.dart';
import '../states/transaction_state.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) {
return TransactionService();
});

// Provider
final transactionControllerProvider = StateNotifierProvider<TransactionController, TransactionState>((ref) {
return TransactionController(ref);
});