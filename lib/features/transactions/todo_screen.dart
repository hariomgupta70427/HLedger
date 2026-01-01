import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/notification_service.dart';
import 'task_service.dart';
import 'models/task_model.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with SingleTickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  final NotificationService _notificationService = NotificationService();
  late TabController _tabController;
  List<Task> _pendingTasks = [];
  List<Task> _completedTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final pending = await _taskService.getPendingTasks();
      final completed = await _taskService.getCompletedTasks();
      
      setState(() {
        _pendingTasks = pending;
        _completedTasks = completed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tasks: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        backgroundColor: AppTheme.background,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.accent,
          tabs: [
            Tab(text: 'Pending (${_pendingTasks.length})'),
            Tab(text: 'Completed (${_completedTasks.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(_pendingTasks, false),
                _buildTaskList(_completedTasks, true),
              ],
            ),
    );
  }

  Widget _buildTaskList(List<Task> tasks, bool isCompleted) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompleted ? Icons.check_circle_outline : Icons.task_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isCompleted ? 'No completed tasks' : 'No pending tasks',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              isCompleted 
                  ? 'Complete some tasks to see them here'
                  : 'Start chatting to add tasks',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final isOverdue = task.dueDate != null && 
                     task.dueDate!.isBefore(DateTime.now()) && 
                     !task.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          onChanged: (value) => _toggleTaskCompletion(task),
          activeColor: AppTheme.accent,
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: task.completed ? TextDecoration.lineThrough : null,
            color: task.completed ? Colors.grey : null,
          ),
        ),
        subtitle: task.dueDate != null
            ? Text(
                'Due: ${_formatDueDate(task.dueDate!)}',
                style: TextStyle(
                  color: isOverdue ? Colors.red : Colors.grey,
                  fontWeight: isOverdue ? FontWeight.w500 : null,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.reminder && !task.completed)
              const Icon(Icons.notifications_active, color: AppTheme.accent, size: 20),
            if (isOverdue)
              const Icon(Icons.warning, color: Colors.red, size: 20),
            PopupMenuButton<String>(
              onSelected: (value) => _handleTaskAction(task, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
                if (!task.completed)
                  PopupMenuItem(
                    value: 'reminder',
                    child: Row(
                      children: [
                        Icon(
                          task.reminder ? Icons.notifications_off : Icons.notifications,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(task.reminder ? 'Remove Reminder' : 'Set Reminder'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    try {
      final updatedTask = task.copyWith(completed: !task.completed);
      await _taskService.updateTask(updatedTask);
      
      if (updatedTask.completed && task.reminder) {
        await _notificationService.cancelNotification(task.id.hashCode);
      }
      
      await _loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task: $e')),
      );
    }
  }

  Future<void> _handleTaskAction(Task task, String action) async {
    try {
      switch (action) {
        case 'delete':
          await _taskService.deleteTask(task.id);
          if (task.reminder) {
            await _notificationService.cancelNotification(task.id.hashCode);
          }
          break;
        case 'reminder':
          final updatedTask = task.copyWith(reminder: !task.reminder);
          await _taskService.updateTask(updatedTask);
          
          if (updatedTask.reminder && updatedTask.dueDate != null) {
            await _notificationService.scheduleTaskReminder(
              id: task.id.hashCode,
              title: 'Task Reminder',
              body: task.title,
              scheduledDate: updatedTask.dueDate!,
            );
          } else if (!updatedTask.reminder) {
            await _notificationService.cancelNotification(task.id.hashCode);
          }
          break;
      }
      await _loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays == -1) {
      return 'Yesterday (Overdue)';
    } else if (difference.inDays < 0) {
      return '${-difference.inDays} days overdue';
    } else if (difference.inDays < 7) {
      return 'In ${difference.inDays} days';
    } else {
      return '${dueDate.day}/${dueDate.month}/${dueDate.year}';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}