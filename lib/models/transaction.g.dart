// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Transaction _$TransactionFromJson(Map<String, dynamic> json) => Transaction(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  person: json['person'] as String,
  amount: (json['amount'] as num).toDouble(),
  category: json['category'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  description: json['description'] as String?,
);

Map<String, dynamic> _$TransactionToJson(Transaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'person': instance.person,
      'amount': instance.amount,
      'category': instance.category,
      'timestamp': instance.timestamp.toIso8601String(),
      'description': instance.description,
    };
