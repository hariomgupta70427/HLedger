import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import 'models/task_model.dart';

class TaskService {
  final _supabase = Supabase.instance.client;

  Future<List<Task>> getTasks() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from(AppConstants.tasksTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response.map((json) => Task.fromJson(json)).toList();
  }

  Future<Task> addTask({
    required String title,
    DateTime? dueDate,
    bool reminder = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final task = Task(
      id: '',
      userId: userId,
      title: title,
      dueDate: dueDate,
      completed: false,
      reminder: reminder,
      createdAt: DateTime.now(),
    );

    final response = await _supabase
        .from(AppConstants.tasksTable)
        .insert(task.toJson())
        .select()
        .single();

    return Task.fromJson(response);
  }

  Future<Task> updateTask(Task task) async {
    final response = await _supabase
        .from(AppConstants.tasksTable)
        .update(task.toJson())
        .eq('id', task.id)
        .select()
        .single();

    return Task.fromJson(response);
  }

  Future<void> deleteTask(String id) async {
    await _supabase
        .from(AppConstants.tasksTable)
        .delete()
        .eq('id', id);
  }

  Future<List<Task>> getPendingTasks() async {
    final tasks = await getTasks();
    return tasks.where((task) => !task.completed).toList();
  }

  Future<List<Task>> getCompletedTasks() async {
    final tasks = await getTasks();
    return tasks.where((task) => task.completed).toList();
  }
}