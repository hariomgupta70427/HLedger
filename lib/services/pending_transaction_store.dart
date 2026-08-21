import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

/// On-device store for auto-detected transactions awaiting review.
///
/// Privacy by design: detected transactions live ONLY on the user's device
/// (SharedPreferences) until they explicitly confirm one. Nothing is sent to
/// Firestore or any server while pending. On confirm, the entry is inserted as
/// a normal transaction; on reject, it's simply dropped.
class PendingTransactionStore {
  PendingTransactionStore._();

  static const String _key = 'pending_transactions';
  static const int _maxPending = 100;

  /// Load all pending (unreviewed) transactions from device storage.
  static Future<List<Transaction>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ PendingTransactionStore load failed: $e');
      return [];
    }
  }

  /// Persist the full pending list, trimming to the most recent [_maxPending].
  static Future<void> save(List<Transaction> pending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed =
          pending.length > _maxPending ? pending.sublist(0, _maxPending) : pending;
      final raw = json.encode(trimmed.map((t) => t.toLocalJson()).toList());
      await prefs.setString(_key, raw);
    } catch (e) {
      debugPrint('❌ PendingTransactionStore save failed: $e');
    }
  }

  /// Clear all pending entries.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('❌ PendingTransactionStore clear failed: $e');
    }
  }
}
