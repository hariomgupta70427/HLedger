import 'dart:async';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/task.dart';
import '../services/home_widget_service.dart';
import '../services/notification_service.dart';
import '../services/pending_transaction_store.dart';
import '../services/sms_transaction_service.dart';
import '../services/transaction_classifier.dart';
import '../services/upi_parser.dart';
import '../services/supabase_service.dart';

class AppProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];
  List<Task> _tasks = [];
  List<Transaction> _pendingReview = [];
  StreamSubscription<UpiParseResult>? _detectionSub;
  bool _isLoadingTransactions = false;
  bool _isLoadingTasks = false;
  DateTime? _lastLoadTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  List<Transaction> get transactions => _transactions;
  List<Task> get tasks => _tasks;

  /// Auto-detected transactions awaiting user review (on-device only).
  List<Transaction> get pendingReview => List.unmodifiable(_pendingReview);
  int get pendingReviewCount => _pendingReview.length;

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

      // Re-schedule all future reminders on every app launch
      // This ensures reminders survive device restarts and OEM battery kills
      _rescheduleReminders();

      // Push latest data to home screen widgets
      _updateWidgets();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoadingTransactions = false;
    _isLoadingTasks = false;
    notifyListeners();
  }

  /// Re-schedule notifications for all tasks that have a future reminder.
  /// Called on every app launch to ensure no reminders are lost.
  void _rescheduleReminders() {
    final now = DateTime.now();
    int count = 0;
    for (final task in _tasks) {
      if (task.reminder && task.reminderTime != null && task.reminderTime!.isAfter(now)) {
        NotificationService().scheduleTaskReminder(
          id: task.id.hashCode,
          title: '📝 Task Reminder',
          body: task.title,
          scheduledDate: task.reminderTime!,
        );
        count++;
      }
    }
    if (count > 0) {
      debugPrint('🔄 Re-scheduled $count reminder(s) on app launch');
    }
  }

  /// Push latest data to all home screen widgets.
  void _updateWidgets() {
    HomeWidgetService.updateAllWidgets(
      transactions: _transactions,
      tasks: _tasks,
    );
  }

  Future<void> addTransaction(Transaction transaction) async {
    try {
      final newTransaction = await SupabaseService.addTransaction(transaction);
      _transactions.insert(0, newTransaction);
      _lastLoadTime = DateTime.now();
      notifyListeners();
      _updateWidgets();
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
      _updateWidgets();
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
        _updateWidgets();
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
        _updateWidgets();
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
      _updateWidgets();
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
      _updateWidgets();
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

  // ── Review queue (auto-detected transactions) ──

  /// Load the on-device pending review queue and start listening for new
  /// auto-detected transactions app-wide (so capture works regardless of which
  /// screen is open). Safe to call on startup.
  Future<void> loadPendingReview() async {
    _pendingReview = await PendingTransactionStore.load();
    notifyListeners();
    _startDetectionListener();
  }

  /// Subscribe to the notification-listener detection stream and route each
  /// parsed transaction through the on-device classifier into the review queue.
  void _startDetectionListener() {
    _detectionSub?.cancel();
    _detectionSub =
        SmsTransactionService.instance.onTransactionDetected.listen((parsed) {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;
      final pending =
          TransactionClassifier.toPendingTransaction(parsed, userId: userId);
      addToReviewQueue(pending);
    });
  }

  /// Add a newly auto-detected transaction to the on-device review queue.
  /// De-dupes against existing pending entries with the same amount + label
  /// within a short window to avoid double-capture of the same notification.
  Future<void> addToReviewQueue(Transaction detected) async {
    final isDup = _pendingReview.any((t) =>
        t.amount == detected.amount &&
        t.displayLabel == detected.displayLabel &&
        detected.timestamp.difference(t.timestamp).abs() <
            const Duration(minutes: 2));
    if (isDup) return;

    _pendingReview.insert(0, detected);
    await PendingTransactionStore.save(_pendingReview);
    notifyListeners();
  }

  /// Confirm a pending entry: persist it to Supabase as a real transaction
  /// and remove it from the on-device queue. [edited] lets the user tweak
  /// fields before confirming.
  Future<void> confirmPending(String pendingId, {Transaction? edited}) async {
    final index = _pendingReview.indexWhere((t) => t.id == pendingId);
    if (index == -1) return;

    final toSave = (edited ?? _pendingReview[index]).copyWith(
      id: '', // let Supabase assign the real id
      status: TransactionStatus.confirmed,
    );

    await addTransaction(toSave);

    _pendingReview.removeAt(index);
    await PendingTransactionStore.save(_pendingReview);
    notifyListeners();
  }

  /// Reject (dismiss) a pending entry without saving it anywhere.
  Future<void> rejectPending(String pendingId) async {
    _pendingReview.removeWhere((t) => t.id == pendingId);
    await PendingTransactionStore.save(_pendingReview);
    notifyListeners();
  }

  /// Clear the entire review queue.
  Future<void> clearReviewQueue() async {
    _pendingReview.clear();
    await PendingTransactionStore.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _detectionSub?.cancel();
    super.dispose();
  }
}