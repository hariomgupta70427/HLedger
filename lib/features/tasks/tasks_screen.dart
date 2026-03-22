import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/input_validator.dart';
import '../../models/task.dart';
import '../../providers/app_provider.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../shared/widgets/shimmer_skeleton.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  TasksScreenState createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  String _filter = 'All'; // 'All', 'Active', 'Completed'

  /// Called by DashboardScreen FAB to open add task sheet.
  void showAddTask() {
    _showAddTaskSheet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            if (provider.isLoadingTasks) {
              return const TaskSkeletonLoader();
            }

            final filtered = _filteredTasks(provider.tasks);

            return RefreshIndicator(
              onRefresh: () => provider.refresh(),
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Text(
                        'Tasks',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // Filter chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: ['All', 'Active', 'Completed'].map((f) {
                          final isSelected = _filter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _filter = f),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.accent : AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? AppColors.accent : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  f,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  // Task list
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt_rounded,
                                size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _filter == 'All'
                                  ? 'No tasks yet'
                                  : 'No ${_filter.toLowerCase()} tasks',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final task = filtered[index];
                          return Slidable(
                            startActionPane: ActionPane(
                              motion: const BehindMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _toggleTask(provider, task),
                                  backgroundColor: task.completed ? AppColors.yellow : AppColors.green,
                                  foregroundColor: Colors.white,
                                  icon: task.completed ? Icons.undo_rounded : Icons.check_rounded,
                                  label: task.completed ? 'Undo' : 'Done',
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ],
                            ),
                            endActionPane: ActionPane(
                              motion: const BehindMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _deleteTask(provider, task),
                                  backgroundColor: AppColors.red,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_rounded,
                                  label: 'Delete',
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ],
                            ),
                            child: _TaskCard(
                              task: task,
                              onToggle: () => _toggleTask(provider, task),
                              onSetReminder: () => _setReminder(provider, task),
                            ).animate()
                                .fadeIn(duration: 300.ms, delay: (50 * index).ms)
                                .slideX(begin: 0.1, duration: 300.ms),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Task> _filteredTasks(List<Task> tasks) {
    switch (_filter) {
      case 'Active':
        return tasks.where((t) => !t.completed).toList();
      case 'Completed':
        return tasks.where((t) => t.completed).toList();
      default:
        return tasks;
    }
  }

  Future<void> _toggleTask(AppProvider provider, Task task) async {
    try {
      await provider.updateTask(task.copyWith(completed: !task.completed));
    } catch (e) {
      debugPrint('❌ Toggle task error: $e');
    }
  }

  Future<void> _deleteTask(AppProvider provider, Task task) async {
    try {
      // Cancel any scheduled notification
      await NotificationService().cancelNotification(task.id.hashCode);
      await provider.deleteTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task deleted', style: GoogleFonts.inter()),
            backgroundColor: AppColors.surface2,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e', style: GoogleFonts.inter()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _setReminder(AppProvider provider, Task task) async {
    // Pick date
    final date = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: _themedPicker,
    );
    if (date == null || !mounted) return;

    // Pick time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: _themedPicker,
    );
    if (time == null || !mounted) return;

    final reminderDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    // Schedule notification
    await NotificationService().scheduleTaskReminder(
      id: task.id.hashCode,
      title: '📝 Task Reminder',
      body: task.title,
      scheduledDate: reminderDateTime,
    );

    // Update task with reminder info
    final updated = task.copyWith(
      reminder: true,
      reminderTime: reminderDateTime,
    );
    await provider.updateTask(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder set for ${DateFormat('d MMM, h:mm a').format(reminderDateTime)} ⏰',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.surface2,
        ),
      );
    }
  }

  void _showAddTaskSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? dueDate;
    TimeOfDay? reminderTime;
    String priority = 'medium';
    bool setReminder = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      Text(
                        'New Task',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      TextFormField(
                        controller: titleCtrl,
                        validator: (v) => InputValidator.validateText(v),
                        style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Task title',
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
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: _themedPicker,
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
                                    ? DateFormat('d MMM yyyy').format(dueDate!)
                                    : 'Set due date',
                                style: GoogleFonts.inter(
                                  color: dueDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Reminder toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.notifications_active_rounded,
                                size: 18,
                                color: setReminder ? AppColors.accent : AppColors.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                setReminder && reminderTime != null
                                    ? 'Reminder at ${reminderTime!.format(context)}'
                                    : 'Set Reminder',
                                style: GoogleFonts.inter(
                                  color: setReminder ? AppColors.textPrimary : AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Switch(
                              value: setReminder,
                              activeTrackColor: AppColors.accent.withValues(alpha: 0.4),
                              activeThumbColor: AppColors.accent,
                              onChanged: (val) async {
                                if (val) {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                    builder: _themedPicker,
                                  );
                                  if (time != null) {
                                    setSheetState(() {
                                      setReminder = true;
                                      reminderTime = time;
                                    });
                                  }
                                } else {
                                  setSheetState(() {
                                    setReminder = false;
                                    reminderTime = null;
                                  });
                                }
                              },
                            ),
                          ],
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
                            formKey: formKey,
                            titleCtrl: titleCtrl,
                            descCtrl: descCtrl,
                            dueDate: dueDate,
                            priority: priority,
                            setReminder: setReminder,
                            reminderTime: reminderTime,
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
    BuildContext sheetContext, {
    required GlobalKey<FormState> formKey,
    required TextEditingController titleCtrl,
    required TextEditingController descCtrl,
    required DateTime? dueDate,
    required String priority,
    required bool setReminder,
    required TimeOfDay? reminderTime,
  }) async {
    if (!formKey.currentState!.validate()) return;

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please login first', style: GoogleFonts.inter()),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    // Build reminder datetime
    DateTime? reminderDateTime;
    if (setReminder && reminderTime != null) {
      final dateForReminder = dueDate ?? DateTime.now().add(const Duration(days: 1));
      reminderDateTime = DateTime(
        dateForReminder.year,
        dateForReminder.month,
        dateForReminder.day,
        reminderTime.hour,
        reminderTime.minute,
      );
    }

    final task = Task(
      id: '',
      userId: userId,
      title: titleCtrl.text.trim(),
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      dueDate: dueDate,
      priority: priority,
      reminder: setReminder,
      reminderTime: reminderDateTime,
      createdAt: DateTime.now(),
    );

    Navigator.pop(sheetContext);

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final savedTask = await provider.addTask(task);

      // Schedule notification if reminder is set
      if (setReminder && reminderDateTime != null) {
        await NotificationService().scheduleTaskReminder(
          id: savedTask.id.hashCode,
          title: '📝 Task Reminder',
          body: savedTask.title,
          scheduledDate: reminderDateTime,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              setReminder ? 'Task added with reminder ⏰' : 'Task added ✅',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: AppColors.surface2,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Save task error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e', style: GoogleFonts.inter()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Widget _themedPicker(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
      ),
      child: child!,
    );
  }
}

/// Premium task card with priority indicator and reminder info.
class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onSetReminder;

  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onSetReminder,
  });

  Color get _priorityColor {
    switch (task.priority) {
      case 'high':
        return AppColors.red;
      case 'medium':
        return AppColors.yellow;
      default:
        return AppColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: task.completed
                    ? AppColors.green.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: task.completed ? AppColors.green : AppColors.border,
                  width: 2,
                ),
              ),
              child: task.completed
                  ? const Icon(Icons.check_rounded, size: 16, color: AppColors.green)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: task.completed
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    decoration: task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (task.dueDate != null) ...[
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: task.isOverdue ? AppColors.red : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('d MMM').format(task.dueDate!),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: task.isOverdue ? AppColors.red : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (task.reminder) ...[
                      Icon(
                        Icons.notifications_active_rounded,
                        size: 12,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.reminderTime != null
                            ? DateFormat('h:mm a').format(task.reminderTime!)
                            : 'Reminder',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Reminder button
          if (!task.completed)
            IconButton(
              icon: Icon(
                task.reminder ? Icons.notifications_active : Icons.notifications_none_rounded,
                size: 20,
                color: task.reminder ? AppColors.accent : AppColors.textSecondary,
              ),
              onPressed: onSetReminder,
              tooltip: 'Set reminder',
              visualDensity: VisualDensity.compact,
            ),
          // Priority badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _priorityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              task.priority[0].toUpperCase() + task.priority.substring(1),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _priorityColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
