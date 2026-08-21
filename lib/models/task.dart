/// Task model for the Tasks module.
///
/// Maps to Firestore `users/{uid}/tasks`.
class Task {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String priority; // 'low', 'medium', 'high'
  final bool completed;
  final bool reminder;
  final DateTime? reminderTime; // exact time for notification
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.dueDate,
    this.priority = 'medium',
    this.completed = false,
    this.reminder = false,
    this.reminderTime,
    required this.createdAt,
  });

  /// Whether this task is overdue.
  bool get isOverdue {
    if (dueDate == null || completed) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  /// Stable id for this task's reminder notification.
  ///
  /// `id.hashCode` was used for this, but Dart makes no promise that
  /// `Object.hashCode` is stable across runs — and these ids are handed to
  /// Android's AlarmManager, which outlives the process. A change in VM hashing
  /// would orphan every alarm already registered and make every cancel miss.
  /// FNV-1a is fixed by definition; masking to 31 bits keeps it inside the Java
  /// `int` the platform channel expects.
  int get notificationId {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    bool? completed,
    bool? reminder,
    DateTime? reminderTime,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      reminder: reminder ?? this.reminder,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id']?.toString() ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      priority: json['priority'] as String? ?? 'medium',
      completed: json['completed'] as bool? ?? json['is_completed'] as bool? ?? false,
      reminder: json['reminder'] as bool? ?? false,
      reminderTime: json['reminder_time'] != null
          ? DateTime.tryParse(json['reminder_time'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// Serialization for Firestore. `DateTime` values are stored natively as
  /// `Timestamp`s, so date fields are passed through unconverted.
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'priority': priority,
      'completed': completed,
      'reminder': reminder,
      'created_at': createdAt,
    };
    if (description != null) map['description'] = description;
    if (dueDate != null) map['due_date'] = dueDate;
    if (reminderTime != null) map['reminder_time'] = reminderTime;
    return map;
  }

  @override
  String toString() => 'Task($title, priority=$priority, completed=$completed)';
}