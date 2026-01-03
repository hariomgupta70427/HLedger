import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/gemini/gemini_service.dart';
import '../../providers/app_provider.dart';
import '../../services/chat_history_service.dart';
import '../../models/transaction.dart';
import '../../models/task.dart';
import '../../services/supabase_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final history = await ChatHistoryService.loadChatHistory();
    if (history.isNotEmpty) {
      setState(() {
        _messages.addAll(history);
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HLedger Chat'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearHistory,
            tooltip: 'Clear chat history',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.accent),
                  const SizedBox(width: 12),
                  Text('AI is thinking...', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Start a conversation!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'I can help you track transactions and manage tasks. Just chat with me naturally!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? AppTheme.userChatBubble : AppTheme.aiChatBubble,
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          message.text,
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _isLoading ? null : _sendMessage,
            backgroundColor: _isLoading ? Colors.grey : AppTheme.accent,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Add user message
    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Get AI response with categorization
      final response = await _geminiService.chatWithAI(text);
      
      // Add AI message
      final aiMessage = ChatMessage(
        text: response.aiMessage,
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
      });

      // Handle categorization
      await _handleCategorization(response);

      // Save chat history
      await ChatHistoryService.saveChatHistory(_messages);
      
    } catch (e, stackTrace) {
      print('❌ Error in _sendMessage: $e');
      print('❌ Stack trace: $stackTrace');
      
      // Add error message with details
      final errorMessage = ChatMessage(
        text: 'Error: ${e.toString()}\n\nPlease check:\n• Internet connection\n• Gemini API key is set in app_constants.dart\n• API key is valid',
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(errorMessage);
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _handleCategorization(GeminiChatResponse response) async {
    if (!mounted) return;

    print('🔄 Handling categorization: type=${response.type}');

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final userId = SupabaseService.currentUser?.id;

    if (userId == null) {
      print('⚠️  User not authenticated, skipping categorization save');
      return;
    }

    try {
      if (response.type == 'transaction' && response.amount != null && response.person != null) {
        print('💰 Creating transaction: person=${response.person}, amount=${response.amount}, category=${response.category}');
        // Create and save transaction
        final transaction = Transaction(
          id: '', // Will be generated by Supabase
          userId: userId,
          person: response.person!,
          amount: response.amount!,
          category: response.category ?? 'debit',
          timestamp: DateTime.now(),
          description: null,
        );

        await appProvider.addTransaction(transaction);
        print('✅ Transaction saved successfully: ${response.person} - ₹${response.amount}');
        
      } else if (response.type == 'task' && response.task != null) {
        print('✅ Creating task: title=${response.task}, dueDate=${response.dueDate}');
        // Create and save task
        final task = Task(
          id: '', // Will be generated by Supabase
          userId: userId,
          title: response.task!,
          dueDate: response.dueDate,
          completed: false,
          reminder: response.reminderNeeded,
          createdAt: DateTime.now(),
        );

        await appProvider.addTask(task);
        print('✅ Task saved successfully: ${response.task}');
      } else {
        print('💬 Normal conversation - not saving anything (type=${response.type})');
      }
    } catch (e) {
      print('❌ Error saving categorized item: $e');
      // Don't show error to user - the chat message was already sent successfully
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to clear all chat history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ChatHistoryService.clearChatHistory();
      setState(() {
        _messages.clear();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}