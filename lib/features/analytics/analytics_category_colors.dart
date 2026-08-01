import 'package:flutter/material.dart';

/// Maps each transaction category to a distinct, premium-feeling color used
/// across the analytics charts and legends.
///
/// Colors are hand-picked to sit well on the dark [AppColors.background] and
/// to stay visually distinct from one another in a pie chart legend.
class AnalyticsCategoryColors {
  AnalyticsCategoryColors._();

  /// The canonical per-category palette. Keys match the category strings used
  /// in [Transaction.category].
  static const Map<String, Color> _palette = <String, Color>{
    'Food': Color(0xFFFF6B6B),
    'Transport': Color(0xFF4D96FF),
    'Shopping': Color(0xFFFFA94D),
    'Bills': Color(0xFF9775FA),
    'Entertainment': Color(0xFFFF87C5),
    'Health': Color(0xFF00D68F),
    'Education': Color(0xFF38D9A9),
    'Work': Color(0xFF6C63FF),
    'Friends & Family': Color(0xFFFFD43B),
    'Other': Color(0xFF8B8FA8),
  };

  /// Fallback palette for any category not present in [_palette] (e.g. legacy
  /// or user-created categories). Chosen deterministically by hashing the name
  /// so the same category always gets the same color.
  static const List<Color> _fallback = <Color>[
    Color(0xFF63E6BE),
    Color(0xFF748FFC),
    Color(0xFFFFC078),
    Color(0xFFDA77F2),
    Color(0xFF66D9E8),
    Color(0xFFA9E34B),
  ];

  /// Returns a stable color for [category].
  static Color of(String category) {
    final Color? direct = _palette[category];
    if (direct != null) return direct;
    // Deterministic fallback based on the category name.
    final int index = category.hashCode.abs() % _fallback.length;
    return _fallback[index];
  }
}
