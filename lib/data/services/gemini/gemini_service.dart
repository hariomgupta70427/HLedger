import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/input_validator.dart';

/// Response from the AI service, parsed from JSON.
class AIChatResponse {
  final String action; // 'NONE', 'ADD_TRANSACTION', 'ADD_TASK', 'GET_BALANCE'
  final String reply;
  final Map<String, dynamic>? data;

  const AIChatResponse({
    required this.action,
    required this.reply,
    this.data,
  });

  factory AIChatResponse.fromJson(Map<String, dynamic> json) {
    return AIChatResponse(
      action: json['action'] as String? ?? 'NONE',
      reply: json['reply'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

/// AI chat client.
///
/// Holds no provider credentials. Model selection, provider fallback and both
/// API keys live in the HLedger AI Worker — a key compiled into the APK is
/// readable by anyone who decompiles it, and cannot be rotated out of an app
/// that is already installed. See `backend/hledger-ai-worker/`.
///
/// Keeps the filename as gemini_service.dart to avoid breaking imports.
class GeminiService {
  static const Duration _timeout = Duration(seconds: 40);

  /// Sends a message and returns the parsed action.
  ///
  /// [history] should already contain all previous messages (user + assistant).
  /// [userMessage] is the NEW user message (it is not added to history here).
  ///
  /// Never throws: chat failure is a reply the user can read, not an exception
  /// for the widget tree to handle.
  Future<AIChatResponse> sendMessage(
    List<Map<String, dynamic>> history,
    String userMessage,
  ) async {
    if (!AppConstants.hasAiProxy) {
      debugPrint('❌ AI_PROXY_URL not set for this build');
      return const AIChatResponse(
        action: 'NONE',
        reply: 'AI chat is configured nahi hai is build mein. '
            'Transaction ya task manually add kar lo.',
      );
    }

    final token = await _idToken();
    if (token == null) {
      return const AIChatResponse(
        action: 'NONE',
        reply: 'AI chat ke liye sign in karna padega 🔑',
      );
    }

    final sanitized = InputValidator.sanitizeForAI(userMessage);

    // The device's own local time. The Worker runs in UTC at an arbitrary edge
    // location, so it cannot resolve "kal" or "shaam" on its own.
    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}T'
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.aiProxyUrl}/chat'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'message': sanitized,
              'history': history
                  .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
                  .map((m) => {
                        'role': m['role'],
                        'content': m['content']?.toString() ?? '',
                      })
                  .toList(),
              'now': stamp,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ AI reply via ${body['provider']}/${body['model']}');
        final parsed = AIChatResponse.fromJson(body);
        if (parsed.reply.isEmpty) {
          return const AIChatResponse(
            action: 'NONE',
            reply: 'AI ka jawab poora nahi aaya 🤔 Ek baar dobara bolo?',
          );
        }
        return parsed;
      }

      // The Worker sends a user-safe sentence with every error, and never
      // forwards provider text — which could otherwise leak configuration.
      return AIChatResponse(action: 'NONE', reply: _explain(response));
    } on TimeoutException {
      debugPrint('⏱️ AI proxy timed out');
      return const AIChatResponse(
        action: 'NONE',
        reply: 'AI ne jawab dene mein bahut time laga ⏱️ Dobara try karo.',
      );
    } on SocketException {
      return const AIChatResponse(
        action: 'NONE',
        reply: 'Internet nahi mil raha 📴 Connection check karke retry karo.',
      );
    } on http.ClientException catch (e) {
      debugPrint('📴 AI proxy network error: $e');
      return const AIChatResponse(
        action: 'NONE',
        reply: 'Internet nahi mil raha 📴 Connection check karke retry karo.',
      );
    } catch (e) {
      debugPrint('❌ AI proxy error: $e');
      return const AIChatResponse(
        action: 'NONE',
        reply: 'AI se baat nahi ho payi 😔 Thodi der baad try karo.',
      );
    }
  }

  /// A fresh Firebase ID token, which is what the Worker authenticates against.
  Future<String?> _idToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('❌ Could not get ID token: $e');
      return null;
    }
  }

  String _explain(http.Response response) {
    debugPrint('📨 AI proxy ${response.statusCode}');
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {
      // Fall through to a status-based message.
    }
    if (response.statusCode == 401) {
      return 'Session expire ho gayi 🔑 Dobara sign in karo.';
    }
    if (response.statusCode == 429) {
      return 'AI abhi busy hai 😅 Ek minute baad dobara bolo.';
    }
    return 'AI service down hai abhi 🛠️ Thodi der baad try karo.';
  }

  // ── Legacy compatibility ──

  /// Old API used by existing code. Wraps [sendMessage] with the old format.
  Future<GeminiChatResponse> chatWithAI(String message) async {
    final result = await sendMessage([], message);

    String type = 'normal';
    String? category;
    double? amount;
    String? person;
    String? task;
    DateTime? dueDate;
    bool reminderNeeded = false;

    if (result.action == 'ADD_TRANSACTION' && result.data != null) {
      type = 'transaction';
      amount = (result.data!['amount'] as num?)?.toDouble();
      category = result.data!['type'] == 'income' ? 'credit' : 'debit';
      person = result.data!['description'] as String?;
    } else if (result.action == 'ADD_TASK' && result.data != null) {
      type = 'task';
      task = result.data!['title'] as String?;
      final dueDateStr = result.data!['due_date'] as String?;
      if (dueDateStr != null) {
        dueDate = DateTime.tryParse(dueDateStr);
        reminderNeeded = dueDate != null;
      }
    }

    return GeminiChatResponse(
      aiMessage: result.reply,
      type: type,
      category: category,
      amount: amount,
      person: person,
      task: task,
      dueDate: dueDate,
      reminderNeeded: reminderNeeded,
    );
  }
}

/// Legacy response class for backward compatibility.
class GeminiChatResponse {
  final String aiMessage;
  final String type; // 'normal', 'transaction', or 'task'
  final String? category;
  final double? amount;
  final String? person;
  final String? task;
  final DateTime? dueDate;
  final bool reminderNeeded;

  const GeminiChatResponse({
    required this.aiMessage,
    required this.type,
    this.category,
    this.amount,
    this.person,
    this.task,
    this.dueDate,
    required this.reminderNeeded,
  });
}
