import 'package:json_annotation/json_annotation.dart';

part 'transaction.g.dart';

@JsonSerializable()
class Transaction {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String person;
  final double amount;
  final String category;
  final DateTime timestamp;
  final String? description;

  Transaction({
    required this.id,
    required this.userId,
    required this.person,
    required this.amount,
    required this.category,
    required this.timestamp,
    this.description,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionToJson(this);

  // For inserting into database (excludes id which is auto-generated)
  Map<String, dynamic> toJsonForInsert() {
    return {
      'user_id': userId,
      'person': person,
      'amount': amount,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
      if (description != null) 'description': description,
    };
  }

  bool get isCredit => category == 'credit';
  bool get isDebit => category == 'debit';
}