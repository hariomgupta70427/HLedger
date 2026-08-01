import 'dart:convert';
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

/// AI chat service using Groq (OpenAI-compatible API) with model fallback.
///
/// Keeps the filename as gemini_service.dart to avoid breaking imports.
class GeminiService {
  static const String _baseUrl = AppConstants.groqApiUrl;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${AppConstants.groqKey}',
  };

  static const String _systemPrompt = '''
You are HLedger — a personal finance and task buddy.
Talk like a close friend on WhatsApp. Casual, warm, short. Max 2 sentences in reply.

Match user's language — Hindi, English, Hinglish. Use "yaar", "bhai" in Hinglish.

RULES:
1. ALWAYS respond with ONLY a single JSON object. No text before or after. No markdown.
2. NEVER wrap JSON in code blocks or backticks.
3. NEVER add explanations outside the JSON.
4. When the user mentions money spent/received, or a task/reminder, the APP will ASK the user to confirm before saving. So your "reply" should ASK, not announce as done. Example: "₹200 Food add kar du? ✓" or "Reminder set kar du kal ke liye? 🔔".

JSON FORMATS:

Money spent/received → MUST include description. Reply must ASK for confirmation:
{"action":"ADD_TRANSACTION","data":{"amount":200,"type":"expense","category":"Food","description":"chai"},"reply":"₹200 Food (chai) add kar du? ✓"}

Task or reminder → include reminder_time when a time/day is implied. Reply must ASK:
{"action":"ADD_TASK","data":{"title":"Doctor ke paas jana","due_date":"2026-07-19","reminder_time":"2026-07-19T10:00:00","priority":"medium"},"reply":"Reminder set kar du kal ke liye? 🔔"}

Balance/spending query:
{"action":"GET_BALANCE","reply":"Checking your Khaata..."}

Normal chat (no action needed):
{"action":"NONE","reply":"your reply here"}

FIELD RULES:
- action: MUST be one of ADD_TRANSACTION, ADD_TASK, GET_BALANCE, NONE
- description: REQUIRED for transactions — short label like "chai", "petrol", "salary"
- type: "income" or "expense" only
- category: Food, Transport, Shopping, Bills, Entertainment, Health, Education, Work, Other
- priority: "low", "medium", or "high"
- due_date: "YYYY-MM-DD" or null. Resolve relative dates using TODAY given below.
- reminder_time: "YYYY-MM-DDTHH:MM:SS" (local time) or null. Set it whenever the user implies a day/time ("kal", "subah", "shaam 5 baje", "next monday"). Default to 09:00 if only a day is given.
- amount: number only, no currency symbols

EXPENSE vs INCOME (Hinglish/Hindi cues):
- expense: "diye", "diya", "paid", "gave", "spent", "kharch", "kharcha", "kharide", "kharida", "bought", "pi/khaya (chai/khana)", "bill", "recharge", "de diye", "cut gaye", "nikaale"
- income: "mile", "mila", "received", "got", "earned", "aaye", "aaya", "salary aayi", "credit hua", "refund mila", "wapas mile"
- If unclear but money left the user → expense.

TASK / REMINDER cues:
- "karna hai", "karni hai", "jana hai", "yaad dila", "remind", "reminder", "call karna", "meeting", "appointment", "bill bharna hai", "milna hai"

RELATIVE DATES (resolve against TODAY):
- "aaj" = today, "kal" = tomorrow, "parso" = day after tomorrow, "narso" = 3 days later
- "agle/next <weekday>" = next occurrence of that weekday
- "subah" = 09:00, "dopahar" = 13:00, "shaam" = 18:00, "raat" = 21:00
''';

  /// Send a message to AI with conversation history.
  ///
  /// [history] should already contain all previous messages (user + assistant).
  /// [userMessage] is the NEW user message to send (will NOT be added to history here).
  ///
  /// Returns parsed [AIChatResponse] with action and reply.
  /// On all-model failure, returns a friendly fallback message.
  Future<AIChatResponse> sendMessage(
    List<Map<String, dynamic>> history,
    String userMessage,
  ) async {
    final sanitized = InputValidator.sanitizeForAI(userMessage);

    // Give the model today's date + weekday so it can resolve "kal", "next monday", etc.
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dateContext =
        'TODAY is ${now.toIso8601String().substring(0, 10)} (${weekdays[now.weekday - 1]}). '
        'Current time is ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}. '
        'Resolve all relative dates/times against this.';

    // Build messages: system + last 10 history messages + current user message
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': '$_systemPrompt\n$dateContext'},
      ...history.length > 10 ? history.sublist(history.length - 10) : history,
      {'role': 'user', 'content': sanitized},
    ];

    // Try each model in order with delay between failures
    for (int i = 0; i < AppConstants.groqModels.length; i++) {
      final model = AppConstants.groqModels[i];
      try {
        debugPrint('🤖 Trying model: $model (${i + 1}/${AppConstants.groqModels.length})');
        final result = await _callModel(model, messages);
        if (result != null) {
          debugPrint('✅ Got response from $model');
          return result;
        }
        // Model returned null (rate limit, server error, etc.) — wait before next
        if (i < AppConstants.groqModels.length - 1) {
          final delay = Duration(seconds: 1 + i);
          debugPrint('⏳ Waiting ${delay.inSeconds}s before trying next model...');
          await Future.delayed(delay);
        }
      } catch (e) {
        debugPrint('⚠️ Model $model failed with exception: $e');
        if (i < AppConstants.groqModels.length - 1) {
          await Future.delayed(Duration(seconds: 1 + i));
        }
        continue;
      }
    }

    // All models failed — honest error message
    debugPrint('❌ All ${AppConstants.groqModels.length} models failed');
    return const AIChatResponse(
      action: 'NONE',
      reply: 'AI se connect nahi ho pa raha abhi 😔 Internet check karo aur retry karo.',
    );
  }

  /// Call a specific model and parse the response.
  /// Returns null if the model fails or returns empty.
  Future<AIChatResponse?> _callModel(
    String model,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      debugPrint('📡 Calling $model...');
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: _headers,
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': 0.7,
              'max_tokens': 250,
              // Groq native JSON mode — guarantees the reply is a valid JSON
              // object, so we never depend on markdown-stripping heuristics.
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('📨 Response from $model: status=${response.statusCode}');

      // Model not found — skip immediately
      if (response.statusCode == 404) {
        debugPrint('❌ Model $model not found (404) — skipping');
        return null;
      }

      // Rate limited — try next model
      if (response.statusCode == 429) {
        debugPrint('⚠️ Rate limited on model $model');
        return null;
      }

      // Server error — try next model
      if (response.statusCode >= 500) {
        debugPrint('⚠️ Server error ${response.statusCode} on model $model');
        return null;
      }

      // Auth error — API key issue
      if (response.statusCode == 401) {
        debugPrint('❌ Groq auth failed — check API key');
        return null;
      }

      if (response.statusCode != 200) {
        debugPrint('⚠️ Unexpected status ${response.statusCode} from $model');
        return null;
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.isEmpty) return null;

      // Try to parse as JSON — handle various edge cases
      try {
        String jsonText = content.trim();

        // Remove markdown code blocks if present
        if (jsonText.startsWith('```json')) {
          jsonText = jsonText.substring(7);
        } else if (jsonText.startsWith('```')) {
          jsonText = jsonText.substring(3);
        }
        if (jsonText.endsWith('```')) {
          jsonText = jsonText.substring(0, jsonText.length - 3);
        }
        jsonText = jsonText.trim();

        // Try to extract JSON object if there's text before/after it
        if (!jsonText.startsWith('{')) {
          final startIdx = jsonText.indexOf('{');
          final endIdx = jsonText.lastIndexOf('}');
          if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
            jsonText = jsonText.substring(startIdx, endIdx + 1);
          }
        }

        final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
        
        // Validate action field
        final action = parsed['action'] as String? ?? 'NONE';
        if (!['ADD_TRANSACTION', 'ADD_TASK', 'GET_BALANCE', 'NONE'].contains(action)) {
          parsed['action'] = 'NONE';
        }
        
        return AIChatResponse.fromJson(parsed);
      } catch (e) {
        debugPrint('⚠️ JSON parse failed for model $model: $e');
        // If JSON parsing fails, treat the raw text as a plain reply
        return AIChatResponse(action: 'NONE', reply: content.trim());
      }
    } catch (e) {
      debugPrint('❌ Model $model error: $e');
      return null;
    }
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