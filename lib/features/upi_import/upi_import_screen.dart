import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction.dart';
import '../../providers/app_provider.dart';
import '../../services/sms_transaction_service.dart';
import '../../services/supabase_service.dart';
import '../../services/upi_parser.dart';

/// Auto-detecting UPI import screen.
///
/// Listens for incoming bank/UPI notifications and shows detected
/// transactions as cards. User can review, edit, and import each one
/// to Khaata.
class UpiImportScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const UpiImportScreen({super.key, this.onNavigateToTab});

  @override
  State<UpiImportScreen> createState() => _UpiImportScreenState();
}

class _UpiImportScreenState extends State<UpiImportScreen> {
  final _smsService = SmsTransactionService.instance;
  List<UpiParseResult> _detected = [];
  bool _isScanning = false;
  bool _permissionDenied = false;
  StreamSubscription<UpiParseResult>? _realtimeSub;

  // Editable fields for the currently selected transaction
  int? _expandedIndex;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Other';
  String _selectedType = 'expense';
  bool _isSaving = false;

  static const _categories = [
    'Food', 'Transport', 'Shopping', 'Bills',
    'Entertainment', 'Health', 'Education', 'Work',
    'Friends & Family', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initAndScan();
  }

  Future<void> _initAndScan() async {
    setState(() => _isScanning = true);

    try {
      // Check if permission is already granted
      final hasPermission = await _smsService.initialize();

      if (!hasPermission) {
        // Request permission — opens Android notification access settings
        final granted = await _smsService.requestPermission();
        if (!granted) {
          if (mounted) {
            setState(() {
              _isScanning = false;
              _permissionDenied = true;
            });
          }
          return;
        }
      }

      // Load any already-detected transactions
      _detected = List.from(_smsService.detectedTransactions);

      // Listen for real-time notifications
      _realtimeSub?.cancel();
      _realtimeSub = _smsService.onTransactionDetected.listen((result) {
        if (mounted) {
          setState(() {
            _detected.insert(0, result);
          });
          _showSnackBar('🔔 New UPI transaction detected!');
        }
      });

      if (mounted) {
        setState(() {
          _isScanning = false;
          _permissionDenied = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Notification listener error: $e');
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _expandCard(int index) {
    final result = _detected[index];
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
      if (_expandedIndex == index) {
        _amountController.text = result.amount.toStringAsFixed(
          result.amount.truncateToDouble() == result.amount ? 0 : 2,
        );
        _selectedType = result.transactionType;
        _selectedCategory = result.suggestedCategory;
        final parts = <String>[];
        if (result.vpa != null) parts.add('UPI: ${result.vpa}');
        if (result.bankName != null) parts.add(result.bankName!);
        if (result.referenceNumber != null) parts.add('Ref: ${result.referenceNumber}');
        _descriptionController.text = parts.join(' · ');
      }
    });
  }

  Future<void> _importTransaction(int index) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    final result = _detected[index];

    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final desc = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    final transaction = Transaction(
      id: '',
      userId: userId,
      amount: amount,
      type: _selectedType,
      category: _selectedCategory,
      description: desc,
      person: desc ?? '',
      timestamp: result.date ?? DateTime.now(),
    );

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.addTransaction(transaction);
      if (!mounted) return;

      // Remove from detected list
      setState(() {
        _detected.removeAt(index);
        _expandedIndex = null;
        _isSaving = false;
      });
      _smsService.removeDetected(index);

      _showSnackBar('Transaction imported ✅');
    } catch (e) {
      debugPrint('❌ UPI import error: $e');
      if (mounted) {
        _showSnackBar('Failed to import: $e', isError: true);
        setState(() => _isSaving = false);
      }
    }
  }

  void _dismissTransaction(int index) {
    setState(() {
      _detected.removeAt(index);
      if (_expandedIndex == index) _expandedIndex = null;
      if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    _smsService.removeDetected(index);
    _showSnackBar('Transaction dismissed');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: isError ? AppColors.red : AppColors.surface2,
      ),
    );
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
              child: const Icon(Icons.sms_rounded, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'UPI Auto-Detect',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isScanning)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              onPressed: _initAndScan,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isScanning) {
      return _buildScanningState();
    }
    if (_permissionDenied) {
      return _buildPermissionDeniedState();
    }
    if (_detected.isEmpty) {
      return _buildEmptyState();
    }
    return _buildTransactionList();
  }

  Widget _buildScanningState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 3,
                ),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1500.ms, color: AppColors.accent.withValues(alpha: 0.3)),
          const SizedBox(height: 24),
          Text(
            'Setting up auto-detection...',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enabling notification listener for UPI transactions',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildPermissionDeniedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_off_rounded, color: AppColors.red, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'Notification Access Required',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'HLedger needs notification access to automatically detect UPI transactions from your bank notifications.\n\nTap below to open Settings and enable HLedger.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _initAndScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                label: Text(
                  'Open Settings',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'All caught up!',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No UPI transactions found in recent messages.\nNew ones will appear here automatically.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _initAndScan,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.refresh_rounded, color: AppColors.accent, size: 18),
            label: Text(
              'Scan Again',
              style: GoogleFonts.inter(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildTransactionList() {
    return Column(
      children: [
        // Info banner
        _buildInfoBanner(),
        // List
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _detected.length,
            itemBuilder: (context, index) => _buildTransactionCard(index),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.08),
            AppColors.accentLight.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_detected.length} UPI transaction${_detected.length != 1 ? 's' : ''} detected',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to review and import to Khaata',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildTransactionCard(int index) {
    final result = _detected[index];
    final isDebit = result.isDebit;
    final color = isDebit ? AppColors.red : AppColors.green;
    final isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded ? color.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Summary row (always visible)
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _expandCard(index),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDebit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDebit ? 'Money Sent' : 'Money Received',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (result.vpa != null) result.vpa!,
                            if (result.bankName != null) result.bankName!,
                            if (result.date != null) DateFormat('d MMM').format(result.date!),
                          ].join(' · '),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${result.amount.toStringAsFixed(result.amount.truncateToDouble() == result.amount ? 0 : 2)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Expanded edit section
          if (isExpanded) ...[
            Divider(color: AppColors.border, height: 1),
            _buildExpandedEdit(index, result),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (40 * (index % 10)).ms)
        .slideX(begin: 0.05, duration: 300.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildExpandedEdit(int index, UpiParseResult result) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Raw SMS
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              result.rawText,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          // Type toggle
          Row(
            children: [
              Expanded(child: _buildTypeChip(
                label: 'Expense', icon: Icons.arrow_upward_rounded,
                isSelected: _selectedType == 'expense', color: AppColors.red,
                onTap: () => setState(() => _selectedType = 'expense'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildTypeChip(
                label: 'Income', icon: Icons.arrow_downward_rounded,
                isSelected: _selectedType == 'income', color: AppColors.green,
                onTap: () => setState(() => _selectedType = 'income'),
              )),
            ],
          ),
          const SizedBox(height: 10),
          // Amount
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: GoogleFonts.jetBrainsMono(
                fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.accent,
              ),
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Description
          TextFormField(
            controller: _descriptionController,
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Description',
              hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Category
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _dismissTransaction(index),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
                  label: Text(
                    'Dismiss',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _importTransaction(index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    disabledBackgroundColor: AppColors.surface2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                  label: Text(
                    _isSaving ? 'Importing...' : 'Import to Khaata',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textSecondary, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
