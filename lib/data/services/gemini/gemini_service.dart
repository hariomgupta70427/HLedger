import 'dart:convert';
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

/// AI chat service using OpenRouter with model fallback chain.
///
/// Keeps the filename as gemini_service.dart to avoid breaking imports.
class GeminiService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${AppConstants.openRouterKey}',
    'HTTP-Referer': 'https://hledger.app',
    'X-Title': 'HLedger',
  };

  static const String _systemPrompt = '''
You are HLedger — a personal finance and task buddy.
Talk like a close friend on WhatsApp.
Casual, warm, short messages. Max 2 sentences in reply.

NEVER say:
- "I'm here to help you track transactions"
- "You can tell me about payments"
- Any corporate filler phrase

Match user's language — Hindi, English, or Hinglish.
Use "yaar", "bhai" if they write in Hinglish.

ALWAYS respond with valid JSON only. Nothing outside JSON.

When user mentions spending or receiving money:
{"action":"ADD_TRANSACTION","data":{"amount":200,"type":"expense","category":"Food","description":"chai"},"reply":"Done ✓ ₹200 chai added."}

When user mentions a task or reminder:
{"action":"ADD_TASK","data":{"title":"Call mom","due_date":"2025-03-22","priority":"medium"},"reply":"Added 📝 Call mom — tomorrow."}

When user asks about balance/spending:
{"action":"GET_BALANCE","reply":"Checking your Khaata..."}

Normal conversation (no action):
{"action":"NONE","reply":"Your casual response here."}

Categories: Food, Transport, Shopping, Bills, Entertainment, Health, Education, Work, Other

type must be: "income" or "expense" only
priority must be: "low", "medium", or "high" only
due_date format: "YYYY-MM-DD" or null

Parse Hindi/Hinglish naturally:
"diye" / "paid" / "gave" / "spent" = expense
"mile" / "received" / "got" / "earned" = income
"kal" = tomorrow, "aaj" = today
"karna hai" / "yaad dila" = task
''';

  /// Send a message to AI with conversation history.
  ///
  /// Returns parsed [AIChatResponse] with action and reply.
  /// On all-model failure, returns a friendly fallback message.
  Future<AIChatResponse> sendMessage(
    List<Map<String, dynamic>> history,
    String userMessage,
  ) async {
    final sanitized = InputValidator.sanitizeForAI(userMessage);

    // Build messages list: system + last 10 history + current
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt},
      ...history.length > 10 ? history.sublist(history.length - 10) : history,
      {'role': 'user', 'content': sanitized},
    ];

    // Try each model in order
    for (final model in AppConstants.openRouterModels) {
      try {
        final result = await _callModel(model, messages);
        if (result != null) return result;
      } catch (_) {
        continue;
      }
    }

    // All models failed — friendly fallback
    return const AIChatResponse(
      action: 'NONE',
      reply: 'Kuch gadbad ho gayi 😅 Dobara try karo?',
    );
  }

  /// Call a specific model and parse the response.
  /// Returns null if the model fails or returns empty.
  Future<AIChatResponse?> _callModel(
    String model,
    List<Map<String, dynamic>> messages,
  ) async {
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: _headers,
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'temperature': 0.7,
            'max_tokens': 250,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) return null;

    // Try to parse as JSON
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

      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
      return AIChatResponse.fromJson(parsed);
    } catch (_) {
      // If JSON parsing fails, treat the raw text as a plain reply
      return AIChatResponse(action: 'NONE', reply: content.trim());
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