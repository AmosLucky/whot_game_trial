// Transaction Status Enum
import 'package:naija_whot_trail/models/transaction_model.dart';

enum TransactionStatus { pending, success, declined }


// Transaction State
class TransactionState {
final bool loading;
final List<TransactionModel> transactions;
final String? error;


TransactionState({
this.loading = false,
this.transactions = const [],
this.error,
});


TransactionState copyWith({
bool? loading,
List<TransactionModel>? transactions,
String? error,
}) {
return TransactionState(
loading: loading ?? this.loading,
transactions: transactions ?? this.transactions,
error: error,
);
}
}