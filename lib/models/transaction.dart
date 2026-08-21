/// Origin of a transaction entry.
enum TransactionSource {
  manual, // user typed it in
  chat, // added via AI chat
  autoDetected, // parsed from a bank/UPI notification
}

/// Review status for auto-detected entries.
/// Manual/chat entries are always [confirmed].
enum TransactionStatus {
  pending, // awaiting user review in the inbox
  confirmed, // live in the Khaata book
  rejected, // user dismissed it
}

/// Transaction model for Khaata.
///
/// Maps to Firestore `users/{uid}/transactions`.
/// `type` is 'income' or 'expense' (migrated from old credit/debit).
class Transaction {
  final String id;
  final String userId;
  final double amount;
  final String type; // 'income' or 'expense'
  final String category;
  final String? description;
  final String? person; // backward compat
  final DateTime timestamp;

  /// Where this entry came from. Defaults to manual for backward compat.
  final TransactionSource source;

  /// Classifier confidence 0.0–1.0 for auto-detected entries; null otherwise.
  final double? confidence;

  /// Review status. Manual/chat entries are confirmed; auto-detected start pending.
  final TransactionStatus status;

  /// Stable identity of the bank alert this entry was detected from — the
  /// bank's own reference number where it published one. Null for anything the
  /// user typed.
  ///
  /// One payment is commonly announced twice, by the bank's SMS and by the
  /// payment app's notification, so this is what lets a second sighting be
  /// recognised as the same money rather than booked again.
  final String? detectionKey;

  const Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.category,
    this.description,
    this.person,
    required this.timestamp,
    this.source = TransactionSource.manual,
    this.confidence,
    this.status = TransactionStatus.confirmed,
    this.detectionKey,
  });

  /// Whether this is an income entry.
  bool get isIncome => type == 'income';

  /// Whether this entry is awaiting review in the inbox.
  bool get isPending => status == TransactionStatus.pending;

  /// Whether this entry was auto-detected from a notification.
  bool get isAutoDetected => source == TransactionSource.autoDetected;

  /// Format amount with ₹ sign.
  String get formattedAmount => '₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';

  /// Display label — prefers description, falls back to person, then category.
  String get displayLabel => description ?? person ?? category;

  Transaction copyWith({
    String? id,
    String? userId,
    double? amount,
    String? type,
    String? category,
    String? description,
    String? person,
    DateTime? timestamp,
    TransactionSource? source,
    double? confidence,
    TransactionStatus? status,
    String? detectionKey,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      person: person ?? this.person,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      detectionKey: detectionKey ?? this.detectionKey,
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Handle legacy credit/debit → income/expense mapping
    String resolvedType = json['type'] as String? ?? 'expense';
    final category = json['category'] as String? ?? 'Other';
    if (resolvedType.isEmpty || (resolvedType != 'income' && resolvedType != 'expense')) {
      if (category == 'credit') {
        resolvedType = 'income';
      } else {
        resolvedType = 'expense';
      }
    }

    return Transaction(
      id: json['id']?.toString() ?? '',
      userId: json['user_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: resolvedType,
      category: category,
      description: json['description'] as String?,
      person: json['person'] as String?,
      timestamp: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      source: _sourceFromString(json['source'] as String?),
      confidence: (json['confidence'] as num?)?.toDouble(),
      // Rows without a status column are existing confirmed entries.
      status: _statusFromString(json['status'] as String?),
      detectionKey: json['detection_key'] as String?,
    );
  }

  /// Serialization for Firestore. `DateTime` values are stored natively as
  /// `Timestamp`s, so date fields are passed through unconverted.
  ///
  /// `status` is deliberately omitted: everything that reaches Firestore has
  /// been confirmed by the user, and the review queue stays on-device so
  /// detected data never leaves the phone unconfirmed. See [toLocalJson].
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'user_id': userId,
      'amount': amount,
      'type': type,
      'category': category,
      'person': person ?? '',
      'created_at': timestamp,
      'source': source.name,
    };
    if (description != null) map['description'] = description;
    if (confidence != null) map['confidence'] = confidence;
    // Kept server-side so a re-detection of an entry the user already confirmed
    // is recognised instead of being offered a second time.
    if (detectionKey != null) map['detection_key'] = detectionKey;
    return map;
  }

  /// Full serialization for the on-device pending-review queue (SharedPreferences).
  /// Unlike [toFirestore], this must stay JSON-encodable and preserves status.
  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'user_id': userId,
        'amount': amount,
        'type': type,
        'category': category,
        'description': description,
        'person': person,
        'created_at': timestamp.toIso8601String(),
        'source': source.name,
        'confidence': confidence,
        'status': status.name,
        'detection_key': detectionKey,
      };

  static TransactionSource _sourceFromString(String? s) {
    switch (s) {
      case 'autoDetected':
        return TransactionSource.autoDetected;
      case 'chat':
        return TransactionSource.chat;
      default:
        return TransactionSource.manual;
    }
  }

  static TransactionStatus _statusFromString(String? s) {
    switch (s) {
      case 'pending':
        return TransactionStatus.pending;
      case 'rejected':
        return TransactionStatus.rejected;
      default:
        return TransactionStatus.confirmed;
    }
  }

  @override
  String toString() => 'Transaction($type: ₹$amount $category - $displayLabel)';
}