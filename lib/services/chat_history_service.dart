import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class ChatHistoryService {
  static const String _chatHistoryKey = 'chat_history';
  static const int _maxMessages = 100; // Keep last 100 messages

  static Future<List<ChatMessage>> loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString(_chatHistoryKey);
      
      if (historyJson == null || historyJson.isEmpty) {
        print('📝 ChatHistory: No history found');
        return [];
      }

      final List<dynamic> jsonList = json.decode(historyJson);
      final messages = jsonList.map((json) => ChatMessage.fromJson(json)).toList();
      
      print('📝 ChatHistory: Loaded ${messages.length} messages');
      return messages;
    } catch (e) {
      print('❌ ChatHistory: Error loading history: $e');
      return [];
    }
  }

  static Future<void> saveChatHistory(List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Keep only the last N messages to avoid storage bloat
      final messagesToSave = messages.length > _maxMessages
          ? messages.sublist(messages.length - _maxMessages)
          : messages;
      
      final jsonList = messagesToSave.map((msg) => msg.toJson()).toList();
      final historyJson = json.encode(jsonList);
      
      await prefs.setString(_chatHistoryKey, historyJson);
      print('📝 ChatHistory: Saved ${messagesToSave.length} messages');
    } catch (e) {
      print('❌ ChatHistory: Error saving history: $e');
    }
  }

  static Future<void> clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatHistoryKey);
      print('📝 ChatHistory: Cleared history');
    } catch (e) {
      print('❌ ChatHistory: Error clearing history: $e');
    }
  }
}
