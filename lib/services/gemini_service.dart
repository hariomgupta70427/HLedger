import 'dart:convert';
import 'dart:math';
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
  static late final GenerativeModel _conversationModel;
  static bool _isInitialized = false;

  static void initialize() {
    print('🟡 Gemini: Starting initialization...');
    try {
      print('🟡 Gemini: Checking API key...');
      print('🟡 Gemini: API key length: ${AppConstants.geminiApiKey.length}');
      print('🟡 Gemini: API key starts with: ${AppConstants.geminiApiKey.substring(0, min(10, AppConstants.geminiApiKey.length))}...');
      
      // Validate API key
      if (AppConstants.geminiApiKey.isEmpty || AppConstants.geminiApiKey == 'YOUR_GEMINI_API_KEY') {
        print('❌ Gemini: Invalid API key. Please configure your API key in app_constants.dart');
        _isInitialized = false;
        return;
      }

      print('🟡 Gemini: API key validated, creating models...');
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: AppConstants.geminiApiKey,
      );
      
      _conversationModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: AppConstants.geminiApiKey,
      );
      
      _isInitialized = true;
      print('✅ Gemini: Initialized successfully with model gemini-1.5-flash');
      print('✅ Gemini: _isInitialized = $_isInitialized');
    } catch (e, stackTrace) {
      print('❌ Gemini: Initialization failed: $e');
      print('❌ Gemini: Stack trace: $stackTrace');
      _isInitialized = false;
    }
  }

  static Future<GeminiResponse> categorizeMessage(String message) async {
    print('🔵 Gemini: Processing message: "$message"');
    
    if (!_isInitialized) {
      print('⚠️  Gemini: Not initialized, using fallback');
      return _fallbackCategorization(message);
    }

    // First, categorize the message
    final categorizationPrompt = '''
You are a smart assistant for HLedger app that helps users track transactions and tasks through natural conversation.

Analyze this message and categorize it. The user may write in English, Hindi, or Hinglish (mixed Hindi-English).

Message: "$message"

CATEGORIZATION RULES:
1. TRANSACTION: If message mentions money, amounts, payments, giving/receiving money
   - Hindi/Hinglish keywords: diye/diya (gave), mile/mila/mili (received), paisa/paise, rupees, rs, ₹
   - English keywords: paid, payment, gave, received, lent, borrowed
   - Extract: person name, amount, type (credit/debit)
   
2. TASK: If message mentions work to do, assignments, reminders, deadlines
   - Hindi/Hinglish keywords: karna/karna hai (to do), complete, assignment, homework, kal (tomorrow), aaj (today)
   - English keywords: task, reminder, deadline, complete, finish, do
   - Extract: task description, due date if mentioned
   
3. CONVERSATION: Everything else - greetings, questions, casual chat
   - Generate a helpful, friendly response
   - Be conversational and natural

IMPORTANT PARSING RULES:
- "diye/diya" = gave money = DEBIT
- "mile/mila/mili" = received money = CREDIT
- "ko" after name = gave to that person = DEBIT
- "se" after name = received from that person = CREDIT
- "kal" = tomorrow
- "aaj" = today
- "parso" = day after tomorrow

Return ONLY valid JSON in this exact format:
{
  "type": "transaction" OR "task" OR "conversation",
  "category": "credit" OR "debit" (only for transactions),
  "amount": number (only for transactions),
  "person": "name" (only for transactions),
  "task": "task description" (only for tasks),
  "due_date": "YYYY-MM-DD" (only for tasks with dates),
  "reminder_needed": true/false,
  "reply": "your response" (only for conversations)
}

Examples:
Input: "500 Kaif ko diye"
Output: {"type": "transaction", "category": "debit", "amount": 500, "person": "Kaif", "reminder_needed": false}

Input: "Assignment kal karna hai"
Output: {"type": "task", "task": "Assignment karna hai", "due_date": "TOMORROW_DATE", "reminder_needed": true}

Input: "Hello, how are you?"
Output: {"type": "conversation", "reply": "Hello! I'm doing great, thank you for asking! I'm here to help you track your transactions and tasks. You can tell me about any money you gave or received, or tasks you need to complete. How can I assist you today?", "reminder_needed": false}

Now analyze the message and return JSON:
''';

    try {
      print('🔵 Gemini: Sending categorization request...');
      final content = [Content.text(categorizationPrompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null || response.text!.isEmpty) {
        print('❌ Gemini: Empty response from API');
        return _fallbackCategorization(message);
      }

      print('🔵 Gemini: Raw response: ${response.text}');
      String jsonText = response.text!.trim();
      
      // Clean up markdown code blocks
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      } else if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      
      jsonText = jsonText.trim();
      
      // Handle TOMORROW_DATE placeholder
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      jsonText = jsonText.replaceAll('TOMORROW_DATE', tomorrowStr);
      
      print('🔵 Gemini: Cleaned JSON: $jsonText');
      
      final jsonData = json.decode(jsonText);
      print('✅ Gemini: Successfully parsed JSON');
      
      final geminiResponse = GeminiResponse.fromJson(jsonData);
      print('✅ Gemini: Type=${geminiResponse.type}, Category=${geminiResponse.category}, Amount=${geminiResponse.amount}, Person=${geminiResponse.person}, Task=${geminiResponse.task}');
      
      // If it's a conversation and no reply was generated, generate one
      if (geminiResponse.type == 'conversation' && (geminiResponse.reply == null || geminiResponse.reply!.isEmpty)) {
        print('🔵 Gemini: Generating conversation response...');
        final conversationReply = await _generateConversationReply(message);
        return GeminiResponse(
          type: 'conversation',
          reminderNeeded: false,
          reply: conversationReply,
        );
      }
      
      return geminiResponse;
    } catch (e, stackTrace) {
      print('❌ Gemini: Error occurred: $e');
      print('❌ Gemini: Stack trace: $stackTrace');
      
      // Check if it's a network/API error
      if (e.toString().contains('API key') || e.toString().contains('403') || e.toString().contains('401')) {
        print('❌ Gemini: API key error detected');
      }
      
      print('⚠️  Gemini: Falling back to keyword matching');
      return _fallbackCategorization(message);
    }
  }

  static Future<String> _generateConversationReply(String message) async {
    try {
      final conversationPrompt = '''
You are a friendly AI assistant for HLedger, a personal finance and task management app.

User said: "$message"

Generate a helpful, friendly, and natural response. Keep it concise (2-3 sentences max).

Guidelines:
- Be warm and conversational
- If they're greeting you, greet back
- If they ask what you can do, explain you can help track transactions and tasks
- If they ask a question, answer it helpfully
- Use a friendly, casual tone

Respond naturally:
''';

      final content = [Content.text(conversationPrompt)];
      final response = await _conversationModel.generateContent(content);
      
      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.trim();
      }
    } catch (e) {
      print('❌ Gemini: Conversation generation failed: $e');
    }
    
    // Fallback conversation responses
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('hello') || lowerMessage.contains('hi') || lowerMessage.contains('hey')) {
      return 'Hello! 👋 I\'m here to help you track your transactions and tasks. Just tell me naturally what you need!';
    } else if (lowerMessage.contains('help') || lowerMessage.contains('kya kar sakte')) {
      return 'I can help you track money transactions and tasks! Just tell me like:\n• "500 Kaif ko diye" for transactions\n• "Assignment kal karna hai" for tasks';
    }
    
    return 'I\'m here to help! You can tell me about transactions (like "500 Kaif ko diye") or tasks (like "Assignment kal karna hai"). What would you like to track?';
  }

  static GeminiResponse _fallbackCategorization(String message) {
    print('⚠️  Fallback: Using keyword-based categorization');
    final lowerMessage = message.toLowerCase();
    final originalMessage = message;
    
    // Transaction keywords
    final debitKeywords = ['diye', 'diya', 'paid', 'payment', 'de diya', 'de diye', 'dene', 'kharch'];
    final creditKeywords = ['mile', 'mila', 'received', 'mili', 'aaye', 'aaya', 'mili', 'liye'];
    final moneyKeywords = ['₹', 'rs', 'rupees', 'rupee', 'paisa', 'paise', 'inr'];
    
    // Task keywords
    final taskKeywords = ['karna', 'karna hai', 'complete', 'assignment', 'task', 'reminder', 'kal', 'tomorrow', 'homework', 'work', 'kaam', 'karni hai', 'karne'];
    
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
      } else {
        // Try to extract name after amount
        final nameAfterAmount = RegExp(r'\d+\s+(\w+)');
        final nameMatch = nameAfterAmount.firstMatch(originalMessage);
        if (nameMatch != null) {
          final possibleName = nameMatch.group(1)!.toLowerCase();
          // Skip common words
          if (!['ko', 'se', 'rs', 'rupees', 'paisa'].contains(possibleName)) {
            person = nameMatch.group(1)!;
          }
        }
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
      } else if (lowerMessage.contains('parso')) {
        dueDate = DateTime.now().add(const Duration(days: 2));
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
    
    // Generate a contextual response
    String reply;
    if (lowerMessage.contains('hello') || lowerMessage.contains('hi') || lowerMessage.contains('hey') || lowerMessage.contains('namaste')) {
      reply = 'Hello! 👋 I\'m your HLedger assistant. I can help you track transactions and tasks. Just tell me naturally!';
    } else if (lowerMessage.contains('help') || lowerMessage.contains('kya') || lowerMessage.contains('what')) {
      reply = 'I can help you with:\n💰 Transactions: "500 Kaif ko diye" or "1000 mile salary se"\n✅ Tasks: "Assignment kal karna hai" or "Meeting aaj 3 baje"\n\nJust tell me naturally in Hindi, English, or Hinglish!';
    } else {
      reply = 'I\'m here to help! Tell me about any transactions or tasks, and I\'ll track them for you. 😊';
    }
    
    return GeminiResponse(
      type: 'conversation',
      reminderNeeded: false,
      reply: reply,
    );
  }
}