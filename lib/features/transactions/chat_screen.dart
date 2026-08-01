import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/gemini/gemini_service.dart';
import '../../models/transaction.dart';
import '../../models/task.dart';
import '../../providers/app_provider.dart';
import '../../services/chat_history_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../shared/widgets/typing_indicator.dart';

/// A transient action the assistant has detected and is asking the user to
/// confirm before it touches the Khaata / Tasks. Never persisted — it lives
/// only until the user taps Confirm or Cancel (or sends another message).
class _PendingAction {
  final String kind; // 'transaction' | 'task'
  final Transaction? transaction;
  final Task? task;

  const _PendingAction.transaction(this.transaction)
      : kind = 'transaction',
        task = null;

  const _PendingAction.task(this.task)
      : kind = 'task',
        transaction = null;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  final List<ChatMessage> _messages = [];
  final List<Map<String, dynamic>> _chatHistory = [];
  bool _isLoading = false;

  /// Currently awaiting Confirm/Cancel from the user, if any.
  _PendingAction? _pendingAction;

  static const List<_QuickReply> _quickReplies = [
    _QuickReply('Add expense', '💸', 'Maine 200 ki chai pi'),
    _QuickReply('Set reminder', '🔔', 'Kal doctor ke paas jana hai'),
    _QuickReply('Check balance', '📊', 'Mera balance kitna hai?'),
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final history = await ChatHistoryService.loadChatHistory();
    if (history.isNotEmpty && mounted) {
      setState(() {
        _messages.addAll(history);
        // Build chat history for AI context
        for (final msg in history) {
          _chatHistory.add({
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.text,
          });
        }
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _messages.isEmpty && _pendingAction == null
                  ? _buildEmptyState()
                  : _buildMessageList(),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    // Item layout: [ ...messages, (pending card)?, (typing indicator)? ]
    final pendingSlot = _pendingAction != null ? 1 : 0;
    final loadingSlot = _isLoading ? 1 : 0;
    final itemCount = _messages.length + pendingSlot + loadingSlot;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Typing indicator is always last.
        if (_isLoading && index == itemCount - 1) {
          return const TypingIndicator();
        }
        // Pending confirmation card sits after all messages.
        if (_pendingAction != null && index == _messages.length) {
          return _buildPendingCard(_pendingAction!);
        }
        final message = _messages[index];
        final showDaySeparator = index == 0 ||
            !_isSameDay(_messages[index - 1].timestamp, message.timestamp);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDaySeparator) _buildDaySeparator(message.timestamp),
            _buildMessageBubble(message),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDaySeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(thatDay).inDays;
    String label;
    if (diff == 0) {
      label = 'Today';
    } else if (diff == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('EEE, d MMM').format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'H',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HLedger Chat',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Your finance buddy',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearHistory,
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary),
            tooltip: 'Clear chat',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'H',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Text(
              'Hey 👋',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell me what you spent, or what you need to do. I\'ll ask before saving anything.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final qr in _quickReplies)
                  _buildQuickReplyChip(qr),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildQuickReplyChip(_QuickReply qr) {
    return GestureDetector(
      onTap: () {
        _messageController.text = qr.prefill;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '${qr.emoji}  ${qr.label}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final timeLabel = DateFormat('h:mm a').format(message.timestamp);

    if (isUser) {
      // User bubble — right aligned
      return Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: const BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                message.text,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 4, bottom: 2),
              child: Text(
                timeLabel,
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3, duration: 200.ms);
    }

    // AI bubble — left aligned with avatar
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _aiAvatar(),
            const SizedBox(width: 8),
            // Bubble
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      message.text,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, bottom: 2),
                    child: Text(
                      timeLabel,
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3, duration: 200.ms);
  }

  Widget _aiAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'H',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Inline Confirm / Cancel card for a detected transaction or task.
  Widget _buildPendingCard(_PendingAction pending) {
    final bool isTransaction = pending.kind == 'transaction';
    final IconData icon;
    final String title;
    final String subtitle;

    if (isTransaction) {
      final t = pending.transaction!;
      final isIncome = t.isIncome;
      icon = isIncome ? Icons.south_west_rounded : Icons.north_east_rounded;
      title = '${t.formattedAmount}  ·  ${t.category}';
      final label = t.displayLabel;
      subtitle = '${isIncome ? 'Income' : 'Expense'}${label.isNotEmpty && label != t.category ? '  ·  $label' : ''}';
    } else {
      final task = pending.task!;
      icon = task.reminder ? Icons.notifications_active_rounded : Icons.check_circle_outline_rounded;
      title = task.title;
      subtitle = task.reminder && task.reminderTime != null
          ? DateFormat('EEE, d MMM • h:mm a').format(task.reminderTime!)
          : (task.dueDate != null
              ? DateFormat('EEE, d MMM').format(task.dueDate!)
              : 'No reminder time');
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _aiAvatar(),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(14),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 18, color: AppColors.accent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _confirmButton(
                            label: 'Confirm',
                            icon: Icons.check_rounded,
                            filled: true,
                            onTap: () => _confirmPending(pending),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _confirmButton(
                            label: 'Cancel',
                            icon: Icons.close_rounded,
                            filled: false,
                            onTap: _cancelPending,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2, duration: 200.ms);
  }

  Widget _confirmButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: filled ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        // Removed the visible border — was causing the ugly border on focus
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Type anything...',
                hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isLoading ? AppColors.surface2 : AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: _isLoading ? AppColors.textSecondary : Colors.white,
                size: 18,
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

    // Add user message to UI immediately
    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      // A new message supersedes any un-answered confirmation card.
      _pendingAction = null;
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // FIX: Don't add to _chatHistory here — sendMessage() will add userMessage itself.
    // We pass _chatHistory as previous context, and the current text separately.
    // This prevents the duplicate user message that was confusing the AI.

    try {
      final response = await _geminiService.sendMessage(_chatHistory, text);

      // Now add to chat history AFTER the call succeeds
      _chatHistory.add({'role': 'user', 'content': text});

      // Add AI reply
      final aiMessage = ChatMessage(
        text: response.reply,
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
      });

      _chatHistory.add({'role': 'assistant', 'content': response.reply});

      // Detect actions → show inline confirmation (does NOT auto-execute).
      _handleAction(response);

      // Save chat history locally
      await ChatHistoryService.saveChatHistory(_messages);
    } catch (e) {
      debugPrint('❌ Chat error: $e');
      final errorMessage = ChatMessage(
        text: 'Thoda busy hoon abhi, 2 second mein dobara try karo 😅',
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMessage);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  /// Turns an AI response into either an inline confirmation card
  /// (transactions/tasks) or an immediate reply (balance). Nothing is written
  /// to the Khaata/Tasks until the user taps Confirm.
  void _handleAction(AIChatResponse response) {
    if (!mounted) return;

    final userId = SupabaseService.currentUser?.id;

    if (response.action == 'ADD_TRANSACTION' && response.data != null) {
      if (userId == null) {
        debugPrint('⚠️ No user logged in, skipping action');
        return;
      }
      final data = response.data!;
      final description = data['description'] as String? ?? data['person'] as String?;
      final transaction = Transaction(
        id: '',
        userId: userId,
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
        type: data['type'] as String? ?? 'expense',
        category: data['category'] as String? ?? 'Other',
        description: description,
        person: description ?? '', // Supabase NOT NULL — always provide
        timestamp: DateTime.now(),
        source: TransactionSource.chat,
      );
      setState(() => _pendingAction = _PendingAction.transaction(transaction));
      _scrollToBottom();
    } else if (response.action == 'ADD_TASK' && response.data != null) {
      if (userId == null) {
        debugPrint('⚠️ No user logged in, skipping action');
        return;
      }
      final data = response.data!;
      final reminderTime = data['reminder_time'] != null
          ? DateTime.tryParse(data['reminder_time'] as String)
          : null;
      final dueDate = data['due_date'] != null
          ? DateTime.tryParse(data['due_date'] as String)
          : null;
      final hasReminder = reminderTime != null;
      final task = Task(
        id: '',
        userId: userId,
        title: data['title'] as String? ?? 'Untitled Task',
        description: data['description'] as String?,
        dueDate: dueDate ?? reminderTime,
        priority: data['priority'] as String? ?? 'medium',
        reminder: hasReminder,
        reminderTime: reminderTime,
        createdAt: DateTime.now(),
      );
      setState(() => _pendingAction = _PendingAction.task(task));
      _scrollToBottom();
    } else if (response.action == 'GET_BALANCE') {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final income = appProvider.totalIncome;
      final expense = appProvider.totalExpense;
      final balance = income - expense;

      final balanceMsg = ChatMessage(
        text: '💰 Income: ₹${income.toStringAsFixed(0)}\n'
            '💸 Expense: ₹${expense.toStringAsFixed(0)}\n'
            '📊 Balance: ₹${balance.toStringAsFixed(0)}',
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() => _messages.add(balanceMsg));
      _chatHistory.add({'role': 'assistant', 'content': balanceMsg.text});
      _scrollToBottom();
    }
  }

  /// User tapped Confirm → actually persist the detected entry.
  Future<void> _confirmPending(_PendingAction pending) async {
    if (!mounted) return;
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    // Clear the card immediately so it can't be double-tapped.
    setState(() => _pendingAction = null);

    try {
      String ack;
      if (pending.kind == 'transaction') {
        final t = pending.transaction!;
        await appProvider.addTransaction(t);
        debugPrint('✅ Transaction added via chat: ${t.formattedAmount}');
        ack = 'Done ✅ ${t.formattedAmount} ${t.category} add ho gaya.';
      } else {
        final task = pending.task!;
        final saved = await appProvider.addTask(task);
        debugPrint('✅ Task added via chat: ${task.title}');
        // Mirror TasksScreen: schedule the local notification for future reminders.
        if (task.reminder &&
            task.reminderTime != null &&
            task.reminderTime!.isAfter(DateTime.now())) {
          await NotificationService().scheduleTaskReminder(
            id: saved.id.hashCode,
            title: '📝 Task Reminder',
            body: saved.title,
            scheduledDate: task.reminderTime!,
          );
          ack = 'Set ✅ Reminder lag gaya — '
              '${DateFormat('EEE, d MMM • h:mm a').format(task.reminderTime!)}.';
        } else {
          ack = 'Added 📝 ${task.title}';
        }
      }
      _appendAssistantMessage(ack);
    } catch (e) {
      debugPrint('❌ Action failed: $e');
      _appendAssistantMessage('Entry save nahi ho payi 😕 Check karo internet connection.');
    } finally {
      if (mounted) {
        await ChatHistoryService.saveChatHistory(_messages);
      }
    }
  }

  /// User tapped Cancel → drop the pending entry, assistant acknowledges.
  void _cancelPending() {
    if (!mounted) return;
    setState(() => _pendingAction = null);
    _appendAssistantMessage('Theek hai, kuch save nahi kiya 👍');
    ChatHistoryService.saveChatHistory(_messages);
  }

  void _appendAssistantMessage(String text) {
    if (!mounted) return;
    final msg = ChatMessage(text: text, isUser: false, timestamp: DateTime.now());
    setState(() => _messages.add(msg));
    _chatHistory.add({'role': 'assistant', 'content': text});
    _scrollToBottom();
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear Chat?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'This will delete all chat messages.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear', style: GoogleFonts.inter(color: AppColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ChatHistoryService.clearChatHistory();
      setState(() {
        _messages.clear();
        _chatHistory.clear();
        _pendingAction = null;
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

/// A tappable suggestion shown on the empty state that prefills the input.
class _QuickReply {
  final String label;
  final String emoji;
  final String prefill;
  const _QuickReply(this.label, this.emoji, this.prefill);
}
