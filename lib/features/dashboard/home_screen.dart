import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction.dart';
import '../../providers/app_provider.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/quick_actions.dart';
import '../../shared/widgets/transaction_card.dart';
import '../../main.dart';
import '../upi_import/upi_import_screen.dart';
import '../analytics/analytics_category_colors.dart';
import '../analytics/analytics_screen.dart';
import '../compliance/privacy_policy_screen.dart';

/// Dashboard/Home screen — opens on the balance, then this month, then the week.
class HomeScreen extends StatefulWidget {
  /// Callback to navigate to a specific tab index.
  final void Function(int tabIndex)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
            final stats = _Stats.from(provider.transactions);

            return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildAppBar(context, provider.pendingReviewCount),
                ),
                SliverToBoxAdapter(child: _buildBalanceHero(stats)),
                SliverToBoxAdapter(
                  child: QuickActionsRow(
                    onViewSummary: () {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    onNavigateToTab: widget.onNavigateToTab,
                  ),
                ),
                SliverToBoxAdapter(child: _buildMonthGrid(stats)),
                SliverToBoxAdapter(child: _buildWeekChart(stats)),
                SliverToBoxAdapter(child: _buildCategoryBreakdown(stats)),
                SliverToBoxAdapter(child: _buildRecentActivity(provider)),
                SliverToBoxAdapter(child: _buildQuote()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, int pendingReview) {
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
          _IconAction(
            icon: Icons.insights_rounded,
            tooltip: 'Analytics',
            // Labelled, because a bare icon chip read as decoration and went
            // unnoticed. The label is what makes it obviously tappable.
            label: 'Insights',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              );
            },
          ),
          _IconAction(
            icon: Icons.sms_rounded,
            tooltip: 'Review detected transactions',
            // Detection is worthless if the queue it fills is invisible.
            badge: pendingReview,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UpiImportScreen(
                    onNavigateToTab: widget.onNavigateToTab,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.settings_rounded,
                  color: AppColors.textSecondary, size: 18),
            ),
            tooltip: 'Settings',
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) async {
              if (value == 'logout') {
                await _confirmLogout(context);
              } else if (value == 'privacy') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'privacy',
                child: Row(
                  children: [
                    const Icon(Icons.privacy_tip_rounded,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Text('Privacy Policy',
                        style: GoogleFonts.inter(color: AppColors.textPrimary)),
                  ],
                ),
              ),
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
            child: Text('Logout',
                style: GoogleFonts.inter(
                    color: AppColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      }
    }
  }

  /// Balance, with the two figures it is made of underneath it.
  ///
  /// Income and expense are shown side by side rather than collapsed into a
  /// single net number: the net alone cannot tell a ₹0 balance earned by
  /// spending nothing apart from one earned by spending everything.
  Widget _buildBalanceHero(_Stats stats) {
    final name = AuthService.displayName;
    final inCredit = stats.balance >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.surface2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_greeting, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildAvatar(name),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'BALANCE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: stats.balance),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Money.rupees(value),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: inCredit ? AppColors.textPrimary : AppColors.red,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildFlow(
                  'Income',
                  stats.income,
                  AppColors.green,
                  Icons.south_west_rounded,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                child: _buildFlow(
                  'Expense',
                  stats.expense,
                  AppColors.red,
                  Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initial = name.characters.isNotEmpty
        ? name.characters.first.toUpperCase()
        : 'U';
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildFlow(String label, double amount, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Money.rupees(amount),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Four money figures. The grid used to spend three of its four tiles on
  /// counts — two of them task counts — on a screen whose subject is money.
  Widget _buildMonthGrid(_Stats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Expanded(child: Text('This month', style: _sectionTitle())),
                Text(
                  DateFormat('MMMM').format(DateTime.now()),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _MoneyTile(
                  icon: Icons.north_east_rounded,
                  color: AppColors.red,
                  label: 'Spent',
                  amount: stats.monthSpent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoneyTile(
                  icon: Icons.south_west_rounded,
                  color: AppColors.green,
                  label: 'Received',
                  amount: stats.monthReceived,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MoneyTile(
                  icon: Icons.today_rounded,
                  color: AppColors.accent,
                  label: 'Spent today',
                  amount: stats.todaySpent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoneyTile(
                  icon: Icons.speed_rounded,
                  color: AppColors.yellow,
                  label: 'Avg / day',
                  amount: stats.monthDailyAverage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Seven rolling days, drawn against a fixed reference rather than the week's
  /// own peak.
  ///
  /// Normalising each week to its own maximum made every week look identical —
  /// a ₹50 week and a ₹50,000 week both produced one full-height bar — which is
  /// worse than no chart, because it reads as information.
  Widget _buildWeekChart(_Stats stats) {
    const plotHeight = 116.0;
    final ceiling = stats.scaleCeiling;
    final average = stats.weekAverage;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text('Last 7 days', style: _sectionTitle())),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${Money.rupees(stats.weekSpend)} out',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'avg ${Money.rupees(average)}/day',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (ceiling <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Nothing spent in the last four weeks.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else ...[
            SizedBox(
              height: plotHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  7,
                  (i) => _buildBar(stats, i, ceiling, plotHeight),
                ),
              ),
            ),
            // A real baseline, so the bars sit on something. There used to be a
            // free-floating average rule across the middle of the plot instead;
            // it read as the axis, which made every bar look like it overshot
            // below the line. The average is stated in the header rather than
            // drawn.
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            Row(children: List.generate(7, (i) => _buildDayLabel(stats, i))),
            const SizedBox(height: 14),
            Text(
              'Full height is ${Money.rupees(ceiling)}, your busiest day in the '
              'last four weeks — so these bars mean the same thing next week.',
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBar(_Stats stats, int index, double ceiling, double plotHeight) {
    final amount = stats.daySpend[index];
    final isToday = index == stats.todayIndex;
    final target = (amount / ceiling).clamp(0.0, 1.0);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target),
          duration: Duration(milliseconds: 550 + index * 60),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => Container(
            // A day with no spend keeps a 2px trace so the axis stays readable,
            // but it must not be mistaken for a small amount.
            height: amount > 0 ? (plotHeight * value).clamp(3.0, plotHeight) : 2,
            decoration: BoxDecoration(
              color: amount <= 0
                  ? AppColors.surface2
                  : isToday
                      ? AppColors.accent
                      : AppColors.accent.withValues(alpha: 0.38),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayLabel(_Stats stats, int index) {
    final isToday = index == stats.todayIndex;
    return Expanded(
      child: Text(
        stats.dayLabels[index],
        textAlign: TextAlign.center,
        maxLines: 1,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          color: isToday ? AppColors.accent : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(_Stats stats) {
    if (stats.categories.isEmpty) return const SizedBox.shrink();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Where it goes', style: _sectionTitle())),
              Text(
                '${Money.rupees(stats.expense)} total',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...stats.categories.map(_buildCategoryRow),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(_CategorySlice slice) {
    final color = slice.isRemainder
        ? AppColors.textSecondary
        : AnalyticsCategoryColors.of(slice.label);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  slice.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${Money.rupees(slice.amount)}  ·  '
                '${(slice.share * 100).round()}%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: slice.share.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => Stack(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(AppProvider provider) {
    final recent = provider.transactions.take(3).toList();
    if (recent.isEmpty) {
      return _Card(
        child: Center(
          child: Text(
            'No transactions yet.\nAdd one, or turn on auto-detect.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
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
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Recent activity', style: _sectionTitle()),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => widget.onNavigateToTab?.call(1),
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
          ...recent.map(
            (t) => TransactionCard(
              transaction: t,
              onTap: () => widget.onNavigateToTab?.call(1),
            ),
          ),
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

TextStyle _sectionTitle() => GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

/// Everything the dashboard reads, computed in a single pass over the ledger.
///
/// The screen used to walk the transaction list four times per rebuild — once
/// per section — and recompute the balance by hand from two getters that each
/// walked it again.
class _Stats {
  const _Stats({
    required this.income,
    required this.expense,
    required this.monthSpent,
    required this.monthReceived,
    required this.todaySpent,
    required this.daysElapsed,
    required this.dayLabels,
    required this.daySpend,
    required this.scaleCeiling,
    required this.categories,
  });

  final double income;
  final double expense;
  final double monthSpent;
  final double monthReceived;
  final double todaySpent;
  final int daysElapsed;

  /// A rolling seven days, oldest first. Today is always the last column, which
  /// is what makes the labels agree with the window the data covers — fixed
  /// Mon–Sun columns described a calendar week the filter never used.
  final List<String> dayLabels;
  final List<double> daySpend;

  /// Height reference for the bars: the busiest single day in the last four
  /// weeks.
  final double scaleCeiling;

  final List<_CategorySlice> categories;

  int get todayIndex => daySpend.length - 1;
  double get balance => income - expense;
  double get weekSpend => daySpend.fold(0.0, (sum, value) => sum + value);
  double get weekAverage => weekSpend / daySpend.length;

  /// Spend per day *elapsed*, not per day in the month — dividing a partial
  /// month by 31 understates the pace it is actually running at.
  double get monthDailyAverage =>
      daysElapsed == 0 ? 0 : monthSpent / daysElapsed;

  factory _Stats.from(List<Transaction> transactions) {
    final now = DateTime.now();
    // Day keys are UTC midnights: subtracting local midnights can return 23 or
    // 25 hours across a zone change and drop a transaction into the wrong day.
    final today = DateTime.utc(now.year, now.month, now.day);
    final windowStart = today.subtract(const Duration(days: 27));
    final monthStart = DateTime.utc(now.year, now.month);

    var income = 0.0;
    var expense = 0.0;
    var monthSpent = 0.0;
    var monthReceived = 0.0;
    var todaySpent = 0.0;

    final daySpend = List<double>.filled(7, 0);
    final windowSpend = <DateTime, double>{};
    final byCategory = <String, double>{};

    for (final t in transactions) {
      final stamp = t.timestamp;
      final day = DateTime.utc(stamp.year, stamp.month, stamp.day);
      final thisMonth = !day.isBefore(monthStart);

      if (t.isIncome) {
        income += t.amount;
        if (thisMonth) monthReceived += t.amount;
        continue;
      }

      expense += t.amount;
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
      if (thisMonth) monthSpent += t.amount;
      if (day == today) todaySpent += t.amount;

      if (!day.isBefore(windowStart) && !day.isAfter(today)) {
        windowSpend[day] = (windowSpend[day] ?? 0) + t.amount;
        final daysAgo = today.difference(day).inDays;
        if (daysAgo < 7) daySpend[6 - daysAgo] += t.amount;
      }
    }

    var ceiling = 0.0;
    for (final value in windowSpend.values) {
      if (value > ceiling) ceiling = value;
    }

    final labels = <String>[];
    for (var back = 6; back >= 0; back--) {
      labels.add(back == 0
          ? 'Today'
          : DateFormat('E').format(now.subtract(Duration(days: back))));
    }

    return _Stats(
      income: income,
      expense: expense,
      monthSpent: monthSpent,
      monthReceived: monthReceived,
      todaySpent: todaySpent,
      daysElapsed: now.day,
      dayLabels: labels,
      daySpend: daySpend,
      scaleCeiling: ceiling,
      categories: _slice(byCategory, expense),
    );
  }

  /// Top four categories plus a remainder.
  ///
  /// Without the remainder the bars on screen sum to whatever the top four
  /// happen to cover, and a breakdown that adds up to 71% with nothing to
  /// account for the rest reads as a bug.
  static List<_CategorySlice> _slice(
    Map<String, double> byCategory,
    double total,
  ) {
    if (byCategory.isEmpty || total <= 0) return const <_CategorySlice>[];

    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final slices = <_CategorySlice>[
      for (final entry in sorted.take(4))
        _CategorySlice(entry.key, entry.value, entry.value / total),
    ];

    if (sorted.length > 4) {
      final rest = sorted
          .skip(4)
          .fold<double>(0, (sum, entry) => sum + entry.value);
      slices.add(_CategorySlice(
        'Everything else',
        rest,
        rest / total,
        isRemainder: true,
      ));
    }

    return slices;
  }
}

class _CategorySlice {
  const _CategorySlice(
    this.label,
    this.amount,
    this.share, {
    this.isRemainder = false,
  });

  final String label;
  final double amount;
  final double share;
  final bool isRemainder;
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// A money tile that counts up to its value.
///
/// It takes the amount as a number. The tile it replaces took a pre-formatted
/// string and stripped it back to a number with a regex in order to animate it,
/// which stopped working the moment the string contained a separator.
class _MoneyTile extends StatelessWidget {
  const _MoneyTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.amount,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: amount),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Money.compact(value),
                maxLines: 1,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

/// A header action, optionally labelled and optionally carrying a count.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String? label;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: label == null
          ? const EdgeInsets.all(6)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        // 48dp minimum, so the tap target stays accessible even though the chip
        // itself is smaller.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  chip,
                  if (badge > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.background, width: 1.5),
                        ),
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
