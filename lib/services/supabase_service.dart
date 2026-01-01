import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
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

  // Auth
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
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Transactions
  static Future<List<Transaction>> getTransactions() async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from(AppConstants.transactionsTable)
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false);

    return response.map((json) => Transaction.fromJson(json)).toList();
  }

  static Future<Transaction> addTransaction(Transaction transaction) async {
    try {
      final response = await _client
          .from(AppConstants.transactionsTable)
          .insert(transaction.toJsonForInsert())
          .select()
          .single();

      return Transaction.fromJson(response);
    } catch (e) {
      print('Error adding transaction: $e');
      print('Transaction data: ${transaction.toJsonForInsert()}');
      rethrow;
    }
  }

  // Tasks
  static Future<List<Task>> getTasks() async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from(AppConstants.tasksTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response.map((json) => Task.fromJson(json)).toList();
  }

  static Future<Task> addTask(Task task) async {
    try {
      final response = await _client
          .from(AppConstants.tasksTable)
          .insert(task.toJsonForInsert())
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      print('Error adding task: $e');
      print('Task data: ${task.toJsonForInsert()}');
      rethrow;
    }
  }

  static Future<Task> updateTask(Task task) async {
    final response = await _client
        .from(AppConstants.tasksTable)
        .update(task.toJson())
        .eq('id', task.id)
        .select()
        .single();

    return Task.fromJson(response);
  }
}