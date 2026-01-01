import 'package:json_annotation/json_annotation.dart';

part 'transaction_model.g.dart';

@JsonSerializable()
class Transaction {
  final String id;
  final String userId;
  final String person;
  final double amount;
  final String category; // 'credit' or 'debit'
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

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionToJson(this);

  bool get isCredit => category == 'credit';
  bool get isDebit => category == 'debit';
}