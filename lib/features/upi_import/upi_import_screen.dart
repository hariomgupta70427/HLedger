import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction.dart';
import '../../providers/app_provider.dart';
import '../../services/sms_transaction_service.dart';
import '../../services/transaction_classifier.dart';
import '../compliance/prominent_disclosure_dialog.dart';

/// Review inbox for auto-detected UPI/bank transactions.
///
/// Detection runs app-wide (see [AppProvider] detection listener). This screen
/// shows the on-device pending queue and lets the user confirm, edit, or reject
/// each entry before it enters the Khaata book. Nothing is saved to the server
/// until the user confirms — the queue lives only on the device.
///
/// COMPLIANCE: before requesting SMS access, callers show the
/// prominent-disclosure dialog (see lib/features/compliance/). See
/// [_enableAutoDetect].
class UpiImportScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const UpiImportScreen({super.key, this.onNavigateToTab});

  @override
  State<UpiImportScreen> createState() => _UpiImportScreenState();
}

class _UpiImportScreenState extends State<UpiImportScreen>
    with WidgetsBindingObserver {
  final _smsService = SmsTransactionService.instance;
  bool _isChecking = false;
  bool _smsOn = false;
  bool _notificationsOn = false;

  static const _categories = [
    'Food', 'Transport', 'Shopping', 'Bills',
    'Entertainment', 'Health', 'Education', 'Work',
    'Friends & Family', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Notification access is granted on a system settings screen, so the app is
  /// backgrounded while the user decides. Re-checking on resume is what makes
  /// the toggle reflect reality instead of whatever it read before leaving.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncNotificationState();
  }

  /// On open, only CHECK which sources are already enabled — never prompt.
  ///
  /// This is the fix for the old flow that ambushed the user with a permission
  /// dialog the moment the screen opened. Enabling is now a deliberate tap.
  /// Detection itself runs app-wide from startup (main.dart + AppProvider), so
  /// this screen just reflects state.
  Future<void> _refreshStatus() async {
    setState(() => _isChecking = true);
    try {
      // initialize() only checks what was granted and resumes listening if so —
      // it never opens a system prompt.
      final sms = await _smsService.initialize();
      final notifications = await _smsService.checkNotificationAccess();
      if (mounted) {
        setState(() {
          _isChecking = false;
          _smsOn = sms;
          _notificationsOn = notifications;
        });
      }
    } catch (e) {
      debugPrint('❌ Auto-detect status check failed: $e');
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _syncNotificationState() async {
    final granted = await _smsService.checkNotificationAccess();
    if (!mounted || granted == _notificationsOn) return;
    setState(() => _notificationsOn = granted);
    // Coming back from Android's settings screen is the moment the user wants a
    // straight answer about whether it worked.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Payment detection is on. New payments will show up here.'
              : 'Payment detection is off.',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: AppColors.surface2,
      ),
    );
  }

  /// Deliberate opt-in for the SMS source.
  ///
  /// COMPLIANCE: Google Play requires a prominent in-app disclosure shown
  /// BEFORE requesting SMS access. The system dialog only appears after the
  /// user accepts.
  Future<void> _enableSms() async {
    final accepted = await ProminentDisclosure.showForSms(context);
    if (!accepted || !mounted) return;

    setState(() => _isChecking = true);
    try {
      final granted = await _smsService.requestPermission();
      if (mounted) {
        setState(() {
          _isChecking = false;
          _smsOn = granted;
        });
      }
    } catch (e) {
      debugPrint('❌ SMS auto-detect enable failed: $e');
      if (mounted) setState(() => _isChecking = false);
    }
  }

  /// Deliberate opt-in for the payment-app notification source.
  ///
  /// Android grants this on a settings screen rather than through a dialog, so
  /// the result is also re-checked on resume — see
  /// [didChangeAppLifecycleState].
  Future<void> _enableNotifications() async {
    final accepted = await ProminentDisclosure.showForNotifications(context);
    if (!accepted || !mounted) return;

    try {
      final granted = await _smsService.requestNotificationAccess();
      if (mounted) setState(() => _notificationsOn = granted);
    } catch (e) {
      debugPrint('❌ Notification access enable failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Review Inbox',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<AppProvider>(
            builder: (context, provider, _) {
              if (provider.pendingReviewCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _confirmClearAll(provider),
                child: Text('Clear all',
                    style: GoogleFonts.inter(color: AppColors.textSecondary)),
              );
            },
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isChecking) return _buildCheckingState();

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final pending = provider.pendingReview;
        // Already-detected transactions are always shown, even if a source was
        // later revoked in system settings — the queue is still the user's.
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: pending.isEmpty ? 2 : pending.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) return _buildSourcesCard();
            if (pending.isEmpty) return _buildEmptyState();
            if (index == 1) return _buildHeader(pending.length);
            final txn = pending[index - 2];
            return _PendingCard(
              key: ValueKey(txn.id),
              transaction: txn,
              categories: _categories,
              onConfirm: (edited) => provider.confirmPending(txn.id, edited: edited),
              onReject: () => provider.rejectPending(txn.id),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1);
          },
        );
      },
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count transaction${count == 1 ? '' : 's'} detected',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'On-device only',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.accent),
    );
  }

  /// Both detection sources, with what each one covers and its current state.
  ///
  /// Always shown, not only while everything is off. The two sources catch
  /// different transactions, so someone with SMS on and notifications off is
  /// still missing every in-app UPI payment — and has no other way to find out.
  Widget _buildSourcesCard() {
    final liveCount = (_smsOn ? 1 : 0) + (_notificationsOn ? 1 : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Detection sources',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  liveCount == 0 ? 'Both off' : '$liveCount of 2 on',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: liveCount == 0
                        ? AppColors.textSecondary
                        : AppColors.green,
                  ),
                ),
              ],
            ),
          ),
          _buildSourceRow(
            icon: Icons.sms_rounded,
            title: 'Bank SMS',
            detail: 'Every bank texts. Keeps working when the app is closed.',
            isOn: _smsOn,
            onEnable: _enableSms,
          ),
          Container(height: 1, color: AppColors.border),
          _buildSourceRow(
            icon: Icons.notifications_active_rounded,
            title: 'Payment app alerts',
            detail: 'Catches GPay and PhonePe payments that send no SMS. '
                'Only while HLedger is running.',
            isOn: _notificationsOn,
            onEnable: _enableNotifications,
          ),
          // Said plainly, and said here, because this is the screen where a user
          // decides how much to trust auto-detection. No detector catches cash,
          // and none catches every app.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
            child: Text(
              liveCount == 0
                  ? 'Both are optional — you can always add transactions '
                      'manually or by chat.'
                  : 'Auto-detect is a helper, not a guarantee: cash never '
                      'appears, and some apps stay quiet. Anything missed, just '
                      'add it yourself in Khaata or by chat.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceRow({
    required IconData icon,
    required String title,
    required String detail,
    required bool isOn,
    required VoidCallback onEnable,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isOn ? AppColors.green : AppColors.textSecondary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isOn ? AppColors.green : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isOn)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'On',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
            )
          else
            TextButton(
              onPressed: onEnable,
              child: Text(
                'Turn on',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final anyOn = _smsOn || _notificationsOn;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.inbox_rounded,
                color: AppColors.textSecondary, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            anyOn ? 'Nothing to review yet' : 'Auto-detect is off',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            anyOn
                ? 'The next transaction your bank or payment app announces '
                    'will show up here for you to confirm.'
                : 'Turn on a source above and HLedger will suggest '
                    'transactions here — you still confirm each one, and '
                    'nothing leaves your device until you do.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(AppProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Clear all?',
            style: GoogleFonts.inter(color: AppColors.textPrimary)),
        content: Text(
          'This dismisses all detected transactions without saving them.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear',
                style: GoogleFonts.inter(
                    color: AppColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.clearReviewQueue();
  }
}

/// A single pending transaction card with confirm / edit / reject.
class _PendingCard extends StatefulWidget {
  final Transaction transaction;
  final List<String> categories;
  final void Function(Transaction edited) onConfirm;
  final VoidCallback onReject;

  const _PendingCard({
    super.key,
    required this.transaction,
    required this.categories,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard> {
  late final TextEditingController _amountController;
  late String _type;
  late String _category;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _amountController = TextEditingController(
      text: t.amount.toStringAsFixed(
          t.amount.truncateToDouble() == t.amount ? 0 : 2),
    );
    _type = t.type;
    _category = widget.categories.contains(t.category) ? t.category : 'Other';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool get _isHighConfidence =>
      TransactionClassifier.isHighConfidence(widget.transaction.confidence ?? 0);

  void _confirm() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter a valid amount', style: GoogleFonts.inter()),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    widget.onConfirm(
      widget.transaction.copyWith(
        amount: amount,
        type: _type,
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final isExpense = _type == 'expense';
    final accent = isExpense ? AppColors.red : AppColors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isExpense
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            DateFormat('d MMM, h:mm a').format(t.timestamp),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _confidenceBadge(),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isExpense ? '-' : '+'}₹${_amountController.text}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),

          if (_expanded) _buildEditor(),

          // Action bar
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.onReject,
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                    label: Text('Reject',
                        style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  ),
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(_expanded ? Icons.check_rounded : Icons.edit_rounded,
                        size: 18, color: AppColors.textSecondary),
                    label: Text(_expanded ? 'Done' : 'Edit',
                        style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  ),
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.add_task_rounded,
                        size: 18, color: AppColors.accent),
                    label: Text('Add',
                        style: GoogleFonts.inter(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidenceBadge() {
    final high = _isHighConfidence;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: (high ? AppColors.green : AppColors.yellow).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        high ? 'High match' : 'Check',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: high ? AppColors.green : AppColors.yellow,
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type toggle
          Row(
            children: [
              _typeChip('expense', 'Expense', AppColors.red),
              const SizedBox(width: 8),
              _typeChip('income', 'Income', AppColors.green),
            ],
          ),
          const SizedBox(height: 12),
          // Amount
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.jetBrainsMono(color: AppColors.textPrimary),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Category chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.categories.map((c) {
              final selected = c == _category;
              return GestureDetector(
                onTap: () => setState(() => _category = c),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Text(
                    c,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.accent : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String value, String label, Color color) {
    final selected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : AppColors.border),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
