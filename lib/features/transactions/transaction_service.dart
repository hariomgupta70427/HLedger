import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import 'models/transaction_model.dart';

class TransactionService {
  final _supabase = Supabase.instance.client;

  Future<List<Transaction>> getTransactions() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from(AppConstants.transactionsTable)
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false);

    return response.map((json) => Transaction.fromJson(json)).toList();
  }

  Future<Transaction> addTransaction({
    required String person,
    required double amount,
    required String category,
    String? description,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final transaction = Transaction(
      id: '',
      userId: userId,
      person: person,
      amount: amount,
      category: category,
      timestamp: DateTime.now(),
      description: description,
    );

    final response = await _supabase
        .from(AppConstants.transactionsTable)
        .insert(transaction.toJson())
        .select()
        .single();

    return Transaction.fromJson(response);
  }

  Future<void> deleteTransaction(String id) async {
    await _supabase
        .from(AppConstants.transactionsTable)
        .delete()
        .eq('id', id);
  }

  Future<Map<String, double>> getBalance() async {
    final transactions = await getTransactions();
    
    double totalCredit = 0;
    double totalDebit = 0;
    
    for (final transaction in transactions) {
      if (transaction.isCredit) {
        totalCredit += transaction.amount;
      } else {
        totalDebit += transaction.amount;
      }
    }
    
    return {
      'credit': totalCredit,
      'debit': totalDebit,
      'balance': totalCredit - totalDebit,
    };
  }
}