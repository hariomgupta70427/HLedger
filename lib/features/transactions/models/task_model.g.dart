// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Task _$TaskFromJson(Map<String, dynamic> json) => Task(
  id: json['id'] as String,
  userId: json['userId'] as String,
  title: json['title'] as String,
  dueDate: json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String),
  completed: json['completed'] as bool,
  reminder: json['reminder'] as bool,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$TaskToJson(Task instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'title': instance.title,
  'dueDate': instance.dueDate?.toIso8601String(),
  'completed': instance.completed,
  'reminder': instance.reminder,
  'createdAt': instance.createdAt.toIso8601String(),
};
