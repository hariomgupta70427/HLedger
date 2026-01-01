// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Task _$TaskFromJson(Map<String, dynamic> json) => Task(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  title: json['title'] as String,
  dueDate: json['due_date'] == null
      ? null
      : DateTime.parse(json['due_date'] as String),
  completed: json['completed'] as bool,
  reminder: json['reminder'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$TaskToJson(Task instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'title': instance.title,
  'due_date': instance.dueDate?.toIso8601String(),
  'completed': instance.completed,
  'reminder': instance.reminder,
  'created_at': instance.createdAt.toIso8601String(),
};
