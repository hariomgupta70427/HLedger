import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/retry_helper.dart';
import '../models/transaction.dart';
import '../models/task.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  // ── Auth ──

  static User? get currentUser => _client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  /// Get display name for current user (email prefix or metadata name).
  static String get displayName {
    final user = currentUser;
    if (user == null) return 'User';
    final meta = user.userMetadata;
    if (meta != null && meta['full_name'] != null) return meta['full_name'];
    if (meta != null && meta['name'] != null) return meta['name'];
    final email = user.email ?? '';
    return email.split('@').first;
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  static Future<AuthResponse> signUp(String email, String password) async {
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  static Future<bool> signInWithGoogle() async {
    try {
      final response = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.hledger://login-callback',
      );
      return response;
    } on AuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'Google Sign-In failed. Please try again.';
    }
  }

  static String _handleAuthError(AuthException error) {
    switch (error.message) {
      case 'Invalid login credentials':
        return 'Invalid email or password. Please try again.';
      case 'Email not confirmed':
        return 'Please verify your email before logging in.';
      case 'User already registered':
        return 'This email is already registered. Please login instead.';
      default:
        return error.message;
    }
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Transactions ──

  static Future<List<Transaction>> getTransactions() async {
    return RetryHelper.run(() async {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _client
          .from(AppConstants.transactionsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map((json) => Transaction.fromJson(json)).toList();
    });
  }

  static Future<Transaction> addTransaction(Transaction transaction) async {
    final user = currentUser;
    if (user == null) throw Exception('Not logged in');

    final data = transaction.toJson()..['user_id'] = user.id;
    data.remove('id');

    try {
      return await RetryHelper.run(() async {
        final response = await _client
            .from(AppConstants.transactionsTable)
            .insert(data)
            .select()
            .single();

        return Transaction.fromJson(response);
      });
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase addTransaction error: ${e.message} | code: ${e.code}');
      throw Exception('Save failed: ${e.message}');
    }
  }

  static Future<Transaction> updateTransaction(Transaction transaction) async {
    final user = currentUser;
    if (user == null) throw Exception('Not logged in');

    final data = transaction.toJson()..['user_id'] = user.id;
    data.remove('id');

    try {
      return await RetryHelper.run(() async {
        final response = await _client
            .from(AppConstants.transactionsTable)
            .update(data)
            .eq('id', transaction.id)
            .select()
            .single();

        return Transaction.fromJson(response);
      });
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase updateTransaction error: ${e.message} | code: ${e.code}');
      throw Exception('Update failed: ${e.message}');
    }
  }

  static Future<void> deleteTransaction(String id) async {
    try {
      return await RetryHelper.run(() async {
        await _client
            .from(AppConstants.transactionsTable)
            .delete()
            .eq('id', id);
      });
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase deleteTransaction error: ${e.message}');
      throw Exception('Delete failed: ${e.message}');
    }
  }

  /// Real-time stream of user's transactions, ordered by created_at desc.
  static Stream<List<Transaction>> streamTransactions() {
    final userId = currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _client
        .from(AppConstants.transactionsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Transaction.fromJson(json)).toList());
  }

  // ── Tasks ──

  static Future<List<Task>> getTasks() async {
    return RetryHelper.run(() async {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _client
          .from(AppConstants.tasksTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map((json) => Task.fromJson(json)).toList();
    });
  }

  static Future<Task> addTask(Task task) async {
    final user = currentUser;
    if (user == null) throw Exception('Not logged in');

    final data = task.toJson()..['user_id'] = user.id;
    data.remove('id');

    try {
      return await RetryHelper.run(() async {
        final response = await _client
            .from(AppConstants.tasksTable)
            .insert(data)
            .select()
            .single();

        return Task.fromJson(response);
      });
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase addTask error: ${e.message} | code: ${e.code}');
      throw Exception('Save failed: ${e.message}');
    }
  }

  static Future<Task> updateTask(Task task) async {
    final user = currentUser;
    if (user == null) throw Exception('Not logged in');

    final data = task.toJson()..['user_id'] = user.id;
    data.remove('id');

    try {
      return await RetryHelper.run(() async {
        final response = await _client
            .from(AppConstants.tasksTable)
            .update(data)
            .eq('id', task.id)
            .select()
            .single();

        return Task.fromJson(response);
      });
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase updateTask error: ${e.message} | code: ${e.code}');
      throw Exception('Update failed: ${e.message}');
    }
  }

  static Future<void> deleteTask(String id) async {
    try {
      return await RetryHelper.run(() async {
        await _client
            .from(AppConstants.tasksTable)
            .delete()
            .eq('id', id);
      });
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase deleteTask error: ${e.message}');
      throw Exception('Delete failed: ${e.message}');
    }
  }

  /// Real-time stream of user's tasks, ordered by created_at desc.
  static Stream<List<Task>> streamTasks() {
    final userId = currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _client
        .from(AppConstants.tasksTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Task.fromJson(json)).toList());
  }
}