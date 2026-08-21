/// Bank and UPI SMS parser.
///
/// Extraction is deliberately conservative. An SMS that does not state both an
/// amount and an unambiguous direction is rejected rather than guessed at: a
/// guessed direction books a phantom entry in the user's ledger, which is worse
/// than missing the transaction entirely.
///
/// Covers UPI, card, ATM, NEFT/IMPS/RTGS, mandate and EMI alerts from the major
/// Indian banks and PSPs.
class UpiParseResult {
  final double amount;
  final String direction; // 'debit' or 'credit'
  final String? vpa;
  final String? merchant;
  final String? accountLast4;
  final DateTime? date;
  final String? referenceNumber;
  final String? bankName;

  /// Payment rail, when the message names one: `upi`, `card`, `atm`, `neft`,
  /// `imps`, `rtgs`, `mandate`, `emi`, `wallet`.
  final String? instrument;

  /// Whether the SMS came from a recognised institutional sender. False means
  /// the message parsed but its origin could not be vouched for, so downstream
  /// confidence is reduced rather than the entry being dropped.
  final bool senderVerified;

  final String rawText;
  final String suggestedCategory;

  const UpiParseResult({
    required this.amount,
    required this.direction,
    this.vpa,
    this.merchant,
    this.accountLast4,
    this.date,
    this.referenceNumber,
    this.bankName,
    this.instrument,
    this.senderVerified = false,
    required this.rawText,
    this.suggestedCategory = 'Other',
  });

  bool get isDebit => direction == 'debit';
  bool get isCredit => direction == 'credit';

  /// Returns transaction type for Khaata: 'expense' for debit, 'income' for credit.
  String get transactionType => isDebit ? 'expense' : 'income';

  /// Best human-readable counterparty available, most specific first.
  String get displayLabel {
    if (merchant != null && merchant!.isNotEmpty) return merchant!;
    if (vpa != null && vpa!.isNotEmpty) return vpa!;
    if (accountLast4 != null) {
      return bankName != null ? '$bankName ••$accountLast4' : '••$accountLast4';
    }
    return bankName ?? 'Transaction';
  }

  /// Stable identity for a transaction across duplicate deliveries and across
  /// detection sources. The reference number is the bank's own idempotency key;
  /// when absent, fall back to the fields that together make a collision
  /// improbable within a single day.
  String get dedupeKey {
    if (referenceNumber != null && referenceNumber!.isNotEmpty) {
      return 'ref:$referenceNumber';
    }
    final day = date != null
        ? '${date!.year}-${date!.month}-${date!.day}'
        : 'nodate';
    return 'syn:${amount.toStringAsFixed(2)}|$direction|'
        '${accountLast4 ?? ''}|${vpa ?? merchant ?? ''}|$day';
  }

  UpiParseResult copyWith({
    double? amount,
    String? direction,
    String? vpa,
    String? merchant,
    String? accountLast4,
    DateTime? date,
    String? referenceNumber,
    String? bankName,
    String? instrument,
    bool? senderVerified,
    String? rawText,
    String? suggestedCategory,
  }) {
    return UpiParseResult(
      amount: amount ?? this.amount,
      direction: direction ?? this.direction,
      vpa: vpa ?? this.vpa,
      merchant: merchant ?? this.merchant,
      accountLast4: accountLast4 ?? this.accountLast4,
      date: date ?? this.date,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      bankName: bankName ?? this.bankName,
      instrument: instrument ?? this.instrument,
      senderVerified: senderVerified ?? this.senderVerified,
      rawText: rawText ?? this.rawText,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
    );
  }

  @override
  String toString() =>
      'UpiParseResult($direction ₹$amount, label=$displayLabel, '
      'rail=$instrument, ref=$referenceNumber, verified=$senderVerified)';
}

/// Stateless SMS parser with regex-based extraction.
class UpiParser {
  UpiParser._();

  // ── Amount ──
  // One ordered alternation, not two separate patterns: a grouped form must be
  // tried and fail before the plain form is attempted, otherwise a leading
  // `\d{1,3}` matches the first three digits of an ungrouped amount and the
  // remainder is silently discarded (Rs.1234.56 → 123).
  static final _amountPatterns = [
    RegExp(
      r'(?<![A-Za-z])(?:rs|inr|₹)[.:\s]?\s*'
      r'(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?<![A-Za-z])(?:amount|amt)[.:\s]?\s*'
      r'(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
  ];

  /// Figures qualified by these words describe an account balance or a limit,
  /// never the transaction itself.
  ///
  /// The trailing filler matters: real alerts write "Avl bal is Rs 500" and
  /// "balance of Rs 500", so anchoring straight to the amount missed both and
  /// booked the balance as a spend.
  static final _balanceContext = RegExp(
    r'(?:avl|avail(?:able)?|clos(?:ing)?|cur(?:rent)?|bal(?:ance)?|'
    r'limit|outstanding|o/s)\W*(?:is|of|are|now|:)?\W*$',
    caseSensitive: false,
  );

  // ── Direction ──
  // Anchored on past participles so that "credit card" cannot be read as a
  // credit. Whichever marker sits closest to the start of the message wins,
  // which keeps "Salary credited … transferred by ACME" an income entry.
  //
  // Every marker names a *settled* action. 'cashback' used to sit among the
  // credit markers and was the single worst false positive in the app: "your
  // next 5 payments come with cashback of Rs 20" booked ₹20 of income. A real
  // cashback still parses, because a real one says it was *credited*.
  static final _debitMarkers = RegExp(
    r'\b(?:debited|debit|withdrawn|withdrawal|spent|paid|sent|'
    r'purchase[ds]?|deducted|dr)\b',
    caseSensitive: false,
  );

  static final _creditMarkers = RegExp(
    r'\b(?:credited|deposited|received|refund(?:ed)?|'
    r'reversed|cr)\b'
    // Wallet and account top-ups. A received payment into a wallet is very often
    // worded as "added to your balance" with no settlement participle anywhere,
    // which used to make every incoming wallet payment undetectable. Scoped to
    // "your <thing>" so a promotional "added to cart" cannot match.
    r'|\badded\s+to\s+your\b'
    r'|\btransferred\s+to\s+your\b'
    r'|\bmoney\s+in\b',
    caseSensitive: false,
  );

  /// Messages that carry an amount but describe no completed movement of money.
  /// Rejecting these is what keeps OTPs out of the ledger.
  static final _nonTransactional = RegExp(
    r'(?:\bOTP\b|one[\s-]?time\s*password|do\s*not\s*share|'
    r'never\s*share|\bwill\s*be\s*(?:debited|deducted|credited)|'
    r'requesting|has\s*requested|collect\s*request|payment\s*request|'
    r'\bfailed\b|declined|unsuccessful|not\s*processed|'
    r'\bquote\b|\boffer\b|apply\s*now|click\s*here|\bwin\b|'
    r'\bdue\s*(?:on|by)\b|scheduled\s*(?:for|on)|\bEMI\s*reminder)',
    caseSensitive: false,
  );

  /// Marketing copy that quotes a figure it is not actually moving.
  ///
  /// The largest false-positive class in practice, and the one sender trust
  /// cannot filter: a bank's promotional alert arrives from the bank's own
  /// header and its own app. What separates it from a real alert is that it
  /// describes money conditionally — an offer, a cap, an eligibility, something
  /// a future payment "comes with" — never a movement that has settled.
  ///
  /// Kept deliberately clear of words a genuine alert might also use. 'voucher'
  /// and 'download' were considered and rejected for exactly that reason: real
  /// debits happen at voucher merchants, and real alerts do append app prompts.
  static final _promotional = RegExp(
    r'(?:\bup\s?to\b|\bupto\b|\bT&Cs?\b|'
    r'terms\s*(?:and|&)\s*conditions|'
    r'\bnext\s+\d+\s|\bon\s+every\b|\bevery\s+(?:transaction|payment|txn)\b|'
    r'\bflat\s+\d|\d+\s*%\s*off\b|'
    r'\blimited\s+(?:time|period|offer)|\bhurry\b|\bgrab\b|'
    r'\bcongratulations\b|\beligible\s+(?:for|to)\b|\bclaim\b|'
    r'\bwill\s+(?:get|receive|earn|win)\b|\bcomes?\s+with\b|'
    r'\brefer\s*(?:and|&)\s*earn\b|\bstands?\s+to\s+(?:win|earn)\b|'
    r'\bno\s*cost\s*emi\b|\binterest[\s-]?free\b|\bcoupon\s*code\b)',
    caseSensitive: false,
  );

  // ── VPA / UPI ID ──
  static final _vpaPattern = RegExp(
    r'(?:VPA|UPI\s*(?:ID)?|to|from)\s*[:\s]?\s*([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+)',
    caseSensitive: false,
  );

  // ── Merchant / counterparty name ──
  // Bank SMS names the other party after a small set of prepositions. The
  // capture stops at sentence punctuation so trailing clauses are not absorbed.
  static final _merchantPatterns = [
    RegExp(
      r'(?:\bat\s+)([A-Z][A-Za-z0-9&\x27.\- ]{2,40}?)'
      r'(?=\s*(?:on|for|via|dated|\.|,|;|$))',
    ),
    RegExp(
      r'(?:trf\s+to|transfer(?:red)?\s+to|paid\s+to|sent\s+to|'
      r'received\s+from|credited\s+by|from)\s+'
      r'([A-Z][A-Za-z0-9&\x27.\- ]{2,40}?)'
      r'(?=\s*(?:on|for|via|ref|dated|\.|,|;|$))',
      caseSensitive: false,
    ),
    RegExp(r'(?:Info|Desc|Remarks?)\s*[:\-]\s*([^\r\n.;]{2,40})',
        caseSensitive: false),
  ];

  // ── Account last 4 digits ──
  static final _accountPatterns = [
    RegExp(r'A/[Cc]\s*(?:No\.?\s*)?(?:\*+|[Xx]+|\.+)(\d{4})'),
    RegExp(r'(?:Acct?|Account)\s*(?:\*+|[Xx]+|\.+)(\d{4})', caseSensitive: false),
    RegExp(r'(?:card)\s*(?:no\.?\s*)?(?:\*+|[Xx]+|\.+)(\d{4})',
        caseSensitive: false),
    RegExp(r'[Xx]{2,}(\d{4})'),
  ];

  // ── Reference / UTR ──
  static final _refPatterns = [
    RegExp(
      r'(?:UTR|RRN|UPI\s*Ref(?:erence)?(?:\s*No\.?)?|Ref(?:\.|erence)?(?:\s*No\.?)?|'
      r'Txn\s*(?:No\.?|ID)?|Transaction\s*(?:No\.?|ID))\s*[:#\s]?\s*([A-Za-z0-9]{6,25})',
      caseSensitive: false,
    ),
  ];

  // ── Payment rail ──
  static final _instrumentPatterns = {
    'upi': RegExp(r'\bUPI\b|@[a-z]{2,}', caseSensitive: false),
    'atm': RegExp(r'\bATM\b|cash\s*withdrawal', caseSensitive: false),
    'card': RegExp(r'\b(?:debit|credit)\s*card\b|\bPOS\b|card\s*ending',
        caseSensitive: false),
    'neft': RegExp(r'\bNEFT\b', caseSensitive: false),
    'imps': RegExp(r'\bIMPS\b', caseSensitive: false),
    'rtgs': RegExp(r'\bRTGS\b', caseSensitive: false),
    'mandate': RegExp(r'\b(?:mandate|auto\s*pay|autopay|standing\s*instruction|\bSI\b)',
        caseSensitive: false),
    'emi': RegExp(r'\bEMI\b', caseSensitive: false),
    'wallet': RegExp(r'\bwallet\b', caseSensitive: false),
  };

  // ── Date ──
  static const _monthNames = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  // dd-MMM-yy is the most common bank format and was previously unhandled.
  static final _monthNameDate = RegExp(
    r'(\d{1,2})[-/\s]([A-Za-z]{3})[A-Za-z]*[-/\s](\d{2,4})',
    caseSensitive: false,
  );

  static final _numericDate =
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})');

  /// Time of day, when present. Without it every entry lands at midnight, which
  /// collapses the timestamp axis that duplicate detection depends on.
  static final _timePattern = RegExp(
    r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?',
    caseSensitive: false,
  );

  // ── Institutional senders ──
  // Indian transactional headers arrive as VM-HDFCBK, AD-SBIINB, JD-ICICIB and
  // similar, optionally with a DLT suffix. A purely numeric origin is a person,
  // not a bank.
  static final _senderTokens = RegExp(
    r'HDFC|SBI|ICICI|AXIS|KOTAK|PNB|BOB|BARB|CANARA|CNRB|UNION|UBIN|IDBI|'
    r'INDUS|IDFC|YESBNK|YESB|RBL|FEDERAL|FDRL|BOI|CBIN|IOB|UCO|PAYTM|'
    r'PHONPE|PHONEPE|GPAY|GOOGLE|BHIM|NPCI|AMZN|AIRTEL|JIO|SLICE|CRED|'
    r'ONECRD|AUBANK|BANDHAN|DBS|HSBC|SCB|CITI|AMEX|EQUITAS|JANA|ESAF|'
    r'FINO|AIRTELB|POSTBK|IPPB|BANK|UPI',
    caseSensitive: false,
  );

  static final _numericSender = RegExp(r'^\+?\d[\d\s\-]{5,}$');

  // ── VPA / merchant → Category ──
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
    'instamart': 'Food',
    'restaurant': 'Food',
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
    'fastag': 'Transport',
    'redbus': 'Transport',
    // Shopping
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'ajio': 'Shopping',
    'meesho': 'Shopping',
    'nykaa': 'Shopping',
    'snapdeal': 'Shopping',
    'decathlon': 'Shopping',
    // Bills
    'airtel': 'Bills',
    'jio': 'Bills',
    'bsnl': 'Bills',
    'vi': 'Bills',
    'electricity': 'Bills',
    'bescom': 'Bills',
    'tatapower': 'Bills',
    'adani': 'Bills',
    'gas': 'Bills',
    'water': 'Bills',
    'broadband': 'Bills',
    'insurance': 'Bills',
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
    'tata1mg': 'Health',
    // Education
    'coursera': 'Education',
    'udemy': 'Education',
    'unacademy': 'Education',
    'byjus': 'Education',
    'school': 'Education',
    'college': 'Education',
    'university': 'Education',
  };

  /// Whether an SMS origin is a plausible institutional sender.
  ///
  /// A numeric origin is rejected outright — that is a person messaging the
  /// user, and parsing it would mine private conversations for figures.
  static bool isTrustedSender(String? address) {
    if (address == null) return false;
    final trimmed = address.trim();
    if (trimmed.isEmpty) return false;
    if (_numericSender.hasMatch(trimmed)) return false;
    return _senderTokens.hasMatch(trimmed);
  }

  /// Parse a raw bank or UPI SMS. Returns null when the message is not a
  /// completed transaction, or when its direction cannot be established.
  ///
  /// [sender] is the SMS originating address. When supplied and numeric, the
  /// message is discarded unparsed; when supplied and recognised, the result is
  /// marked [UpiParseResult.senderVerified].
  static UpiParseResult? parse(String sms, {String? sender}) {
    if (sms.trim().isEmpty) return null;

    final text = sms.trim();

    // A person-to-person SMS is never a bank alert. Discard before parsing so
    // private message bodies are not scanned for figures at all.
    if (sender != null && _numericSender.hasMatch(sender.trim())) return null;

    if (_nonTransactional.hasMatch(text)) return null;
    if (_promotional.hasMatch(text)) return null;

    final amount = _extractAmount(text);
    if (amount == null || amount <= 0) return null;

    final direction = _extractDirection(text);
    if (direction == null) return null;

    final vpa = _extractVpa(text);
    final merchant = _extractMerchant(text);
    final accountLast4 = _extractAccount(text);
    final date = _extractDateTime(text);
    final referenceNumber = _extractReference(text);
    final bankName = _detectBank(text, sender);
    final instrument = _detectInstrument(text);
    final category = _suggestCategory([merchant, vpa]);

    return UpiParseResult(
      amount: amount,
      direction: direction,
      vpa: vpa,
      merchant: merchant,
      accountLast4: accountLast4,
      date: date,
      referenceNumber: referenceNumber,
      bankName: bankName,
      instrument: instrument,
      senderVerified: isTrustedSender(sender),
      rawText: text,
      suggestedCategory: category,
    );
  }

  /// First monetary figure that is not qualified as a balance or a limit.
  ///
  /// Returning null when every figure is balance-qualified is what rejects
  /// standalone balance alerts instead of booking the balance as a spend.
  static double? _extractAmount(String text) {
    for (final pattern in _amountPatterns) {
      for (final match in pattern.allMatches(text)) {
        final lead = text.substring(
          match.start > 24 ? match.start - 24 : 0,
          match.start,
        );
        if (_balanceContext.hasMatch(lead)) continue;

        final raw = match.group(1);
        if (raw == null) continue;
        final value = double.tryParse(raw.replaceAll(',', ''));
        if (value != null && value > 0) return value;
      }
    }
    return null;
  }

  /// Direction, or null when the message states neither.
  ///
  /// Never defaults: an unqualified amount used to be booked as a debit, which
  /// turned every stray figure into a fabricated expense.
  static String? _extractDirection(String text) {
    final debit = _debitMarkers.firstMatch(text);
    final credit = _creditMarkers.firstMatch(text);

    if (debit == null && credit == null) return null;
    if (credit == null) return 'debit';
    if (debit == null) return 'credit';
    return debit.start <= credit.start ? 'debit' : 'credit';
  }

  static String? _extractVpa(String text) {
    final match = _vpaPattern.firstMatch(text);
    var vpa = match?.group(1);
    if (vpa == null || !vpa.contains('@')) return null;

    // The handle character class admits '.', '_' and '-', so a VPA at the end
    // of a sentence absorbs the terminating punctuation.
    vpa = vpa.replaceAll(RegExp(r'[._-]+$'), '');
    final parts = vpa.split('@');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
    return vpa;
  }

  static String? _extractMerchant(String text) {
    for (final pattern in _merchantPatterns) {
      final raw = pattern.firstMatch(text)?.group(1)?.trim();
      if (raw == null || raw.length < 3) continue;

      final cleaned = raw.replaceAll(RegExp(r'\s{2,}'), ' ');
      // A bare VPA is already carried separately, and an all-digit capture is
      // a reference number the pattern over-reached into.
      if (cleaned.contains('@')) continue;
      if (RegExp(r'^\d+$').hasMatch(cleaned)) continue;
      return cleaned;
    }
    return null;
  }

  static String? _extractAccount(String text) {
    for (final pattern in _accountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static DateTime? _extractDateTime(String text) {
    final date = _extractDate(text);
    if (date == null) return null;

    final time = _timePattern.firstMatch(text);
    if (time == null) return date;

    var hour = int.tryParse(time.group(1) ?? '');
    final minute = int.tryParse(time.group(2) ?? '');
    final second = int.tryParse(time.group(3) ?? '0') ?? 0;
    final meridiem = time.group(4)?.toLowerCase();

    if (hour == null || minute == null) return date;
    if (minute > 59 || second > 59) return date;

    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;
    if (hour > 23) return date;

    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  static DateTime? _extractDate(String text) {
    final named = _monthNameDate.firstMatch(text);
    if (named != null) {
      final day = int.tryParse(named.group(1) ?? '');
      final month = _monthNames[named.group(2)?.toLowerCase()];
      final year = _normaliseYear(int.tryParse(named.group(3) ?? ''));
      final built = _buildDate(year, month, day);
      if (built != null) return built;
    }

    final numeric = _numericDate.firstMatch(text);
    if (numeric != null) {
      final day = int.tryParse(numeric.group(1) ?? '');
      final month = int.tryParse(numeric.group(2) ?? '');
      final year = _normaliseYear(int.tryParse(numeric.group(3) ?? ''));
      final built = _buildDate(year, month, day);
      if (built != null) return built;
    }

    return null;
  }

  static int? _normaliseYear(int? year) {
    if (year == null) return null;
    return year < 100 ? year + 2000 : year;
  }

  static DateTime? _buildDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final built = DateTime(year, month, day);
    // Rejects impossible days such as 31-02, which DateTime would roll forward.
    if (built.month != month || built.day != day) return null;
    return built;
  }

  static String? _extractReference(String text) {
    for (final pattern in _refPatterns) {
      final raw = pattern.firstMatch(text)?.group(1);
      // A purely alphabetic capture is a word the pattern ran into, not a UTR.
      if (raw != null && RegExp(r'\d').hasMatch(raw)) return raw;
    }
    return null;
  }

  static String? _detectInstrument(String text) {
    for (final entry in _instrumentPatterns.entries) {
      if (entry.value.hasMatch(text)) return entry.key;
    }
    return null;
  }

  static final _bankPatterns = {
    'SBI': RegExp(r'\bSBI\b|State\s*Bank|SBIINB|SBIUPI', caseSensitive: false),
    'HDFC': RegExp(r'HDFC', caseSensitive: false),
    'ICICI': RegExp(r'ICICI', caseSensitive: false),
    'Axis': RegExp(r'\bAxis\b', caseSensitive: false),
    'Kotak': RegExp(r'Kotak', caseSensitive: false),
    'Paytm': RegExp(r'Paytm', caseSensitive: false),
    'GPay': RegExp(r'GPay|Google\s*Pay', caseSensitive: false),
    'PhonePe': RegExp(r'PhonePe|PHONPE', caseSensitive: false),
    'BOB': RegExp(r'Bank\s*of\s*Baroda|\bBOB\b|BARB', caseSensitive: false),
    'PNB': RegExp(r'\bPNB\b|Punjab\s*National', caseSensitive: false),
    'Canara': RegExp(r'Canara|CNRB', caseSensitive: false),
    'Union Bank': RegExp(r'Union\s*Bank|UBIN', caseSensitive: false),
    'IDFC': RegExp(r'IDFC', caseSensitive: false),
    'Yes Bank': RegExp(r'Yes\s*Bank|YESBNK', caseSensitive: false),
    'IndusInd': RegExp(r'IndusInd|INDUS', caseSensitive: false),
    'Federal': RegExp(r'Federal\s*Bank|FDRL', caseSensitive: false),
    'RBL': RegExp(r'\bRBL\b', caseSensitive: false),
    'IDBI': RegExp(r'\bIDBI\b', caseSensitive: false),
  };

  /// Bank identity, preferring the sender header over the body: the header is
  /// assigned by the operator and cannot be spoofed by message content.
  static String? _detectBank(String text, String? sender) {
    if (sender != null && sender.trim().isNotEmpty) {
      for (final entry in _bankPatterns.entries) {
        if (entry.value.hasMatch(sender)) return entry.key;
      }
    }
    for (final entry in _bankPatterns.entries) {
      if (entry.value.hasMatch(text)) return entry.key;
    }
    return null;
  }

  /// Category hint from the counterparty only.
  ///
  /// Matching is scoped to the merchant and VPA rather than the whole message
  /// body because several keys are short enough to appear inside ordinary words
  /// ('vi' inside 'received', 'hp' inside 'shp').
  static String _suggestCategory(List<String?> labels) {
    for (final label in labels) {
      if (label == null || label.isEmpty) continue;
      final lower = label.toLowerCase();
      final tokens = lower.split(RegExp(r'[^a-z0-9]+'))
        ..removeWhere((t) => t.isEmpty);

      for (final entry in _vpaCategoryMap.entries) {
        final key = entry.key;
        final matched = key.length >= 4
            ? lower.contains(key)
            : tokens.contains(key);
        if (matched) return entry.value;
      }
    }
    return 'Other';
  }
}
