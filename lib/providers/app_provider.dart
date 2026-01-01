import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/task.dart';
import '../services/supabase_service.dart';

class AppProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];
  List<Task> _tasks = [];
  bool _isLoading = false;

  List<Transaction> get transactions => _transactions;
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => SupabaseService.isAuthenticated;

  double get totalCredit => _transactions.where((t) => t.isCredit).fold(0, (sum, t) => sum + t.amount);
  double get totalDebit => _transactions.where((t) => t.isDebit).fold(0, (sum, t) => sum + t.amount);
  double get balance => totalCredit - totalDebit;

  Future<void> loadData() async {
    if (!isAuthenticated) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await SupabaseService.getTransactions();
      _tasks = await SupabaseService.getTasks();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
    try {
      final newTransaction = await SupabaseService.addTransaction(transaction);
      _transactions.insert(0, newTransaction);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding transaction: $e');
    }
  }

  Future<void> addTask(Task task) async {
    try {
      final newTask = await SupabaseService.addTask(task);
      _tasks.insert(0, newTask);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      final updatedTask = await SupabaseService.updateTask(task);
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  void signOut() {
    _transactions.clear();
    _tasks.clear();
    notifyListeners();
  }
}