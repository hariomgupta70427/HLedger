import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../services/notification_service.dart';
import 'home_screen.dart';
import '../khaata/khaata_screen.dart';
import '../transactions/chat_screen.dart';
import '../tasks/tasks_screen.dart';
import '../upi_import/upi_import_screen.dart';

/// Main app shell — 4 tabs with Instagram-style swipe + bottom nav.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  int _currentIndex = 0;

  // GlobalKeys for accessing screen methods from FAB
  final GlobalKey<KhaataScreenState> _khaataKey = GlobalKey<KhaataScreenState>();
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey<TasksScreenState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addObserver(this);
    // Load data on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      provider.loadData();
      // Load the on-device review queue and start app-wide auto-detection.
      provider.loadPendingReview();
      _provider = provider..addListener(_onProviderChanged);

      _tapSub = NotificationService.taps.listen(_onNotificationPayload);
      // A tap that cold-started the app landed before anything was listening.
      final launched = NotificationService.takeLaunchPayload();
      if (launched != null) _onNotificationPayload(launched);
    });
  }

  AppProvider? _provider;
  StreamSubscription<String>? _tapSub;

  /// A rejected write leaves the change visible in the local cache, so without
  /// this the user would believe it saved.
  void _onProviderChanged() {
    final message = _provider?.syncError;
    if (message == null || !mounted) return;
    _provider!.clearSyncError();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// The "transaction detected" alert promises "tap to review", so the tap has
  /// to land on the review inbox — it used to be logged and dropped.
  void _onNotificationPayload(String payload) {
    if (payload != kTransactionDetectedPayload || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UpiImportScreen(onNavigateToTab: _navigateToTab),
      ),
    );
  }

  /// A force-stop — which OEM power managers do freely — makes Android drop
  /// every pending alarm without telling anyone. Re-arming on resume is what
  /// silently repairs that.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _provider?.rescheduleReminders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSub?.cancel();
    _provider?.removeListener(_onProviderChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: [
          HomeScreen(onNavigateToTab: _navigateToTab),
          KhaataScreen(key: _khaataKey),
          const ChatScreen(),
          TasksScreen(key: _tasksKey),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentIndex == 1 || _currentIndex == 3
          ? _buildFAB()
          : null,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.dashboard_rounded,
                label: 'Home',
                isActive: _currentIndex == 0,
                onTap: () => _navigateToTab(0),
              ),
              _NavItem(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Khaata',
                isActive: _currentIndex == 1,
                onTap: () => _navigateToTab(1),
              ),
              _NavItem(
                icon: Icons.chat_bubble_rounded,
                label: 'Chat',
                isActive: _currentIndex == 2,
                onTap: () => _navigateToTab(2),
                isLarger: true,
              ),
              _NavItem(
                icon: Icons.task_alt_rounded,
                label: 'Tasks',
                isActive: _currentIndex == 3,
                onTap: () => _navigateToTab(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      backgroundColor: AppColors.accent,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      onPressed: () {
        if (_currentIndex == 1) {
          _khaataKey.currentState?.showAddTransaction();
        } else if (_currentIndex == 3) {
          _tasksKey.currentState?.showAddTask();
        }
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isLarger;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isLarger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.accent : AppColors.textSecondary,
              size: isLarger ? 28 : 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
