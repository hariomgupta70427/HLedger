import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Balance summary showing Total Income, Total Expense, Net Balance.
class BalanceSummary extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;

  const BalanceSummary({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
  });

  double get netBalance => totalIncome - totalExpense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(child: _SummaryCard(
            label: 'Income',
            amount: totalIncome,
            color: AppColors.green,
            icon: Icons.arrow_downward_rounded,
          )),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(
            label: 'Expense',
            amount: totalExpense,
            color: AppColors.red,
            icon: Icons.arrow_upward_rounded,
          )),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(
            label: 'Net',
            amount: netBalance,
            color: netBalance >= 0 ? AppColors.green : AppColors.red,
            icon: Icons.account_balance_wallet_rounded,
          )),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: amount.abs()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '₹${value.toStringAsFixed(0)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
