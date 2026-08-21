import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/task.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/home_widget_service.dart';
import '../services/notification_service.dart';
import '../services/pending_transaction_store.dart';
import '../services/sms_transaction_service.dart';
import '../services/transaction_classifier.dart';
import '../services/upi_parser.dart';

class AppProvider extends ChangeNotifier {
  AppProvider() {
    _authSub = AuthService.authStateChanges.listen((user) {
      if (user == null) {
        _unbind();
      } else if (user.uid != _boundUserId) {
        _bind(user.uid);
      }
    });
    _failureSub = FirestoreService.failures.listen((message) {
      _syncError = message;
      notifyListeners();
    });
  }

  List<Transaction> _transactions = [];
  List<Task> _tasks = [];
  List<Transaction> _pendingReview = [];

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<Transaction>>? _transactionSub;
  StreamSubscription<List<Task>>? _taskSub;
  StreamSubscription<UpiParseResult>? _detectionSub;
  StreamSubscription<String>? _failureSub;

  String? _syncError;

  /// Set when a read or write is rejected outright, so a save can never fail
  /// in silence while the local cache keeps showing it. Cleared once shown.
  String? get syncError => _syncError;

  void clearSyncError() {
    if (_syncError == null) return;
    _syncError = null;
    notifyListeners();
  }

  String? _boundUserId;
  bool _isLoadingTransactions = false;
  bool _isLoadingTasks = false;
  bool _remindersScheduled = false;

  List<Transaction> get transactions => _transactions;
  List<Task> get tasks => _tasks;

  /// Auto-detected transactions awaiting user review (on-device only).
  List<Transaction> get pendingReview => List.unmodifiable(_pendingReview);
  int get pendingReviewCount => _pendingReview.length;

  bool get isLoading => _isLoadingTransactions || _isLoadingTasks;
  bool get isLoadingTransactions => _isLoadingTransactions;
  bool get isLoadingTasks => _isLoadingTasks;
  bool get isAuthenticated => AuthService.isAuthenticated;

  double get totalIncome =>
      _transactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
  double get totalExpense =>
      _transactions.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
  double get balance => totalIncome - totalExpense;

  // Backward compat
  double get totalCredit => totalIncome;
  double get totalDebit => totalExpense;

  // ── Live data ──

  /// Attaches snapshot listeners for [userId]. Firestore serves the first
  /// emission from its local cache, so data is on screen before the network
  /// answers — and stays correct without it.
  void _bind(String userId) {
    _boundUserId = userId;
    _remindersScheduled = false;
    _transactionSub?.cancel();
    _taskSub?.cancel();

    _isLoadingTransactions = true;
    _isLoadingTasks = true;
    notifyListeners();

    _transactionSub = FirestoreService.transactionsStream().listen(
      (transactions) {
        _transactions = transactions;
        _isLoadingTransactions = false;
        notifyListeners();
        _updateWidgets();
      },
      onError: (Object error) {
        debugPrint('Transaction stream error: $error');
        _syncError = 'Could not load your ledger from the server.';
        _isLoadingTransactions = false;
        notifyListeners();
      },
    );

    _taskSub = FirestoreService.tasksStream().listen(
      (tasks) {
        _tasks = tasks;
        _isLoadingTasks = false;
        if (!_remindersScheduled) {
          _remindersScheduled = true;
          rescheduleReminders();
        }
        notifyListeners();
        _updateWidgets();
      },
      onError: (Object error) {
        debugPrint('Task stream error: $error');
        _syncError = 'Could not load your tasks from the server.';
        _isLoadingTasks = false;
        notifyListeners();
      },
    );

    // A capture the drain held back because nobody was signed in can be filed
    // now. Without this it would sit in the queue until the next cold start.
    SmsTransactionService.instance.startCapture(_captureDetection);
  }

  void _unbind() {
    _boundUserId = null;
    _remindersScheduled = false;
    _transactionSub?.cancel();
    _taskSub?.cancel();
    _transactionSub = null;
    _taskSub = null;
    _transactions = [];
    _tasks = [];
    _isLoadingTransactions = false;
    _isLoadingTasks = false;
    notifyListeners();
  }

  /// Kept for screens that kick off a load on mount. The listeners are attached
  /// by the auth-state subscription, so this only has to cover a sign-in that
  /// raced ahead of them.
  Future<void> loadData({bool forceRefresh = false}) async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    if (forceRefresh || _boundUserId != userId) _bind(userId);
  }

  /// Pull-to-refresh. Snapshots already keep the lists current, so this re-binds
  /// only if needed and holds the indicator long enough to read as a response.
  Future<void> refresh() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    if (_boundUserId != userId) _bind(userId);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  /// Re-arm notifications for every task with a future reminder.
  ///
  /// Runs on every bind AND on every app resume, because a force-stop — which
  /// vivo/Oppo/Xiaomi power managers do freely — makes Android drop every
  /// pending alarm silently. Re-arming on resume is the layer that heals that
  /// without the user having to know it happened.
  Future<void> rescheduleReminders() async {
    final now = DateTime.now();
    int count = 0;
    for (final task in _tasks) {
      if (task.completed) continue;
      if (!task.reminder || task.reminderTime == null) continue;
      if (!task.reminderTime!.isAfter(now)) continue;

      final precision = await NotificationService().scheduleTaskReminder(
        id: task.notificationId,
        title: '📝 Task Reminder',
        body: task.title,
        scheduledDate: task.reminderTime!,
      );
      if (precision != ReminderPrecision.failed) count++;
    }
    if (count > 0) {
      debugPrint('🔄 Re-scheduled $count reminder(s)');
    }
  }

  /// Push latest data to all home screen widgets.
  void _updateWidgets() {
    HomeWidgetService.updateAllWidgets(
      transactions: _transactions,
      tasks: _tasks,
    );
  }

  // ── Writes ──
  //
  // The snapshot listeners are the single source of truth for the lists, so
  // these only hand the change to Firestore — patching the lists here as well
  // would double-count.

  Future<void> addTransaction(Transaction transaction) async {
    await FirestoreService.addTransaction(transaction);
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await FirestoreService.updateTransaction(transaction);
  }

  Future<void> deleteTransaction(String id) async {
    await FirestoreService.deleteTransaction(id);
  }

  /// Returns the saved task, whose id is available immediately and is what the
  /// caller needs to key its reminder notification.
  Future<Task> addTask(Task task) => FirestoreService.addTask(task);

  Future<void> updateTask(Task task) async {
    await FirestoreService.updateTask(task);
  }

  Future<void> deleteTask(String id) async {
    await FirestoreService.deleteTask(id);
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

  /// Subscribe to the detection stream and route each parsed transaction through
  /// the on-device classifier into the review queue. After subscribing, flush
  /// anything either source captured while the app was closed.
  void _startDetectionListener() {
    _detectionSub?.cancel();
    _detectionSub = SmsTransactionService.instance.onTransactionDetected
        .listen(_captureDetection);
    // startCapture holds the handler and drains both the SMS stash and the
    // native notification queue, keeping whatever we refuse.
    SmsTransactionService.instance.startCapture(_captureDetection);
  }

  /// Classify a detection and file it for review.
  ///
  /// Returns whether it is accounted for. False means there is no signed-in
  /// user yet, and the caller must hold on to the capture rather than drop it.
  Future<bool> _captureDetection(UpiParseResult parsed) async {
    final userId = AuthService.currentUserId;
    if (userId == null) return false;
    return addToReviewQueue(
      TransactionClassifier.toPendingTransaction(parsed, userId: userId),
    );
  }

  /// Add a newly auto-detected transaction to the on-device review queue.
  ///
  /// Returns whether the detection is accounted for — true for a duplicate as
  /// well as for a fresh entry, since in both cases there is nothing left to do
  /// with it.
  Future<bool> addToReviewQueue(Transaction detected) async {
    if (_isAlreadyKnown(detected.detectionKey)) return true;

    _pendingReview.insert(0, detected);
    await PendingTransactionStore.save(_pendingReview);
    notifyListeners();
    return true;
  }

  /// Whether a detection is already waiting for review or already in the ledger.
  ///
  /// Matched on the bank's own reference number where it published one — the
  /// only identifier that survives one payment being announced by two sources.
  /// The previous check compared amount, label and a two-minute window, which
  /// silently merged two genuine ₹200 payments to the same shop on the same day.
  bool _isAlreadyKnown(String? key) {
    if (key == null || key.isEmpty) return false;
    return _pendingReview.any((t) => t.detectionKey == key) ||
        _transactions.any((t) => t.detectionKey == key);
  }

  /// Confirm a pending entry: persist it to the ledger and remove it from the
  /// on-device queue. [edited] lets the user tweak fields before confirming.
  Future<void> confirmPending(String pendingId, {Transaction? edited}) async {
    final index = _pendingReview.indexWhere((t) => t.id == pendingId);
    if (index == -1) return;

    final toSave = (edited ?? _pendingReview[index]).copyWith(
      id: '', // a fresh document id is assigned on save
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
    _authSub?.cancel();
    _transactionSub?.cancel();
    _taskSub?.cancel();
    _detectionSub?.cancel();
    _failureSub?.cancel();
    super.dispose();
  }
}
