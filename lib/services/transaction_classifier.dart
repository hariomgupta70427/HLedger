import '../models/transaction.dart';
import '../services/upi_parser.dart';

/// Result of classifying a parsed transaction: a category plus a confidence
/// score that drives whether the entry is shown as high- or low-confidence
/// in the review inbox.
class ClassificationResult {
  final String category;
  final double confidence; // 0.0–1.0

  const ClassificationResult(this.category, this.confidence);
}

/// On-device transaction classifier.
///
/// Everything here runs locally — no network, no server. Given a parsed UPI
/// notification, it infers a spending category and a confidence score using
/// merchant/VPA keyword matching. This is the "brain" behind auto-entry and
/// is intentionally deterministic and explainable (no ML model to ship).
class TransactionClassifier {
  TransactionClassifier._();

  /// Canonical category list — must stay in sync with the Khaata categories.
  static const List<String> categories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Education',
    'Work',
    'Friends & Family',
    'Other',
  ];

  /// Keyword → category map. Keys are matched (lowercased, substring) against
  /// the VPA and the raw notification text. Ordered roughly by specificity.
  static const Map<String, String> _keywordCategory = {
    // Food & dining
    'zomato': 'Food',
    'swiggy': 'Food',
    'dominos': 'Food',
    'mcdonald': 'Food',
    'kfc': 'Food',
    'starbucks': 'Food',
    'restaurant': 'Food',
    'cafe': 'Food',
    'food': 'Food',
    'eat': 'Food',
    'dhaba': 'Food',
    'bakery': 'Food',
    // Transport
    'uber': 'Transport',
    'ola': 'Transport',
    'rapido': 'Transport',
    'irctc': 'Transport',
    'redbus': 'Transport',
    'metro': 'Transport',
    'petrol': 'Transport',
    'fuel': 'Transport',
    'hpcl': 'Transport',
    'iocl': 'Transport',
    'bpcl': 'Transport',
    'fastag': 'Transport',
    'railway': 'Transport',
    // Shopping
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'ajio': 'Shopping',
    'meesho': 'Shopping',
    'nykaa': 'Shopping',
    'store': 'Shopping',
    'mart': 'Shopping',
    'retail': 'Shopping',
    'shop': 'Shopping',
    // Bills & utilities
    'electricity': 'Bills',
    'recharge': 'Bills',
    'jio': 'Bills',
    'airtel': 'Bills',
    'vodafone': 'Bills',
    'vi ': 'Bills',
    'bsnl': 'Bills',
    'broadband': 'Bills',
    'gas': 'Bills',
    'water': 'Bills',
    'bill': 'Bills',
    'dth': 'Bills',
    'insurance': 'Bills',
    'rent': 'Bills',
    // Entertainment
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'hotstar': 'Entertainment',
    'prime video': 'Entertainment',
    'bookmyshow': 'Entertainment',
    'pvr': 'Entertainment',
    'inox': 'Entertainment',
    'youtube': 'Entertainment',
    'game': 'Entertainment',
    // Health
    'pharmacy': 'Health',
    'apollo': 'Health',
    'medplus': 'Health',
    'hospital': 'Health',
    'clinic': 'Health',
    'medical': 'Health',
    'pharmeasy': 'Health',
    '1mg': 'Health',
    'diagnostic': 'Health',
    // Education
    'school': 'Education',
    'college': 'Education',
    'university': 'Education',
    'course': 'Education',
    'udemy': 'Education',
    'coursera': 'Education',
    'byju': 'Education',
    'unacademy': 'Education',
    'tuition': 'Education',
  };

  /// Classify a parsed UPI result into a category with a confidence score.
  ///
  /// Confidence heuristic:
  ///   0.95 — a merchant/VPA keyword matched (strong signal)
  ///   0.55 — no keyword, but we have a VPA/merchant string to show the user
  ///   0.35 — nothing but an amount and direction (weak, needs review)
  static ClassificationResult classify(UpiParseResult parsed) {
    final haystack = [
      parsed.vpa ?? '',
      parsed.rawText,
      parsed.bankName ?? '',
    ].join(' ').toLowerCase();

    for (final entry in _keywordCategory.entries) {
      if (haystack.contains(entry.key)) {
        return ClassificationResult(entry.value, 0.95);
      }
    }

    // Income with no keyword is usually salary/transfer — mild signal.
    if (parsed.isCredit) {
      return const ClassificationResult('Work', 0.5);
    }

    if ((parsed.vpa != null && parsed.vpa!.isNotEmpty)) {
      return const ClassificationResult('Other', 0.55);
    }

    return const ClassificationResult('Other', 0.35);
  }

  /// Whether a confidence score is high enough to surface as a "ready to add"
  /// suggestion vs. a "needs your attention" one in the inbox.
  static bool isHighConfidence(double confidence) => confidence >= 0.9;

  /// Convert a parsed UPI notification into a pending [Transaction] ready for
  /// the on-device review queue. The category and confidence come from
  /// [classify]; the entry is marked auto-detected + pending.
  ///
  /// [userId] is the current user's id (entries are personal). A local,
  /// time-based id is generated so the pending item can be tracked before it
  /// ever reaches Supabase.
  static Transaction toPendingTransaction(
    UpiParseResult parsed, {
    required String userId,
  }) {
    final result = classify(parsed);
    final label = parsed.vpa ?? parsed.bankName ?? 'UPI transaction';
    return Transaction(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      amount: parsed.amount,
      type: parsed.transactionType, // 'expense' for debit, 'income' for credit
      category: result.category,
      description: label,
      person: label,
      timestamp: parsed.date ?? DateTime.now(),
      source: TransactionSource.autoDetected,
      confidence: result.confidence,
      status: TransactionStatus.pending,
    );
  }
}
