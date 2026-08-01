import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// One slice of the category donut chart.
class CategorySlice {
  final String category;
  final double amount;
  final Color color;

  /// Fraction of the total (0.0–1.0).
  final double fraction;

  const CategorySlice({
    required this.category,
    required this.amount,
    required this.color,
    required this.fraction,
  });
}

/// A donut/pie chart of category spending with a centered total in the hole.
class DonutChart extends StatelessWidget {
  final List<CategorySlice> slices;

  /// Total spent, shown in the center of the donut.
  final double total;

  const DonutChart({
    super.key,
    required this.slices,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 62,
              startDegreeOffset: -90,
              sections: [
                for (final slice in slices)
                  PieChartSectionData(
                    value: slice.amount,
                    color: slice.color,
                    radius: 26,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total spent',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
