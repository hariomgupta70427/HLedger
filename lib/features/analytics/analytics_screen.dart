// AnalyticsScreen — premium, CRED-style spending insights.
//
// Pushed from the insights button in the home screen app bar.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/transaction.dart';
import '../../providers/app_provider.dart';
import 'analytics_category_colors.dart';
import 'widgets/category_legend.dart';
import 'widgets/donut_chart.dart';
import 'widgets/summary_stat_card.dart';
import 'widgets/trend_chart.dart';

/// The period a user can scope the analytics to.
enum AnalyticsRange { thisMonth, lastMonth, allTime }

extension _AnalyticsRangeLabel on AnalyticsRange {
  String get label {
    switch (this) {
      case AnalyticsRange.thisMonth:
        return 'This month';
      case AnalyticsRange.lastMonth:
        return 'Last month';
      case AnalyticsRange.allTime:
        return 'All time';
    }
  }
}

/// Premium analytics / insights screen with charts derived purely from the
/// transactions list. All aggregation is local — nothing is added to
/// [AppProvider].
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsRange _range = AnalyticsRange.thisMonth;

  /// Filters [all] down to the currently selected range.
  List<Transaction> _filter(List<Transaction> all) {
    if (_range == AnalyticsRange.allTime) return all;

    final DateTime now = DateTime.now();
    late final DateTime start;
    late final DateTime end;
    if (_range == AnalyticsRange.thisMonth) {
      start = DateTime(now.year, now.month);
      end = DateTime(now.year, now.month + 1);
    } else {
      start = DateTime(now.year, now.month - 1);
      end = DateTime(now.year, now.month);
    }
    return all
        .where((t) => !t.timestamp.isBefore(start) && t.timestamp.isBefore(end))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Transaction> all =
        Provider.of<AppProvider>(context).transactions;
    final List<Transaction> txns = _filter(all);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildRangeSelector()),
            if (txns.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverToBoxAdapter(child: _buildContent(txns)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
      child: Row(
        children: [
          // Pushed as a full-screen route with no AppBar, so without this the
          // only way back is the system gesture.
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insights',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Where your money goes',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, duration: 300.ms);
  }

  Widget _buildRangeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            for (final range in AnalyticsRange.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _range = range),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _range == range
                          ? AppColors.accent
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      range.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _range == range
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: AppColors.textSecondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No data for ${_range.label.toLowerCase()}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add some transactions and your spending\ninsights will show up here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildContent(List<Transaction> txns) {
    // ── Local aggregation (pure; nothing added to AppProvider) ──
    double income = 0;
    double expense = 0;
    final Map<String, double> byCategory = <String, double>{};
    for (final t in txns) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
        byCategory.update(
          t.category,
          (v) => v + t.amount,
          ifAbsent: () => t.amount,
        );
      }
    }
    final double net = income - expense;

    // Sorted category slices for the donut + legend + ranked list.
    final List<MapEntry<String, double>> sortedCats = byCategory.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final List<CategorySlice> slices = [
      for (final e in sortedCats)
        CategorySlice(
          category: e.key,
          amount: e.value,
          color: AnalyticsCategoryColors.of(e.key),
          fraction: expense > 0 ? e.value / expense : 0,
        ),
    ];

    final List<TrendPoint> trend = _buildTrend(txns);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow(income, expense, net),
          const SizedBox(height: 24),
          if (slices.isNotEmpty) ...[
            _sectionTitle('Spending by category'),
            const SizedBox(height: 12),
            _card(
              child: Column(
                children: [
                  DonutChart(slices: slices, total: expense),
                  const SizedBox(height: 16),
                  CategoryLegend(slices: slices),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          _sectionTitle('Income vs expense'),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _trendLegend(),
                const SizedBox(height: 12),
                TrendChart(points: trend),
              ],
            ),
          ),
          if (slices.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Top spending categories'),
            const SizedBox(height: 12),
            _buildTopCategories(slices),
          ],
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildSummaryRow(double income, double expense, double net) {
    return Row(
      children: [
        Expanded(
          child: SummaryStatCard(
            icon: Icons.arrow_downward_rounded,
            accentColor: AppColors.green,
            label: 'Income',
            value: income,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SummaryStatCard(
            icon: Icons.arrow_upward_rounded,
            accentColor: AppColors.red,
            label: 'Spent',
            value: expense,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SummaryStatCard(
            icon: Icons.account_balance_wallet_rounded,
            accentColor: net >= 0 ? AppColors.accent : AppColors.red,
            label: 'Net balance',
            value: net,
          ),
        ),
      ],
    );
  }

  Widget _buildTopCategories(List<CategorySlice> slices) {
    final List<CategorySlice> top = slices.take(5).toList();
    return _card(
      child: Column(
        children: [
          for (int i = 0; i < top.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _CategoryProgressRow(slice: top[i]),
          ],
        ],
      ),
    );
  }

  Widget _trendLegend() {
    return Row(
      children: [
        _legendDot(AppColors.green, 'Income'),
        const SizedBox(width: 16),
        _legendDot(AppColors.red, 'Expense'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  /// Buckets transactions into time points for the trend chart. Month views
  /// group by day-of-month; all-time groups by calendar month.
  List<TrendPoint> _buildTrend(List<Transaction> txns) {
    if (txns.isEmpty) return const [];

    if (_range == AnalyticsRange.allTime) {
      // Group by year-month across the full range present in the data.
      final Map<String, List<double>> buckets = <String, List<double>>{};
      final List<DateTime> months = <DateTime>[];
      DateTime? minDate;
      DateTime? maxDate;
      for (final t in txns) {
        if (minDate == null || t.timestamp.isBefore(minDate)) {
          minDate = t.timestamp;
        }
        if (maxDate == null || t.timestamp.isAfter(maxDate)) {
          maxDate = t.timestamp;
        }
      }
      DateTime cursor = DateTime(minDate!.year, minDate.month);
      final DateTime last = DateTime(maxDate!.year, maxDate.month);
      while (!cursor.isAfter(last)) {
        final String key = '${cursor.year}-${cursor.month}';
        buckets[key] = <double>[0, 0];
        months.add(cursor);
        cursor = DateTime(cursor.year, cursor.month + 1);
      }
      for (final t in txns) {
        final String key = '${t.timestamp.year}-${t.timestamp.month}';
        final List<double>? b = buckets[key];
        if (b == null) continue;
        if (t.isIncome) {
          b[0] += t.amount;
        } else {
          b[1] += t.amount;
        }
      }
      const List<String> monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return [
        for (final m in months)
          TrendPoint(
            label: monthNames[m.month - 1],
            income: buckets['${m.year}-${m.month}']![0],
            expense: buckets['${m.year}-${m.month}']![1],
          ),
      ];
    }

    // Month views: one bucket per day of the target month.
    final DateTime now = DateTime.now();
    final int year =
        _range == AnalyticsRange.thisMonth ? now.year : now.month == 1 ? now.year - 1 : now.year;
    final int month = _range == AnalyticsRange.thisMonth
        ? now.month
        : now.month == 1
            ? 12
            : now.month - 1;
    final int daysInMonth = DateTime(year, month + 1, 0).day;

    final List<double> incomeByDay = List<double>.filled(daysInMonth, 0);
    final List<double> expenseByDay = List<double>.filled(daysInMonth, 0);
    for (final t in txns) {
      final int dayIndex = t.timestamp.day - 1;
      if (dayIndex < 0 || dayIndex >= daysInMonth) continue;
      if (t.isIncome) {
        incomeByDay[dayIndex] += t.amount;
      } else {
        expenseByDay[dayIndex] += t.amount;
      }
    }
    return [
      for (int d = 0; d < daysInMonth; d++)
        TrendPoint(
          label: '${d + 1}',
          income: incomeByDay[d],
          expense: expenseByDay[d],
        ),
    ];
  }
}

/// A ranked category row with a color-tinted progress bar showing its share of
/// total spend.
class _CategoryProgressRow extends StatelessWidget {
  final CategorySlice slice;

  const _CategoryProgressRow({required this.slice});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                slice.category,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '₹${slice.amount.toStringAsFixed(0)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(
                height: 8,
                color: AppColors.surface2,
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: slice.fraction.clamp(0, 1)),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) {
                  return FractionallySizedBox(
                    widthFactor: value == 0 ? 0.02 : value,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: slice.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
