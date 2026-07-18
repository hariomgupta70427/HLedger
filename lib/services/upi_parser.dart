/// UPI SMS Parser — extracts transaction details from bank SMS messages.
///
/// Supports formats from SBI, HDFC, ICICI, Axis, Kotak, Paytm, GPay, PhonePe
/// and generic UPI messages.
class UpiParseResult {
  final double amount;
  final String direction; // 'debit' or 'credit'
  final String? vpa;
  final String? accountLast4;
  final DateTime? date;
  final String? referenceNumber;
  final String? bankName;
  final String rawText;
  final String suggestedCategory;

  const UpiParseResult({
    required this.amount,
    required this.direction,
    this.vpa,
    this.accountLast4,
    this.date,
    this.referenceNumber,
    this.bankName,
    required this.rawText,
    this.suggestedCategory = 'Other',
  });

  bool get isDebit => direction == 'debit';
  bool get isCredit => direction == 'credit';

  /// Returns transaction type for Khaata: 'expense' for debit, 'income' for credit.
  String get transactionType => isDebit ? 'expense' : 'income';

  UpiParseResult copyWith({
    double? amount,
    String? direction,
    String? vpa,
    String? accountLast4,
    DateTime? date,
    String? referenceNumber,
    String? bankName,
    String? rawText,
    String? suggestedCategory,
  }) {
    return UpiParseResult(
      amount: amount ?? this.amount,
      direction: direction ?? this.direction,
      vpa: vpa ?? this.vpa,
      accountLast4: accountLast4 ?? this.accountLast4,
      date: date ?? this.date,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      bankName: bankName ?? this.bankName,
      rawText: rawText ?? this.rawText,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
    );
  }

  @override
  String toString() =>
      'UpiParseResult($direction ₹$amount, vpa=$vpa, acct=$accountLast4, bank=$bankName)';
}

/// Stateless SMS parser with regex-based extraction.
class UpiParser {
  UpiParser._();

  // ── Amount patterns ──
  // Handles: Rs.500, Rs.500.00, Rs 500, Rs,500, INR 500, INR500,
  //          INR 1,200.50, ₹500, ₹ 500, ₹1,200
  static final _amountPatterns = [
    RegExp(r'(?:Rs\.?|INR|₹)\s*(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'(?:Rs\.?|INR|₹)\s*(\d+(?:\.\d{1,2})?)', caseSensitive: false),
  ];

  // ── Direction patterns ──
  static final _debitPatterns = [
    RegExp(r'debit(?:ed)?', caseSensitive: false),
    RegExp(r'(?:sent|paid|spent|transferred|withdrawn|purchase)', caseSensitive: false),
    RegExp(r'Amt\s+Debited', caseSensitive: false),
    RegExp(r'money\s+sent', caseSensitive: false),
  ];

  static final _creditPatterns = [
    RegExp(r'credit(?:ed)?', caseSensitive: false),
    RegExp(r'(?:received|deposited|refund|cashback)', caseSensitive: false),
    RegExp(r'Amt\s+Credited', caseSensitive: false),
    RegExp(r'money\s+received', caseSensitive: false),
  ];

  // ── VPA / UPI ID ──
  static final _vpaPattern = RegExp(
    r'(?:VPA|UPI\s*(?:ID)?|to|from)\s*[:\s]?\s*([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+)',
    caseSensitive: false,
  );

  // ── Account last 4 digits ──
  static final _accountPatterns = [
    RegExp(r'A/[Cc]\s*(?:No\.?\s*)?(?:\*+|[Xx]+|\.+)(\d{4})'),
    RegExp(r'(?:Acct?|Account)\s*(?:\*+|[Xx]+|\.+)(\d{4})', caseSensitive: false),
    RegExp(r'[Xx]{2,}(\d{4})'),
  ];

  // ── Reference / UTR ──
  static final _refPatterns = [
    RegExp(r'(?:Ref(?:\.|erence)?|UTR|UPI\s*Ref|Txn)\s*(?:No\.?\s*)?[:#\s]?\s*(\d{6,20})', caseSensitive: false),
  ];

  // ── Date patterns ──
  static final _datePatterns = [
    // dd-MM-yy or dd/MM/yy or dd-MM-yyyy or dd/MM/yyyy
    RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})'),
  ];

  // ── Bank detection ──
  static final _bankPatterns = {
    'SBI': RegExp(r'SBI|State\s*Bank', caseSensitive: false),
    'HDFC': RegExp(r'HDFC', caseSensitive: false),
    'ICICI': RegExp(r'ICICI', caseSensitive: false),
    'Axis': RegExp(r'Axis', caseSensitive: false),
    'Kotak': RegExp(r'Kotak', caseSensitive: false),
    'Paytm': RegExp(r'Paytm', caseSensitive: false),
    'GPay': RegExp(r'GPay|Google\s*Pay', caseSensitive: false),
    'PhonePe': RegExp(r'PhonePe', caseSensitive: false),
    'BOB': RegExp(r'Bank\s*of\s*Baroda|BOB', caseSensitive: false),
    'PNB': RegExp(r'PNB|Punjab\s*National', caseSensitive: false),
    'Yes Bank': RegExp(r'Yes\s*Bank', caseSensitive: false),
    'IndusInd': RegExp(r'IndusInd', caseSensitive: false),
  };

  // ── VPA → Category mapping ──
  static const _vpaCategoryMap = <String, String>{
    // Food
    'zomato': 'Food',
    'swiggy': 'Food',
    'foodpanda': 'Food',
    'dominos': 'Food',
    'pizzahut': 'Food',
    'mcdonalds': 'Food',
    'dunzo': 'Food',
    'blinkit': 'Food',
    'zepto': 'Food',
    'bigbasket': 'Food',
    // Transport
    'uber': 'Transport',
    'ola': 'Transport',
    'rapido': 'Transport',
    'irctc': 'Transport',
    'metro': 'Transport',
    'petrol': 'Transport',
    'hp': 'Transport',
    'iocl': 'Transport',
    'bpcl': 'Transport',
    // Shopping
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'ajio': 'Shopping',
    'meesho': 'Shopping',
    'nykaa': 'Shopping',
    'snapdeal': 'Shopping',
    // Bills
    'airtel': 'Bills',
    'jio': 'Bills',
    'bsnl': 'Bills',
    'vi': 'Bills',
    'electricity': 'Bills',
    'bescom': 'Bills',
    'tatapower': 'Bills',
    'gas': 'Bills',
    'water': 'Bills',
    'broadband': 'Bills',
    // Entertainment
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'bookmyshow': 'Entertainment',
    'hotstar': 'Entertainment',
    'prime': 'Entertainment',
    'youtube': 'Entertainment',
    'inox': 'Entertainment',
    'pvr': 'Entertainment',
    // Health
    'pharmacy': 'Health',
    'apollo': 'Health',
    'medplus': 'Health',
    'netmeds': 'Health',
    'pharmeasy': 'Health',
    'practo': 'Health',
    'hospital': 'Health',
    // Education
    'coursera': 'Education',
    'udemy': 'Education',
    'unacademy': 'Education',
    'byjus': 'Education',
    'school': 'Education',
    'college': 'Education',
    'university': 'Education',
  };

  /// Parse a raw UPI/bank SMS text and extract transaction details.
  /// Returns null if the SMS cannot be parsed as a UPI transaction.
  static UpiParseResult? parse(String sms) {
    if (sms.trim().isEmpty) return null;

    final text = sms.trim();

    // 1. Extract amount (required — if no amount found, return null)
    final amount = _extractAmount(text);
    if (amount == null || amount <= 0) return null;

    // 2. Detect direction
    final direction = _extractDirection(text);

    // 3. Extract VPA
    final vpa = _extractVpa(text);

    // 4. Extract account last 4 digits
    final accountLast4 = _extractAccount(text);

    // 5. Extract date
    final date = _extractDate(text);

    // 6. Extract reference number
    final referenceNumber = _extractReference(text);

    // 7. Detect bank
    final bankName = _detectBank(text);

    // 8. Suggest category from VPA
    final category = _suggestCategory(vpa);

    return UpiParseResult(
      amount: amount,
      direction: direction,
      vpa: vpa,
      accountLast4: accountLast4,
      date: date,
      referenceNumber: referenceNumber,
      bankName: bankName,
      rawText: text,
      suggestedCategory: category,
    );
  }

  static double? _extractAmount(String text) {
    for (final pattern in _amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final raw = match.group(1);
        if (raw == null) continue;
        // Remove commas and parse
        final cleaned = raw.replaceAll(',', '');
        final value = double.tryParse(cleaned);
        if (value != null && value > 0) return value;
      }
    }
    return null;
  }

  static String _extractDirection(String text) {
    // Check debit patterns
    for (final pattern in _debitPatterns) {
      if (pattern.hasMatch(text)) return 'debit';
    }
    // Check credit patterns
    for (final pattern in _creditPatterns) {
      if (pattern.hasMatch(text)) return 'credit';
    }
    // Default to debit (most UPI SMS are spending)
    return 'debit';
  }

  static String? _extractVpa(String text) {
    final match = _vpaPattern.firstMatch(text);
    if (match != null) {
      final vpa = match.group(1);
      if (vpa != null && vpa.contains('@')) return vpa;
    }
    return null;
  }

  static String? _extractAccount(String text) {
    for (final pattern in _accountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  static DateTime? _extractDate(String text) {
    for (final pattern in _datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final dayStr = match.group(1);
        final monthStr = match.group(2);
        final yearStr = match.group(3);
        if (dayStr == null || monthStr == null || yearStr == null) continue;

        final day = int.tryParse(dayStr);
        final month = int.tryParse(monthStr);
        int? year = int.tryParse(yearStr);

        if (day == null || month == null || year == null) continue;
        if (month < 1 || month > 12 || day < 1 || day > 31) continue;

        // Handle 2-digit year
        if (year < 100) year += 2000;

        try {
          return DateTime(year, month, day);
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  static String? _extractReference(String text) {
    for (final pattern in _refPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  static String? _detectBank(String text) {
    for (final entry in _bankPatterns.entries) {
      if (entry.value.hasMatch(text)) return entry.key;
    }
    return null;
  }

  static String _suggestCategory(String? vpa) {
    if (vpa == null) return 'Other';
    final lower = vpa.toLowerCase();
    for (final entry in _vpaCategoryMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 'Other';
  }
}
