import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants/app_constants.dart';

class GeminiResponse {
  final String type;  // 'transaction', 'task', or 'conversation'
  final String? category;
  final double? amount;
  final String? person;
  final String? task;
  final DateTime? dueDate;
  final bool reminderNeeded;
  final String? reply;  // For conversation responses

  GeminiResponse({
    required this.type,
    this.category,
    this.amount,
    this.person,
    this.task,
    this.dueDate,
    required this.reminderNeeded,
    this.reply,
  });

  factory GeminiResponse.fromJson(Map<String, dynamic> json) {
    return GeminiResponse(
      type: json['type'] ?? 'conversation',
      category: json['category'],
      amount: json['amount']?.toDouble(),
      person: json['person'],
      task: json['task'],
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      reminderNeeded: json['reminder_needed'] ?? false,
      reply: json['reply'],
    );
  }
}

class GeminiService {
  static late final GenerativeModel _model;

  static void initialize() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',  // Changed to stable version
      apiKey: AppConstants.geminiApiKey,
    );
    print('✅ Gemini: Initialized with model gemini-1.5-flash');
  }

  static Future<GeminiResponse> categorizeMessage(String message) async {
    print('🔵 Gemini: Categorizing message: "$message"');
    
    final prompt = '''
Analyze this message and categorize it. Return ONLY valid JSON.

Message: "$message"

Rules:
- If it mentions money, amounts, giving/receiving money, or financial transactions, categorize as "transaction"
- If it mentions tasks, assignments, work to do, reminders, or deadlines, categorize as "task"
- If it's a general conversation (greetings, questions, casual chat), categorize as "conversation"
- For transactions: extract person name, amount, and determine if it's "credit" (received money) or "debit" (gave money)
- For tasks: extract task description and due date if mentioned
- For conversations: generate a helpful, friendly reply
- Parse Hindi/Hinglish terms: "diye" = gave (debit), "mile" = received (credit), "kal" = tomorrow, "aaj" = today

Return JSON format:
{
  "type": "transaction" or "task" or "conversation",
  "category": "credit" or "debit" (only for transactions),
  "amount": number (only for transactions),
  "person": "name" (only for transactions),
  "task": "task description" (only for tasks),
  "due_date": "YYYY-MM-DD" (only for tasks with dates),
  "reminder_needed": true/false,
  "reply": "AI generated reply" (only for conversations)
}
''';

    try {
      print('🔵 Gemini: Sending request to API...');
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      print('🔵 Gemini: Received response');
      
      if (response.text == null) {
        print('❌ Gemini: No text in response');
        throw Exception('No response from Gemini');
      }

      print('🔵 Gemini: Raw response: ${response.text}');
      String jsonText = response.text!.trim();
      
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      
      jsonText = jsonText.trim();
      print('🔵 Gemini: Cleaned JSON: $jsonText');
      
      final jsonData = json.decode(jsonText);
      print('✅ Gemini: Successfully parsed JSON: $jsonData');
      
      final geminiResponse = GeminiResponse.fromJson(jsonData);
      print('✅ Gemini: Created response - Type: ${geminiResponse.type}, Category: ${geminiResponse.category}, Amount: ${geminiResponse.amount}, Person: ${geminiResponse.person}, Task: ${geminiResponse.task}');
      
      return geminiResponse;
    } catch (e, stackTrace) {
      print('❌ Gemini: Error occurred: $e');
      print('❌ Gemini: Stack trace: $stackTrace');
      print('⚠️  Gemini: Falling back to keyword matching');
      return _fallbackCategorization(message);
    }
  }

  static GeminiResponse _fallbackCategorization(String message) {
    print('⚠️  Fallback: Using keyword-based categorization');
    final lowerMessage = message.toLowerCase();
    final originalMessage = message;
    
    // Transaction keywords
    final debitKeywords = ['diye', 'diya', 'paid', 'payment', 'de diya', 'de diye'];
    final creditKeywords = ['mile', 'mila', 'received', 'mili', 'aaye', 'aaya'];
    final moneyKeywords = ['₹', 'rs', 'rupees', 'rupee', 'paisa', 'paise'];
    
    // Task keywords
    final taskKeywords = ['karna', 'karna hai', 'complete', 'assignment', 'task', 'reminder', 'kal', 'tomorrow', 'homework', 'work'];
    
    // Check if message contains amount
    final amountRegex = RegExp(r'(\d+(?:\.\d+)?)');
    final amountMatch = amountRegex.firstMatch(message);
    final hasAmount = amountMatch != null;
    final amount = hasAmount ? double.tryParse(amountMatch.group(1)!) ?? 0.0 : 0.0;
    
    // Check for transaction indicators
    bool hasDebitKeyword = debitKeywords.any((keyword) => lowerMessage.contains(keyword));
    bool hasCreditKeyword = creditKeywords.any((keyword) => lowerMessage.contains(keyword));
    bool hasMoneyKeyword = moneyKeywords.any((keyword) => lowerMessage.contains(keyword));
    
    // Check for task indicators
    bool hasTaskKeyword = taskKeywords.any((keyword) => lowerMessage.contains(keyword));
    
    print('⚠️  Fallback: hasAmount=$hasAmount, hasDebit=$hasDebitKeyword, hasCredit=$hasCreditKeyword, hasTask=$hasTaskKeyword');
    
    // Transaction detection: Must have amount AND (debit/credit keyword OR money keyword)
    bool isTransaction = hasAmount && (hasDebitKeyword || hasCreditKeyword || hasMoneyKeyword);
    
    if (isTransaction) {
      // Extract person name
      String person = 'Unknown';
      
      // Try to extract person name before "ko" or "se"
      final personRegex = RegExp(r'(\w+)\s+(?:ko|se)', caseSensitive: false);
      final personMatch = personRegex.firstMatch(originalMessage);
      if (personMatch != null) {
        person = personMatch.group(1)!;
      }
      
      // Determine if debit or credit
      String category = 'debit';  // default
      if (hasCreditKeyword) {
        category = 'credit';
      } else if (hasDebitKeyword) {
        category = 'debit';
      } else if (lowerMessage.contains('se')) {
        category = 'credit';  // "se" usually means received from
      } else if (lowerMessage.contains('ko')) {
        category = 'debit';  // "ko" usually means gave to
      }
      
      print('⚠️  Fallback: Detected transaction - Amount: $amount, Type: $category, Person: $person');
      
      return GeminiResponse(
        type: 'transaction',
        category: category,
        amount: amount,
        person: person,
        reminderNeeded: false,
      );
    }
    
    // Task detection: Must have task keyword
    if (hasTaskKeyword) {
      DateTime? dueDate;
      if (lowerMessage.contains('kal') || lowerMessage.contains('tomorrow')) {
        dueDate = DateTime.now().add(const Duration(days: 1));
      } else if (lowerMessage.contains('aaj') || lowerMessage.contains('today')) {
        dueDate = DateTime.now();
      }
      
      print('⚠️  Fallback: Detected task - Task: $message, Due: $dueDate');
      
      return GeminiResponse(
        type: 'task',
        task: message,
        dueDate: dueDate,
        reminderNeeded: dueDate != null,
      );
    }
    
    // If no clear classification, return as conversation
    print('⚠️  Fallback: No clear classification, returning as conversation');
    
    return GeminiResponse(
      type: 'conversation',
      reminderNeeded: false,
      reply: 'I can help you track transactions and tasks. Try saying "500 Kaif ko diye" or "Assignment kal karna hai".',
    );
  }
}