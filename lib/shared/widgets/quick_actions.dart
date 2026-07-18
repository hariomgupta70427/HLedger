import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/input_validator.dart';
import '../../models/task.dart';
import '../../models/transaction.dart';
import '../../providers/app_provider.dart';
import '../../services/supabase_service.dart';

/// Quick action cards row displayed on the dashboard.
///
/// Four action buttons: Add Expense, Add Task, Quick Note, View Summary.
class QuickActionsRow extends StatelessWidget {
  /// Called when View Summary is tapped.
  final VoidCallback? onViewSummary;

  /// Called when user wants to navigate to a tab (e.g., after adding expense → Khaata).
  final void Function(int tabIndex)? onNavigateToTab;

  const QuickActionsRow({
    super.key,
    this.onViewSummary,
    this.onNavigateToTab,
  });

  static const _categories = [
    'Food', 'Transport', 'Shopping', 'Bills',
    'Entertainment', 'Health', 'Education', 'Work',
    'Friends & Family', 'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Quick Actions',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _QuickActionCard(
                  icon: Icons.add_rounded,
                  label: 'Add Expense',
                  gradient: const [Color(0xFF6C63FF), Color(0xFF8B85FF)],
                  onTap: () => _showAddExpense(context),
                  delay: 0,
                ),
                const SizedBox(width: 10),
                _QuickActionCard(
                  icon: Icons.task_alt_rounded,
                  label: 'Add Task',
                  gradient: const [Color(0xFF00D68F), Color(0xFF00E6A0)],
                  onTap: () => _showAddTask(context),
                  delay: 1,
                ),
                const SizedBox(width: 10),
                _QuickActionCard(
                  icon: Icons.edit_note_rounded,
                  label: 'Quick Note',
                  gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                  onTap: () => _showQuickNote(context),
                  delay: 2,
                ),
                const SizedBox(width: 10),
                _QuickActionCard(
                  icon: Icons.bar_chart_rounded,
                  label: 'Summary',
                  gradient: const [Color(0xFFEC407A), Color(0xFFF06292)],
                  onTap: onViewSummary,
                  delay: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Add Expense Bottom Sheet ──

  void _showAddExpense(BuildContext context) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedType = 'expense';
    String selectedCategory = 'Food';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_rounded, color: AppColors.accent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Quick Expense',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Type toggle
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeChip(
                              label: 'Expense',
                              icon: Icons.arrow_upward_rounded,
                              isSelected: selectedType == 'expense',
                              color: AppColors.red,
                              onTap: () => setSheetState(() => selectedType = 'expense'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTypeChip(
                              label: 'Income',
                              icon: Icons.arrow_downward_rounded,
                              isSelected: selectedType == 'income',
                              color: AppColors.green,
                              onTap: () => setSheetState(() => selectedType = 'income'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Amount
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: InputValidator.validateAmount,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          prefixStyle: GoogleFonts.jetBrainsMono(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                          hintText: '0',
                          hintStyle: GoogleFonts.jetBrainsMono(
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Note
                      TextFormField(
                        controller: noteCtrl,
                        style: GoogleFonts.inter(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Note (e.g., chai with friends)',
                          hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Category chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final isSelected = selectedCategory == cat;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedCategory = cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent : AppColors.background,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppColors.accent : AppColors.border,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      // Save
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => _saveExpense(
                            context,
                            sheetCtx,
                            formKey: formKey,
                            amountCtrl: amountCtrl,
                            noteCtrl: noteCtrl,
                            type: selectedType,
                            category: selectedCategory,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Save Transaction',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveExpense(
    BuildContext parentContext,
    BuildContext sheetContext, {
    required GlobalKey<FormState> formKey,
    required TextEditingController amountCtrl,
    required TextEditingController noteCtrl,
    required String type,
    required String category,
  }) async {
    if (!formKey.currentState!.validate()) return;

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    final desc = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();

    final transaction = Transaction(
      id: '',
      userId: userId,
      amount: double.parse(amountCtrl.text.trim()),
      type: type,
      category: category,
      description: desc,
      person: desc ?? '',
      timestamp: DateTime.now(),
    );

    Navigator.pop(sheetContext);

    try {
      final provider = Provider.of<AppProvider>(parentContext, listen: false);
      await provider.addTransaction(transaction);
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Transaction added ✅', style: GoogleFonts.inter()),
            backgroundColor: AppColors.surface2,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Quick expense error: $e');
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e', style: GoogleFonts.inter()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  // ── Add Task Bottom Sheet ──

  void _showAddTask(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';
    DateTime? dueDate;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.task_alt_rounded, color: AppColors.green, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Quick Task',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Title
                      TextFormField(
                        controller: titleCtrl,
                        validator: InputValidator.validateText,
                        style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'e.g., Pay electricity bill by 5th',
                          hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Description
                      TextFormField(
                        controller: descCtrl,
                        style: GoogleFonts.inter(color: AppColors.textPrimary),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Description (optional)',
                          hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Priority
                      Row(
                        children: [
                          Text(
                            'Priority: ',
                            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          ...['low', 'medium', 'high'].map((p) {
                            final isSelected = priority == p;
                            final color = p == 'high'
                                ? AppColors.red
                                : p == 'medium'
                                    ? AppColors.yellow
                                    : AppColors.green;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setSheetState(() => priority = p),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? color.withValues(alpha: 0.2) : AppColors.background,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? color : AppColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    p[0].toUpperCase() + p.substring(1),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: isSelected ? color : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Due date
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: sheetCtx,
                            initialDate: DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (ctx, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: AppColors.accent,
                                  surface: AppColors.surface,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setSheetState(() => dueDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 10),
                              Text(
                                dueDate != null
                                    ? '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'
                                    : 'Set due date (optional)',
                                style: GoogleFonts.inter(
                                  color: dueDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Save
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => _saveTask(
                            context,
                            sheetCtx,
                            formKey: formKey,
                            titleCtrl: titleCtrl,
                            descCtrl: descCtrl,
                            priority: priority,
                            dueDate: dueDate,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Save Task',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveTask(
    BuildContext parentContext,
    BuildContext sheetContext, {
    required GlobalKey<FormState> formKey,
    required TextEditingController titleCtrl,
    required TextEditingController descCtrl,
    required String priority,
    required DateTime? dueDate,
  }) async {
    if (!formKey.currentState!.validate()) return;

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    final task = Task(
      id: '',
      userId: userId,
      title: titleCtrl.text.trim(),
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      dueDate: dueDate,
      priority: priority,
      createdAt: DateTime.now(),
    );

    Navigator.pop(sheetContext);

    try {
      final provider = Provider.of<AppProvider>(parentContext, listen: false);
      await provider.addTask(task);
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Task added ✅', style: GoogleFonts.inter()),
            backgroundColor: AppColors.surface2,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Quick task error: $e');
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e', style: GoogleFonts.inter()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  // ── Quick Note Bottom Sheet ──
  // Per RULE 9: Quick Note saves as a Task with priority=low, no due date.

  void _showQuickNote(BuildContext context) {
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.yellow.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_note_rounded, color: AppColors.yellow, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Quick Note',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saved as a task for reference',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Note text
                    TextFormField(
                      controller: noteCtrl,
                      validator: InputValidator.validateText,
                      maxLines: 3,
                      style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Type your note here…',
                        hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Save
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _saveQuickNote(context, sheetCtx, formKey, noteCtrl),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Save Note',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveQuickNote(
    BuildContext parentContext,
    BuildContext sheetContext,
    GlobalKey<FormState> formKey,
    TextEditingController noteCtrl,
  ) async {
    if (!formKey.currentState!.validate()) return;

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    // Quick Note = Task with no due date, priority low
    final task = Task(
      id: '',
      userId: userId,
      title: noteCtrl.text.trim(),
      description: 'Quick Note',
      priority: 'low',
      createdAt: DateTime.now(),
    );

    Navigator.pop(sheetContext);

    try {
      final provider = Provider.of<AppProvider>(parentContext, listen: false);
      await provider.addTask(task);
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Note saved 📝', style: GoogleFonts.inter()),
            backgroundColor: AppColors.surface2,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Quick note error: $e');
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e', style: GoogleFonts.inter()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  // ── Helpers ──

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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textSecondary, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
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

/// Individual quick action card with gradient glow and tap animation.
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback? onTap;
  final int delay;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    this.onTap,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradient[0].withValues(alpha: 0.2),
                    gradient[1].withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: gradient[0], size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (100 * delay).ms)
        .slideX(begin: 0.2, duration: 400.ms, delay: (100 * delay).ms, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.9, 0.9), duration: 300.ms, delay: (100 * delay).ms);
  }
}
