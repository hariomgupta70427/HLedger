import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../models/transaction.dart';
import '../models/task.dart';

/// Bridge between Flutter app data and native Android home screen widgets.
///
/// Pushes latest expense, task, and note data to SharedPreferences
/// via [HomeWidget], then requests widget updates on the native side.
class HomeWidgetService {
  HomeWidgetService._();

  static const String _appGroupId = 'com.hariverse.hledger';

  /// Initialize the home_widget package.
  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      debugPrint('🏠 HomeWidget service initialized');
    } catch (e) {
      debugPrint('❌ HomeWidget init failed: $e');
    }
  }

  /// Push expense data to the Expense widget.
  static Future<void> updateExpenseWidget({
    required List<Transaction> transactions,
  }) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      double todaySpend = 0;
      double monthSpend = 0;
      double monthIncome = 0;
      final recentExpenses = <String>[];

      for (final t in transactions) {
        if (!t.isIncome) {
          if (t.timestamp.isAfter(todayStart)) {
            todaySpend += t.amount;
          }
          if (t.timestamp.isAfter(monthStart)) {
            monthSpend += t.amount;
          }
          if (recentExpenses.length < 3) {
            recentExpenses.add(
              '${t.category} · ₹${t.amount.toStringAsFixed(0)}',
            );
          }
        } else {
          if (t.timestamp.isAfter(monthStart)) {
            monthIncome += t.amount;
          }
        }
      }

      await HomeWidget.saveWidgetData('today_spend', '₹${todaySpend.toStringAsFixed(0)}');
      await HomeWidget.saveWidgetData('month_spend', '₹${monthSpend.toStringAsFixed(0)}');
      await HomeWidget.saveWidgetData('month_income', '₹${monthIncome.toStringAsFixed(0)}');

      for (int i = 0; i < 3; i++) {
        final key = 'last_txn_${i + 1}';
        final value = i < recentExpenses.length ? recentExpenses[i] : '';
        await HomeWidget.saveWidgetData(key, value);
      }

      await HomeWidget.updateWidget(
        androidName: 'ExpenseWidgetReceiver',
      );

      debugPrint('💰 Expense widget updated');
    } catch (e) {
      debugPrint('❌ Failed to update expense widget: $e');
    }
  }

  /// Push task data to the Tasks widget.
  static Future<void> updateTasksWidget({
    required List<Task> tasks,
  }) async {
    try {
      final pending = tasks.where((t) => !t.completed).toList();
      final completed = tasks.where((t) => t.completed).length;

      await HomeWidget.saveWidgetData('pending_tasks', '${pending.length}');
      await HomeWidget.saveWidgetData('completed_tasks', '$completed');

      // Save up to 5 pending tasks
      for (int i = 0; i < 5; i++) {
        final titleKey = 'task_${i + 1}';
        final priKey = 'task_pri_${i + 1}';
        if (i < pending.length) {
          await HomeWidget.saveWidgetData(titleKey, pending[i].title);
          await HomeWidget.saveWidgetData(priKey, pending[i].priority);
        } else {
          await HomeWidget.saveWidgetData(titleKey, '');
          await HomeWidget.saveWidgetData(priKey, 'low');
        }
      }

      await HomeWidget.updateWidget(
        androidName: 'TasksWidgetReceiver',
      );

      debugPrint('📋 Tasks widget updated');
    } catch (e) {
      debugPrint('❌ Failed to update tasks widget: $e');
    }
  }

  /// Push note data to the Quick Note widget.
  static Future<void> updateQuickNoteWidget({
    required List<Task> tasks,
  }) async {
    try {
      // Quick notes are tasks with description == 'Quick Note'
      final notes = tasks.where(
        (t) => t.description == 'Quick Note',
      ).toList();

      final recentNote = notes.isNotEmpty ? notes.first.title : '';
      final noteCount = notes.length;

      await HomeWidget.saveWidgetData('recent_note', recentNote);
      await HomeWidget.saveWidgetData('note_count', '$noteCount');

      await HomeWidget.updateWidget(
        androidName: 'QuickNoteWidgetReceiver',
      );

      debugPrint('📝 Quick Note widget updated');
    } catch (e) {
      debugPrint('❌ Failed to update quick note widget: $e');
    }
  }

  /// Update all three widgets at once.
  static Future<void> updateAllWidgets({
    required List<Transaction> transactions,
    required List<Task> tasks,
  }) async {
    await updateExpenseWidget(transactions: transactions);
    await updateTasksWidget(tasks: tasks);
    await updateQuickNoteWidget(tasks: tasks);
  }
}
