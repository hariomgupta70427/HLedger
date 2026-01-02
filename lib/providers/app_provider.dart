import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/task.dart';
import '../services/supabase_service.dart';

class AppProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];
  List<Task> _tasks = [];
  bool _isLoading = false;
  DateTime? _lastLoadTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  List<Transaction> get transactions => _transactions;
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => SupabaseService.isAuthenticated;

  double get totalCredit => _transactions.where((t) => t.isCredit).fold(0, (sum, t) => sum + t.amount);
  double get totalDebit => _transactions.where((t) => t.isDebit).fold(0, (sum, t) => sum + t.amount);
  double get balance => totalCredit - totalDebit;

  // Check if cache is still valid
  bool get _isCacheValid {
    if (_lastLoadTime == null) return false;
    return DateTime.now().difference(_lastLoadTime!) < _cacheValidDuration;
  }

  Future<void> loadData({bool forceRefresh = false}) async {
    if (!isAuthenticated) {
      print('⚠️  AppProvider: User not authenticated, skipping load');
      return;
    }
    
    // Use cached data if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid && _transactions.isNotEmpty) {
      print('✅ AppProvider: Using cached data');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      print('🔄 AppProvider: Loading data from Supabase...');
      _transactions = await SupabaseService.getTransactions();
      _tasks = await SupabaseService.getTasks();
      _lastLoadTime = DateTime.now();
      print('✅ AppProvider: Loaded ${_transactions.length} transactions and ${_tasks.length} tasks');
    } catch (e) {
      debugPrint('❌ AppProvider: Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
    try {
      print('💰 AppProvider: Adding transaction...');
      final newTransaction = await SupabaseService.addTransaction(transaction);
      _transactions.insert(0, newTransaction);
      _lastLoadTime = DateTime.now(); // Update cache time
      print('✅ AppProvider: Transaction added');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ AppProvider: Error adding transaction: $e');
      rethrow;
    }
  }

  Future<void> addTask(Task task) async {
    try {
      print('✅ AppProvider: Adding task...');
      final newTask = await SupabaseService.addTask(task);
      _tasks.insert(0, newTask);
      _lastLoadTime = DateTime.now(); // Update cache time
      print('✅ AppProvider: Task added');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ AppProvider: Error adding task: $e');
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      print('🔄 AppProvider: Updating task...');
      final updatedTask = await SupabaseService.updateTask(task);
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
        _lastLoadTime = DateTime.now(); // Update cache time
        print('✅ AppProvider: Task updated');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ AppProvider: Error updating task: $e');
      rethrow;
    }
  }

  void signOut() {
    _transactions.clear();
    _tasks.clear();
    _lastLoadTime = null;
    notifyListeners();
  }

  // Force refresh - for pull-to-refresh
  Future<void> refresh() async {
    print('🔄 AppProvider: Force refreshing data...');
    await loadData(forceRefresh: true);
  }
}