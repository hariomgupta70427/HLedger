import 'package:intl/intl.dart';

/// Rupee formatting for everything the user reads.
///
/// Indian grouping is not the Western three-digit rule — it is `##,##,###`, so
/// twelve lakh fifty thousand reads `₹12,50,000` and not `₹1,250,000`. Getting
/// this wrong makes every large figure momentarily unreadable to the only
/// audience this app has.
///
/// The sign is placed before the symbol (`-₹4,500`) rather than inside it,
/// which is how a negative amount is written in practice.
class Money {
  Money._();

  static final NumberFormat _grouped = NumberFormat.decimalPattern('en_IN');
  static final NumberFormat _oneDecimal = NumberFormat('#,##0.#', 'en_IN');

  /// `₹12,50,000` — whole rupees. Paise are noise at dashboard scale.
  static String rupees(num amount) {
    final rounded = amount.abs().round();
    final sign = amount < 0 && rounded != 0 ? '-' : '';
    return '$sign₹${_grouped.format(rounded)}';
  }

  /// `+₹4,500` / `-₹4,500` — for figures whose direction is the point.
  static String signed(num amount) {
    if (amount > 0) return '+${rupees(amount)}';
    return rupees(amount);
  }

  /// `₹12.5L` — for a space too narrow to hold the grouped form.
  ///
  /// Scaled in lakh and crore, because a reader who thinks in lakh cannot parse
  /// `₹1.3M` at a glance.
  static String compact(num amount) {
    final value = amount.abs();
    final sign = amount < 0 && value.round() != 0 ? '-' : '';

    if (value >= 10000000) return '$sign₹${_oneDecimal.format(value / 10000000)}Cr';
    if (value >= 100000) return '$sign₹${_oneDecimal.format(value / 100000)}L';
    if (value >= 10000) return '$sign₹${_oneDecimal.format(value / 1000)}K';
    return '$sign₹${_grouped.format(value.round())}';
  }
}
