import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              _buildAppBar(isDark),
              // Messages Area
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessageBubble(message, isDark);
                        },
                      ),
              ),
              if (_isLoading) _buildLoadingIndicator(isDark),
              _buildMessageInput(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.chat_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HLedger Chat',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1D29),
                ),
              ),
              Text(
                'AI-powered assistant',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
              onPressed: _clearHistory,
              tooltip: 'Clear chat history',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : const Color(0xFF00BFA6)).withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: isDark ? Colors.white38 : const Color(0xFF00BFA6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start a conversation!',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1D29),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'I can help you track transactions and manage tasks. Just chat with me naturally!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDark) {
    final isUser = message.isUser;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isUser 
              ? const LinearGradient(colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)])
              : null,
          color: isUser 
              ? null 
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          message.text,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: isUser 
                ? Colors.white 
                : (isDark ? Colors.white : const Color(0xFF1A1D29)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Color(0xFF00BFA6),
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'AI is thinking...',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : const Color(0xFF1A1D29),
              ),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: GoogleFonts.inter(
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BFA6).withAlpha(100),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _sendMessage,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    Icons.send_rounded,
                    color: _isLoading ? Colors.white60 : Colors.white,
                  ),
                ),
              ),
            ),
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
        text: 'Error: ${e.toString()}\n\nPlease check:\n• Internet connection\n• API key is valid',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Clear Chat History',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1D29),
          ),
        ),
        content: Text(
          'Are you sure you want to clear all chat history?',
          style: GoogleFonts.inter(
            color: isDark ? Colors.white70 : const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: isDark ? Colors.white60 : const Color(0xFF6B7280)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFF87171)],
              ),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Clear',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
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