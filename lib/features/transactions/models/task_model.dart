import 'package:json_annotation/json_annotation.dart';

part 'task_model.g.dart';

@JsonSerializable()
class Task {
  final String id;
  final String userId;
  final String title;
  final DateTime? dueDate;
  final bool completed;
  final bool reminder;
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