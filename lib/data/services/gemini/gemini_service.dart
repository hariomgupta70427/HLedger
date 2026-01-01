import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/constants/app_constants.dart';

class GeminiResponse {
  final String type; // 'transaction' or 'task'
  final String? category; // 'credit' or 'debit' for transactions
  final double? amount;
  final String? person;
  final String? task;
  final DateTime? dueDate;
  final bool reminderNeeded;

  GeminiResponse({
    required this.type,
    this.category,
    this.amount,
    this.person,
    this.task,
    this.dueDate,
    required this.reminderNeeded,
  });

  factory GeminiResponse.fromJson(Map<String, dynamic> json) {
    return GeminiResponse(
      type: json['type'] ?? '',
      category: json['category'],
      amount: json['amount']?.toDouble(),
      person: json['person'],
      task: json['task'],
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      reminderNeeded: json['reminder_needed'] ?? false,
    );
  }
}

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: AppConstants.geminiApiKey,
    );
  }

  Future<GeminiResponse> categorizeMessage(String message) async {
    final prompt = '''
Analyze this message and categorize it as either a transaction or task. Return ONLY valid JSON.

Message: "$message"

Rules:
- If it mentions money, amounts, giving/receiving money, or financial transactions, categorize as "transaction"
- If it mentions tasks, assignments, work to do, reminders, or deadlines, categorize as "task"
- For transactions: extract person name, amount, and determine if it's "credit" (received money) or "debit" (gave money)
- For tasks: extract task description and due date if mentioned
- Parse Hindi/Hinglish terms: "diye" = gave (debit), "mile" = received (credit), "kal" = tomorrow, "aaj" = today

Return JSON format:
{
  "type": "transaction" or "task",
  "category": "credit" or "debit" (only for transactions),
  "amount": number (only for transactions),
  "person": "name" (only for transactions),
  "task": "task description" (only for tasks),
  "due_date": "YYYY-MM-DD" (only for tasks with dates),
  "reminder_needed": true/false
}
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null) {
        throw Exception('No response from Gemini');
      }

      // Extract JSON from response
      String jsonText = response.text!.trim();
      
      // Remove markdown code blocks if present
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      
      final jsonData = json.decode(jsonText);
      return GeminiResponse.fromJson(jsonData);
    } catch (e) {
      // Fallback: try to detect basic patterns
      return _fallbackCategorization(message);
    }
  }

  GeminiResponse _fallbackCategorization(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Check for transaction keywords
    final transactionKeywords = ['diye', 'mile', 'paid', 'received', '₹', 'rs', 'rupees'];
    final taskKeywords = ['karna', 'complete', 'assignment', 'task', 'reminder', 'kal', 'tomorrow'];
    
    bool isTransaction = transactionKeywords.any((keyword) => lowerMessage.contains(keyword));
    bool isTask = taskKeywords.any((keyword) => lowerMessage.contains(keyword));
    
    if (isTransaction) {
      // Try to extract amount
      final amountRegex = RegExp(r'(\d+(?:\.\d+)?)');
      final amountMatch = amountRegex.firstMatch(message);
      final amount = amountMatch != null ? double.tryParse(amountMatch.group(1)!) : 0.0;
      
      // Determine category
      final isDebit = lowerMessage.contains('diye') || lowerMessage.contains('paid');
      
      return GeminiResponse(
        type: 'transaction',
        category: isDebit ? 'debit' : 'credit',
        amount: amount,
        person: 'Unknown',
        reminderNeeded: false,
      );
    } else if (isTask) {
      // Check for due date
      DateTime? dueDate;
      if (lowerMessage.contains('kal') || lowerMessage.contains('tomorrow')) {
        dueDate = DateTime.now().add(const Duration(days: 1));
      }
      
      return GeminiResponse(
        type: 'task',
        task: message,
        dueDate: dueDate,
        reminderNeeded: dueDate != null,
      );
    }
    
    // Default to task if unclear
    return GeminiResponse(
      type: 'task',
      task: message,
      reminderNeeded: false,
    );
  }
}