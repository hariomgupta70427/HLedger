import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// One time bucket of income vs expense totals.
class TrendPoint {
  /// Short axis label, e.g. "5" (day-of-month) or "Jan".
  final String label;
  final double income;
  final double expense;

  const TrendPoint({
    required this.label,
    required this.income,
    required this.expense,
  });
}

/// A grouped bar chart comparing income and expense across time buckets.
class TrendChart extends StatelessWidget {
  final List<TrendPoint> points;

  const TrendChart({super.key, required this.points});

  double get _maxY {
    double max = 0;
    for (final p in points) {
      if (p.income > max) max = p.income;
      if (p.expense > max) max = p.expense;
    }
    // Add headroom so bars never touch the top; never zero (avoids /0 in grid).
    return max <= 0 ? 100 : max * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    // Only render a subset of axis labels when there are many buckets, to
    // avoid an unreadable, crowded axis.
    final int labelStride = (points.length / 8).ceil().clamp(1, points.length);
    final double maxY = _maxY;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface2,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final bool isIncome = rodIndex == 0;
                return BarTooltipItem(
                  '${isIncome ? 'Income' : 'Expense'}\n₹${rod.toY.toStringAsFixed(0)}',
                  GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isIncome ? AppColors.green : AppColors.red,
                  ),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final int index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  if (index % labelStride != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      points[index].label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 3,
                barRods: [
                  BarChartRodData(
                    toY: points[i].income,
                    color: AppColors.green,
                    width: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  BarChartRodData(
                    toY: points[i].expense,
                    color: AppColors.red,
                    width: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
