import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../services/supabase_service.dart';
import '../../shared/widgets/transaction_card.dart';
import '../../main.dart';

/// Dashboard/Home screen — the landing page with analytics.
class HomeScreen extends StatefulWidget {
  /// Callback to navigate to a specific tab index.
  final void Function(int tabIndex)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _quotes = [
    '"Beware of little expenses; a small leak will sink a great ship." — Benjamin Franklin',
    '"Do not save what is left after spending, spend what is left after saving." — Warren Buffett',
    '"A budget tells your money where to go, instead of wondering where it went." — Dave Ramsey',
    '"Money is only a tool. It will take you wherever you wish, but it will not replace you as the driver." — Ayn Rand',
    '"Financial freedom is available to those who learn about it and work for it." — Robert Kiyosaki',
    '"The habit of saving is itself an education." — George S. Clason',
    '"Paise pedh pe nahi ugte, budget bana ke rakh." — Desi Wisdom 🌿',
  ];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _quoteOfTheDay {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return _quotes[dayOfYear % _quotes.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App bar
                SliverToBoxAdapter(child: _buildAppBar(context)),
                // Greeting card
                SliverToBoxAdapter(child: _buildGreetingCard()),
                // Quick stats
                SliverToBoxAdapter(child: _buildQuickStats(provider)),
                // Weekly chart
                SliverToBoxAdapter(child: _buildWeeklyChart(provider)),
                // Category breakdown
                SliverToBoxAdapter(child: _buildCategoryBreakdown(provider)),
                // Recent activity
                SliverToBoxAdapter(child: _buildRecentActivity(provider)),
                // Quote
                SliverToBoxAdapter(child: _buildQuote()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'HLedger',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_rounded, color: AppColors.textSecondary),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) async {
              if (value == 'logout') {
                await _confirmLogout(context);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: AppColors.red, size: 20),
                    const SizedBox(width: 10),
                    Text('Logout', style: GoogleFonts.inter(color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Logout', style: GoogleFonts.inter(color: AppColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await SupabaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildGreetingCard() {
    final name = SupabaseService.displayName;
    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.surface2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                firstLetter,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting, $name 👋',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here\'s your quick overview',
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
    );
  }

  Widget _buildQuickStats(AppProvider provider) {
    final totalTransactions = provider.transactions.length;
    final completedTasks = provider.tasks.where((t) => t.completed).length;
    final pendingTasks = provider.tasks.where((t) => !t.completed).length;
    final netBalance = provider.totalIncome - provider.totalExpense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Quick Stats',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: Icons.swap_horiz_rounded,
                iconColor: AppColors.accent,
                label: 'Transactions',
                value: '$totalTransactions',
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.green,
                label: 'Tasks Done',
                value: '$completedTasks',
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: Icons.pending_actions_rounded,
                iconColor: AppColors.yellow,
                label: 'Pending',
                value: '$pendingTasks',
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: netBalance >= 0 ? AppColors.green : AppColors.red,
                label: 'Net Balance',
                value: '₹${netBalance.toStringAsFixed(0)}',
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(AppProvider provider) {
    // Calculate last 7 days spending
    final now = DateTime.now();
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dailySpending = List<double>.filled(7, 0);

    for (final t in provider.transactions) {
      if (!t.isIncome) {
        final daysAgo = now.difference(t.timestamp).inDays;
        if (daysAgo >= 0 && daysAgo < 7) {
          // Map to correct weekday slot (0=today going back)
          final dayIndex = (now.weekday - 1 - daysAgo) % 7;
          if (dayIndex >= 0 && dayIndex < 7) {
            dailySpending[dayIndex] += t.amount;
          }
        }
      }
    }

    final maxVal = dailySpending.reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final fraction = maxVal > 0 ? dailySpending[i] / maxVal : 0.0;
                final isHighest = maxVal > 0 && dailySpending[i] == maxVal;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (dailySpending[i] > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '₹${dailySpending[i].toStringAsFixed(0)}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 8,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: fraction),
                          duration: Duration(milliseconds: 600 + i * 100),
                          curve: Curves.easeOutCubic,
                          builder: (_, value, __) {
                            return Container(
                              height: (100 * value).clamp(4, 100),
                              decoration: BoxDecoration(
                                color: isHighest
                                    ? AppColors.accent
                                    : AppColors.accent.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weekDays[i],
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: isHighest ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(AppProvider provider) {
    // Compute spending by category
    final categoryTotals = <String, double>{};
    double totalExpense = 0;

    for (final t in provider.transactions) {
      if (!t.isIncome) {
        categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
        totalExpense += t.amount;
      }
    }

    if (categoryTotals.isEmpty) return const SizedBox.shrink();

    // Sort and take top 4
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4).toList();

    final categoryColors = {
      'Food': const Color(0xFFFF9800),
      'Transport': const Color(0xFF42A5F5),
      'Shopping': const Color(0xFFE91E63),
      'Bills': const Color(0xFF26A69A),
      'Entertainment': const Color(0xFFAB47BC),
      'Health': const Color(0xFFEF5350),
      'Education': const Color(0xFF66BB6A),
      'Work': const Color(0xFF5C6BC0),
      'Other': const Color(0xFF78909C),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Categories',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...top.map((entry) {
            final pct = totalExpense > 0 ? entry.value / totalExpense : 0.0;
            final color = categoryColors[entry.key] ?? const Color(0xFF78909C);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₹${entry.value.toStringAsFixed(0)} (${(pct * 100).toStringAsFixed(0)}%)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) {
                      return Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: value,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(AppProvider provider) {
    final recent = provider.transactions.take(3).toList();
    if (recent.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            'No transactions yet.\nStart by adding one! 📝',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Recent Activity',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateToTab?.call(1), // Go to Khaata
                child: Text(
                  'See all →',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          ...recent.map((t) => TransactionCard(transaction: t)),
        ],
      ),
    );
  }

  Widget _buildQuote() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        _quoteOfTheDay,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Stat card with icon, number, and label — animates number counting up.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    // Parse numeric value for animation, fallback to displaying directly
    final numericStr = value.replaceAll(RegExp(r'[^0-9.-]'), '');
    final numericVal = double.tryParse(numericStr);
    final prefix = value.startsWith('₹') ? '₹' : '';
    final isNegative = value.contains('-');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          if (numericVal != null)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: numericVal.abs()),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, val, __) {
                final displayVal = isNegative ? '-${val.toStringAsFixed(0)}' : val.toStringAsFixed(0);
                return Text(
                  '$prefix$displayVal',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                );
              },
            )
          else
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
