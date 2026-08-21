import 'dart:async';

// `hide Transaction`: cloud_firestore exports its own Transaction (the
// runTransaction handle), which would shadow the ledger model.
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../models/task.dart';
import '../../models/transaction.dart';
import 'auth_service.dart';

/// Reads and writes the signed-in user's ledger under
/// `users/{uid}/transactions` and `users/{uid}/tasks`.
///
/// Scoping by document path rather than a `user_id` filter keeps the security
/// rules to a single uid comparison and keeps `orderBy('created_at')` off the
/// composite-index list.
class FirestoreService {
  static const String _createdAt = 'created_at';

  static final StreamController<String> _failures =
      StreamController<String>.broadcast();

  /// Terminal read/write failures, for the UI to surface. Retryable offline
  /// writes never appear here.
  static Stream<String> get failures => _failures.stream;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── Transactions ──

  static Stream<List<Transaction>> transactionsStream() =>
      _watch(AppConstants.transactionsCollection, Transaction.fromJson);

  static Future<Transaction> addTransaction(Transaction transaction) async {
    final uid = _requireUid();
    final ref = _collection(AppConstants.transactionsCollection).doc();
    final saved = transaction.copyWith(id: ref.id, userId: uid);

    _push(ref.set(saved.toFirestore()), 'add transaction');
    return saved;
  }

  static Future<Transaction> updateTransaction(Transaction transaction) async {
    final uid = _requireUid();
    final saved = transaction.copyWith(userId: uid);

    _push(
      _collection(AppConstants.transactionsCollection)
          .doc(transaction.id)
          .set(saved.toFirestore()),
      'update transaction',
    );
    return saved;
  }

  static Future<void> deleteTransaction(String id) async {
    _requireUid();
    _push(
      _collection(AppConstants.transactionsCollection).doc(id).delete(),
      'delete transaction',
    );
  }

  // ── Tasks ──

  static Stream<List<Task>> tasksStream() =>
      _watch(AppConstants.tasksCollection, Task.fromJson);

  static Future<Task> addTask(Task task) async {
    final uid = _requireUid();
    final ref = _collection(AppConstants.tasksCollection).doc();
    final saved = task.copyWith(id: ref.id, userId: uid);

    _push(ref.set(saved.toFirestore()), 'add task');
    return saved;
  }

  static Future<Task> updateTask(Task task) async {
    final uid = _requireUid();
    final saved = task.copyWith(userId: uid);

    _push(
      _collection(AppConstants.tasksCollection).doc(task.id).set(saved.toFirestore()),
      'update task',
    );
    return saved;
  }

  static Future<void> deleteTask(String id) async {
    _requireUid();
    _push(
      _collection(AppConstants.tasksCollection).doc(id).delete(),
      'delete task',
    );
  }

  // ── Internals ──

  static String _requireUid() {
    final uid = AuthService.currentUserId;
    if (uid == null) throw Exception('Not signed in');
    return uid;
  }

  static CollectionReference<Map<String, dynamic>> _collection(String name) => _db
      .collection(AppConstants.usersCollection)
      .doc(_requireUid())
      .collection(name);

  static Stream<List<T>> _watch<T>(
    String name,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (AuthService.currentUserId == null) return Stream.value(<T>[]);

    return _collection(name)
        .orderBy(_createdAt, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => parse(_decode(doc))).toList());
  }

  /// Firestore returns dates as [Timestamp]s, while the models parse ISO-8601
  /// strings so the same `fromJson` can also read the on-device pending queue
  /// back out of SharedPreferences. Normalising here keeps the models free of
  /// any Firestore import.
  static Map<String, dynamic> _decode(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return <String, dynamic>{
      for (final field in data.entries)
        field.key: field.value is Timestamp
            ? (field.value as Timestamp).toDate().toIso8601String()
            : field.value,
      'id': doc.id,
    };
  }

  /// A Firestore write only completes once the server acknowledges it, so
  /// awaiting one blocks forever while offline. Letting it run unawaited keeps
  /// the UI responsive: the local cache applies the change immediately, the
  /// snapshot listeners emit it, and the SDK retries until it lands.
  ///
  /// A pending write stays pending — it does not error. So an error arriving
  /// here is always terminal (rejected rules, a missing database, a malformed
  /// document) and the user has to be told, or the write is lost in silence
  /// while the cache keeps showing it as saved.
  static void _push(Future<void> write, String action) {
    write.catchError((Object error) {
      debugPrint('Firestore could not $action: $error');
      _reportFailure(action, error);
    });
  }

  static void _reportFailure(String action, Object error) {
    if (_failures.isClosed) return;
    _failures.add(_describe(action, error));
  }

  static String _describe(String action, Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Could not $action — the server rejected it. Check the '
              'Firestore security rules.';
        case 'unauthenticated':
          return 'Could not $action — your session expired. Sign in again.';
        case 'not-found':
        case 'failed-precondition':
          return 'Could not $action — the Firestore database is unreachable. '
              'Confirm it exists for this project.';
      }
    }
    return 'Could not $action. Changes are saved on this device and will '
        'retry.';
  }
}
