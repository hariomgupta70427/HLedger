import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';

class GeminiChatResponse {
  final String aiMessage; // The conversational response from AI
  final String type; // 'normal', 'transaction', or 'task'
  final String? category; // 'credit' or 'debit' for transactions
  final double? amount;
  final String? person;
  final String? task;
  final DateTime? dueDate;
  final bool reminderNeeded;

  GeminiChatResponse({
    required this.aiMessage,
    required this.type,
    this.category,
    this.amount,
    this.person,
    this.task,
    this.dueDate,
    required this.reminderNeeded,
  });

  factory GeminiChatResponse.fromJson(Map<String, dynamic> json) {
    return GeminiChatResponse(
      aiMessage: json['ai_message'] ?? '',
      type: json['type'] ?? 'normal',
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
  /// Main method for chat - returns conversational AI response with categorization
  Future<GeminiChatResponse> chatWithAI(String message) async {
    final prompt = '''
You are HLedger AI, a helpful assistant for managing finances and tasks. Analyze the user's message and respond naturally while also categorizing it.

User message: "$message"

Instructions:
1. Provide a natural, friendly conversational response
2. Categorize the message as "normal", "transaction", or "task":
   - "transaction": mentions money, amounts, giving/receiving money, payments
   - "task": mentions tasks, assignments, work to do, reminders, deadlines
   - "normal": casual conversation, questions, greetings, etc.
3. For transactions: extract person, amount, and category (credit=received, debit=gave)
4. For tasks: extract task description and due date
5. Parse Hindi/Hinglish: "diye"=gave (debit), "mile"=received (credit), "kal"=tomorrow, "aaj"=today

Return ONLY valid JSON:
{
  "ai_message": "Your natural conversational response here",
  "type": "normal" or "transaction" or "task",
  "category": "credit" or "debit" (only for transactions),
  "amount": number (only for transactions),
  "person": "name" (only for transactions),
  "task": "task description" (only for tasks),
  "due_date": "YYYY-MM-DD" (only for tasks with dates),
  "reminder_needed": true/false
}

Example for transaction:
User: "I gave Rahul 500"
Response: {"ai_message": "Got it! I've recorded that you gave Rahul ₹500.", "type": "transaction", "category": "debit", "amount": 500, "person": "Rahul", "reminder_needed": false}

Example for normal chat:
User: "Hello!"
Response: {"ai_message": "Hello! How can I help you today? I can help you track transactions and manage tasks.", "type": "normal", "reminder_needed": false}
''';

    try {
      print('🚀 Sending message to OpenRouter API: "$message"');
      
      final response = await http.post(
        Uri.parse(AppConstants.openRouterApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.openRouterApiKey}',
          'HTTP-Referer': 'https://hledger.app',
          'X-Title': 'HLedger',
        },
        body: jsonEncode({
          'model': AppConstants.openRouterModel,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        }),
      );

      print('📥 Received response from OpenRouter (status: ${response.statusCode})');
      
      if (response.statusCode != 200) {
        print('❌ API Error: ${response.body}');
        throw Exception('API returned ${response.statusCode}: ${response.body}');
      }

      final responseData = jsonDecode(response.body);
      print('📄 Raw API response: $responseData');
      
      final aiText = responseData['choices'][0]['message']['content'] as String;
      print('📝 AI response text: $aiText');

      // Extract JSON from response
      String jsonText = aiText.trim();
      
      // Remove markdown code blocks if present
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      }
      if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      
      jsonText = jsonText.trim();
      
      print('📋 Cleaned JSON: $jsonText');
      
      final jsonData = json.decode(jsonText);
      final result = GeminiChatResponse.fromJson(jsonData);
      print('✅ Successfully parsed response: type=${result.type}, message=${result.aiMessage}');
      return result;
    } catch (e) {
      print('❌ Error in chatWithAI: $e');
      // Fallback: return a default response
      return _fallbackChat(message);
    }
  }

  GeminiChatResponse _fallbackChat(String message) {
    print('⚠️  Using fallback categorization for: "$message"');
    final lowerMessage = message.toLowerCase();
    
    // Check for transaction keywords
    final transactionKeywords = ['diye', 'mile', 'paid', 'received', '₹', 'rs', 'rupees', 'gave', 'give'];
    final taskKeywords = ['karna', 'complete', 'assignment', 'task', 'reminder', 'kal', 'tomorrow', 'remind'];
    
    bool isTransaction = transactionKeywords.any((keyword) => lowerMessage.contains(keyword));
    bool isTask = taskKeywords.any((keyword) => lowerMessage.contains(keyword));
    
    print('🔍 Fallback detection: isTransaction=$isTransaction, isTask=$isTask');
    
    if (isTransaction) {
      // Try to extract amount
      final amountRegex = RegExp(r'(\d+(?:\.\d+)?)');
      final amountMatch = amountRegex.firstMatch(message);
      final amount = amountMatch != null ? double.tryParse(amountMatch.group(1)!) : 0.0;
      
      // Determine category
      final isDebit = lowerMessage.contains('diye') || lowerMessage.contains('paid') || lowerMessage.contains('gave');
      final category = isDebit ? 'debit' : 'credit';
      
      print('💰 Fallback transaction: amount=$amount, category=$category');
      
      return GeminiChatResponse(
        aiMessage: 'I\'ve recorded a ${category == 'debit' ? 'payment' : 'receipt'} of ₹${amount?.toStringAsFixed(0) ?? '0'}.',
        type: 'transaction',
        category: category,
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
      
      print('✅ Fallback task: task=$message, dueDate=$dueDate');
      
      return GeminiChatResponse(
        aiMessage: dueDate != null 
            ? 'Task added! I\'ll remind you tomorrow.'
            : 'Task added to your list!',
        type: 'task',
        task: message,
        dueDate: dueDate,
        reminderNeeded: dueDate != null,
      );
    }
    
    // Normal conversation
    print('💬 Fallback: normal conversation');
    return GeminiChatResponse(
      aiMessage: 'I\'m here to help you track transactions and manage tasks. You can tell me about payments you made or received, or add tasks you need to complete!',
      type: 'normal',
      reminderNeeded: false,
    );
  }
}