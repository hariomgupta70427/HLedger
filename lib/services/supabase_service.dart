import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/retry_helper.dart';
import '../models/transaction.dart';
import '../models/task.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  // ── Auth ──

  static User? get currentUser => _client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

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
    return RetryHelper.run(() async {
      final response = await _client
          .from(AppConstants.transactionsTable)
          .insert(transaction.toJson())
          .select()
          .single();

      return Transaction.fromJson(response);
    });
  }

  static Future<Transaction> updateTransaction(Transaction transaction) async {
    return RetryHelper.run(() async {
      final response = await _client
          .from(AppConstants.transactionsTable)
          .update(transaction.toJson())
          .eq('id', transaction.id)
          .select()
          .single();

      return Transaction.fromJson(response);
    });
  }

  static Future<void> deleteTransaction(String id) async {
    return RetryHelper.run(() async {
      await _client
          .from(AppConstants.transactionsTable)
          .delete()
          .eq('id', id);
    });
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
    return RetryHelper.run(() async {
      final response = await _client
          .from(AppConstants.tasksTable)
          .insert(task.toJson())
          .select()
          .single();

      return Task.fromJson(response);
    });
  }

  static Future<Task> updateTask(Task task) async {
    return RetryHelper.run(() async {
      final response = await _client
          .from(AppConstants.tasksTable)
          .update(task.toJson())
          .eq('id', task.id)
          .select()
          .single();

      return Task.fromJson(response);
    });
  }

  static Future<void> deleteTask(String id) async {
    return RetryHelper.run(() async {
      await _client
          .from(AppConstants.tasksTable)
          .delete()
          .eq('id', id);
    });
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