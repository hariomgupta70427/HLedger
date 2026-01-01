import 'package:json_annotation/json_annotation.dart';

part 'task.g.dart';

@JsonSerializable()
class Task {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String title;
  @JsonKey(name: 'due_date')
  final DateTime? dueDate;
  final bool completed;
  final bool reminder;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.dueDate,
    required this.completed,
    required this.reminder,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);

  // For inserting into database (excludes id which is auto-generated)
  Map<String, dynamic> toJsonForInsert() {
    return {
      'user_id': userId,
      'title': title,
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      'completed': completed,
      'reminder': reminder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? dueDate,
    bool? completed,
    bool? reminder,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      reminder: reminder ?? this.reminder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}