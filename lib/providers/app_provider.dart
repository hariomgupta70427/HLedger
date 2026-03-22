import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/task.dart';
import '../services/supabase_service.dart';

class AppProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];
  List<Task> _tasks = [];
  bool _isLoadingTransactions = false;
  bool _isLoadingTasks = false;
  DateTime? _lastLoadTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  List<Transaction> get transactions => _transactions;
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoadingTransactions || _isLoadingTasks;
  bool get isLoadingTransactions => _isLoadingTransactions;
  bool get isLoadingTasks => _isLoadingTasks;
  bool get isAuthenticated => SupabaseService.isAuthenticated;

  double get totalIncome =>
      _transactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
  double get totalExpense =>
      _transactions.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
  double get balance => totalIncome - totalExpense;

  // Backward compat
  double get totalCredit => totalIncome;
  double get totalDebit => totalExpense;

  bool get _isCacheValid {
    if (_lastLoadTime == null) return false;
    return DateTime.now().difference(_lastLoadTime!) < _cacheValidDuration;
  }

  Future<void> loadData({bool forceRefresh = false}) async {
    if (!isAuthenticated) return;

    if (!forceRefresh && _isCacheValid && _transactions.isNotEmpty) return;

    _isLoadingTransactions = true;
    _isLoadingTasks = true;
    notifyListeners();

    try {
      _transactions = await SupabaseService.getTransactions();
      _isLoadingTransactions = false;
      notifyListeners();

      _tasks = await SupabaseService.getTasks();
      _lastLoadTime = DateTime.now();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoadingTransactions = false;
    _isLoadingTasks = false;
    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
    try {
      final newTransaction = await SupabaseService.addTransaction(transaction);
      _transactions.insert(0, newTransaction);
      _lastLoadTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding transaction: $e');
      rethrow;
    }
  }

  /// Adds a task and returns the saved task (with server-generated id).
  Future<Task> addTask(Task task) async {
    try {
      final newTask = await SupabaseService.addTask(task);
      _tasks.insert(0, newTask);
      _lastLoadTime = DateTime.now();
      notifyListeners();
      return newTask;
    } catch (e) {
      debugPrint('Error adding task: $e');
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      final updatedTask = await SupabaseService.updateTask(task);
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
        _lastLoadTime = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
      rethrow;
    }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    try {
      final updatedTransaction = await SupabaseService.updateTransaction(transaction);
      final index = _transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _transactions[index] = updatedTransaction;
        _lastLoadTime = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await SupabaseService.deleteTransaction(id);
      _transactions.removeWhere((t) => t.id == id);
      _lastLoadTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await SupabaseService.deleteTask(id);
      _tasks.removeWhere((t) => t.id == id);
      _lastLoadTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting task: $e');
      rethrow;
    }
  }

  void signOut() {
    _transactions.clear();
    _tasks.clear();
    _lastLoadTime = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadData(forceRefresh: true);
  }
}