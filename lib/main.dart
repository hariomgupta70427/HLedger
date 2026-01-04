import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'models/transaction.dart';
import 'models/task.dart';
import 'features/transactions/chat_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  
  await SupabaseService.initialize();
  await NotificationService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'HLedger',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo Container
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)],
                    ),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BFA6).withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 70,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'HLedger',
                  style: GoogleFonts.inter(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1D29),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Smart Ledger for Smarter You',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 60),
                // Premium Get Started Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BFA6).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Get Started',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                    MediaQuery.of(context).padding.top - 
                    MediaQuery.of(context).padding.bottom - 40,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00BFA6).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome Back',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1D29),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue managing your finances',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  
                  // Email Field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : const Color(0xFF1A1D29),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : const Color(0xFF1A1D29),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Login Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00BFA6).withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _isSignUp ? 'Create Account' : 'Sign In',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Toggle Sign Up/Login
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 14),
                        children: [
                          TextSpan(
                            text: _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                            style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF6B7280)),
                          ),
                          TextSpan(
                            text: _isSignUp ? 'Sign In' : 'Sign Up',
                            style: const TextStyle(color: Color(0xFF00BFA6), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or continue with',
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Google Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: Image.network(
                        'https://www.google.com/favicon.ico',
                        height: 24,
                        width: 24,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
                      ),
                      label: Text(
                        'Continue with Google',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF1A1D29),
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


  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await SupabaseService.signUp(_emailController.text.trim(), _passwordController.text);
        _showSuccess('Account created! Please check your email to verify.');
      } else {
        await SupabaseService.signIn(_emailController.text.trim(), _passwordController.text);
        _navigateToDashboard();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final success = await SupabaseService.signInWithGoogle();
      if (success) {
        _navigateToDashboard();
      } else {
        _showError('Google Sign-In was cancelled');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ChatScreen(),
    const KhaataScreen(),
    const TodoScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load data when dashboard first opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // Reload data when switching tabs to ensure fresh data
          if (index == 1 || index == 2) {
            Provider.of<AppProvider>(context, listen: false).loadData();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00BFA6),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Khaata',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_outlined),
            activeIcon: Icon(Icons.task),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}



// ChatScreen is now imported from features/transactions/chat_screen.dart

class KhaataScreen extends StatefulWidget {
  const KhaataScreen({super.key});

  @override
  State<KhaataScreen> createState() => _KhaataScreenState();
}

class _KhaataScreenState extends State<KhaataScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Khaata Book',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1D29),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Consumer<AppProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00BFA6)),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: provider.refresh,
                      child: Column(
                        children: [
                          _buildBalanceCard(provider, isDark),
                          Expanded(child: _buildTransactionsList(provider, isDark)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BFA6).withAlpha(100),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddTransactionDialog(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, {Transaction? existing}) {
    final personController = TextEditingController(text: existing?.person ?? '');
    final amountController = TextEditingController(text: existing?.amount.toString() ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    String category = existing?.category ?? 'debit';
    final isEditing = existing != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Transaction' : 'Add Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: personController,
                  decoration: const InputDecoration(
                    labelText: 'Person Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    prefixIcon: Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => category = 'debit'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: category == 'debit' ? Colors.red[100] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: category == 'debit' ? Colors.red : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.arrow_upward, color: category == 'debit' ? Colors.red : Colors.grey),
                              const SizedBox(height: 4),
                              Text('Gave (Debit)', style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: category == 'debit' ? Colors.red : Colors.grey,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => category = 'credit'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: category == 'credit' ? Colors.green[100] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: category == 'credit' ? Colors.green : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.arrow_downward, color: category == 'credit' ? Colors.green : Colors.grey),
                              const SizedBox(height: 4),
                              Text('Received (Credit)', style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: category == 'credit' ? Colors.green : Colors.grey,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _saveTransaction(
                context,
                personController.text,
                amountController.text,
                descController.text,
                category,
                existing,
              ),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA6)),
              child: Text(isEditing ? 'Update' : 'Add', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTransaction(
    BuildContext context,
    String person,
    String amountStr,
    String description,
    String category,
    Transaction? existing,
  ) async {
    if (person.isEmpty || amountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill person and amount'), backgroundColor: Colors.red),
      );
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
      );
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    Navigator.pop(context);

    try {
      if (existing != null) {
        // Update existing
        final updated = Transaction(
          id: existing.id,
          userId: userId,
          person: person,
          amount: amount,
          category: category,
          timestamp: existing.timestamp,
          description: description.isEmpty ? null : description,
        );
        await provider.updateTransaction(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated!'), backgroundColor: Colors.green),
        );
      } else {
        // Add new
        final transaction = Transaction(
          id: '',
          userId: userId,
          person: person,
          amount: amount,
          category: category,
          timestamp: DateTime.now(),
          description: description.isEmpty ? null : description,
        );
        await provider.addTransaction(transaction);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction added!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteTransaction(BuildContext context, Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to delete the transaction with ${transaction.person}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Provider.of<AppProvider>(context, listen: false).deleteTransaction(transaction.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted!'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBalanceCard(AppProvider provider, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BFA6).withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Net Balance',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${provider.balance.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceItem('Credit', provider.totalCredit, const Color(0xFF10B981)),
              _buildBalanceItem('Debit', provider.totalDebit, const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '₹${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(AppProvider provider, bool isDark) {
    if (provider.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : const Color(0xFF00BFA6)).withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: isDark ? Colors.white38 : const Color(0xFF00BFA6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No transactions yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1D29),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add a transaction',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: provider.transactions.length,
      itemBuilder: (context, index) {
        final transaction = provider.transactions[index];
        return _buildTransactionCard(transaction, isDark);
      },
    );
  }

  Widget _buildTransactionCard(Transaction transaction, bool isDark) {
    final isCredit = transaction.isCredit;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.person,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF1A1D29),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(transaction.timestamp),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _showAddTransactionDialog(context, existing: transaction);
              } else if (value == 'delete') {
                _deleteTransaction(context, transaction);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Text('Edit', style: GoogleFonts.inter()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Text('Delete', style: GoogleFonts.inter(color: const Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.task_alt_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'To-Do List',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1D29),
                      ),
                    ),
                  ],
                ),
              ),
              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: isDark ? Colors.white : const Color(0xFF1A1D29),
                  unselectedLabelColor: isDark ? Colors.white38 : const Color(0xFF6B7280),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    ),
                  ),
                  indicatorPadding: const EdgeInsets.all(4),
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Pending'),
                    Tab(text: 'Completed'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Content
              Expanded(
                child: Consumer<AppProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                      );
                    }

                    final pendingTasks = provider.tasks.where((t) => !t.completed).toList();
                    final completedTasks = provider.tasks.where((t) => t.completed).toList();

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTaskList(pendingTasks, false, provider, isDark),
                        _buildTaskList(completedTasks, true, provider, isDark),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withAlpha(100),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddTaskDialog(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, {Task? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    DateTime? selectedDate = existing?.dueDate;
    TimeOfDay? selectedTime = existing?.dueDate != null 
        ? TimeOfDay.fromDateTime(existing!.dueDate!) 
        : null;
    bool reminder = existing?.reminder ?? false;
    final isEditing = existing != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            isEditing ? 'Edit Task' : 'New Task',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1D29),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : const Color(0xFF1A1D29),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    hintText: 'What needs to be done?',
                    prefixIcon: Icon(
                      Icons.task_alt_rounded,
                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Date Selection
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF3B82F6), size: 20),
                    ),
                    title: Text(
                      selectedDate != null 
                          ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                          : 'Select Due Date',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: selectedDate != null 
                            ? (isDark ? Colors.white : const Color(0xFF1A1D29))
                            : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                      ),
                    ),
                    trailing: selectedDate != null 
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: isDark ? Colors.white60 : Colors.grey),
                            onPressed: () => setDialogState(() {
                              selectedDate = null;
                              selectedTime = null;
                            }),
                          )
                        : null,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Time Selection
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.access_time_rounded, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    title: Text(
                      selectedTime != null 
                          ? '${selectedTime!.hourOfPeriod}:${selectedTime!.minute.toString().padLeft(2, '0')} ${selectedTime!.period == DayPeriod.am ? 'AM' : 'PM'}'
                          : 'Select Time (optional)',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: selectedTime != null 
                            ? (isDark ? Colors.white : const Color(0xFF1A1D29))
                            : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                      ),
                    ),
                    trailing: selectedTime != null 
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: isDark ? Colors.white60 : Colors.grey),
                            onPressed: () => setDialogState(() => selectedTime = null),
                          )
                        : null,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedTime = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Reminder Toggle
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      'Set Reminder',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1A1D29),
                      ),
                    ),
                    subtitle: Text(
                      reminder 
                          ? 'Notify me at scheduled time' 
                          : 'No reminder',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      ),
                    ),
                    value: reminder,
                    activeColor: const Color(0xFF00BFA6),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (reminder ? const Color(0xFF00BFA6) : Colors.grey).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        reminder ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                        color: reminder ? const Color(0xFF00BFA6) : Colors.grey,
                        size: 20,
                      ),
                    ),
                    onChanged: (value) => setDialogState(() => reminder = value),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: isDark ? Colors.white60 : const Color(0xFF6B7280)),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)],
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  // Combine date and time
                  DateTime? finalDateTime;
                  if (selectedDate != null) {
                    finalDateTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime?.hour ?? 9,
                      selectedTime?.minute ?? 0,
                    );
                  }
                  _saveTask(context, titleController.text, finalDateTime, reminder, existing);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isEditing ? 'Update' : 'Add Task',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _saveTask(BuildContext context, String title, DateTime? dueDate, bool reminder, Task? existing) async {
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title'), backgroundColor: Colors.red),
      );
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    Navigator.pop(context);

    try {
      if (existing != null) {
        // Update existing
        final updated = existing.copyWith(
          title: title,
          dueDate: dueDate,
          reminder: reminder,
        );
        await provider.updateTask(updated);
        
        // Schedule/cancel notification
        if (reminder && dueDate != null) {
          await NotificationService().scheduleTaskReminder(
            id: updated.id.hashCode,
            title: 'Task Due: $title',
            body: 'Your task is due today!',
            scheduledDate: dueDate,
          );
        } else {
          await NotificationService().cancelNotification(updated.id.hashCode);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated!'), backgroundColor: Colors.green),
        );
      } else {
        // Add new
        final task = Task(
          id: '',
          userId: userId,
          title: title,
          dueDate: dueDate,
          completed: false,
          reminder: reminder,
          createdAt: DateTime.now(),
        );
        await provider.addTask(task);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task added!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteTask(BuildContext context, Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Provider.of<AppProvider>(context, listen: false).deleteTask(task.id);
        await NotificationService().cancelNotification(task.id.hashCode);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted!'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildTaskList(List<Task> tasks, bool isCompleted, AppProvider provider, bool isDark) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : const Color(0xFF8B5CF6)).withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check_circle_outline_rounded : Icons.task_alt_rounded,
                size: 48,
                color: isDark ? Colors.white38 : const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isCompleted ? 'No completed tasks' : 'No pending tasks',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1D29),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCompleted 
                  ? 'Complete some tasks to see them here'
                  : 'Tap + to add a task',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildTaskCard(task, provider, isDark);
        },
      ),
    );
  }

  Widget _buildTaskCard(Task task, AppProvider provider, bool isDark) {
    final isOverdue = task.dueDate != null && 
                     task.dueDate!.isBefore(DateTime.now()) && 
                     !task.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue 
              ? const Color(0xFFEF4444).withAlpha(100)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
          width: isOverdue ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Checkbox
          Container(
            decoration: BoxDecoration(
              gradient: task.completed 
                  ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])
                  : null,
              color: task.completed ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: task.completed 
                  ? null 
                  : Border.all(color: isDark ? Colors.white38 : const Color(0xFFD1D5DB), width: 2),
            ),
            child: InkWell(
              onTap: () => _toggleTaskCompletion(task, provider),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 28,
                height: 28,
                child: task.completed 
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    decoration: task.completed ? TextDecoration.lineThrough : null,
                    color: task.completed 
                        ? (isDark ? Colors.white38 : const Color(0xFF9CA3AF))
                        : (isDark ? Colors.white : const Color(0xFF1A1D29)),
                  ),
                ),
                if (task.dueDate != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: isOverdue ? const Color(0xFFEF4444) : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDueDate(task.dueDate!),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isOverdue ? FontWeight.w600 : null,
                          color: isOverdue ? const Color(0xFFEF4444) : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Indicators
          if (task.reminder && !task.completed)
            Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_rounded, color: Color(0xFF8B5CF6), size: 18),
            ),
          if (isOverdue)
            Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 18),
            ),
          // Menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _showAddTaskDialog(context, existing: task);
              } else if (value == 'delete') {
                _deleteTask(context, task);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Text('Edit', style: GoogleFonts.inter()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Text('Delete', style: GoogleFonts.inter(color: const Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTaskCompletion(Task task, AppProvider provider) async {
    final updatedTask = task.copyWith(completed: !task.completed);
    await provider.updateTask(updatedTask);
    
    if (updatedTask.completed && task.reminder) {
      await NotificationService().cancelNotification(task.id.hashCode);
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final difference = dueDateOnly.difference(today).inDays;
    
    // Format time
    final hour = dueDate.hour > 12 ? dueDate.hour - 12 : (dueDate.hour == 0 ? 12 : dueDate.hour);
    final period = dueDate.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '${hour}:${dueDate.minute.toString().padLeft(2, '0')} $period';
    
    String dateStr;
    if (difference == 0) {
      dateStr = 'Today';
    } else if (difference == 1) {
      dateStr = 'Tomorrow';
    } else if (difference == -1) {
      dateStr = 'Yesterday';
    } else if (difference < 0) {
      dateStr = '${-difference} days overdue';
    } else if (difference < 7) {
      dateStr = 'In $difference days';
    } else {
      dateStr = '${dueDate.day}/${dueDate.month}/${dueDate.year}';
    }
    
    // Only show time if it's not the default 9:00 AM
    if (dueDate.hour != 9 || dueDate.minute != 0) {
      return '$dateStr at $timeStr';
    }
    return dateStr;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Motivational quotes
  static const List<String> _quotes = [
    "Financial freedom is not a dream, it's a plan.",
    "Small daily improvements lead to stunning results.",
    "Your money should work for you, not against you.",
    "Discipline is boring — until it starts paying you back.",
    "Your future self is stalking you… waiting for you to finally start.",
    "Write it down now, or panic about it later. Your choice.",
    "Tiny progress feels useless — until suddenly it isn’t.",
    "Money doesn’t vanish. It just quietly leaves poor planners.",
    "Stop saying ‘someday’. That day never shows up.",
    "Tracking isn’t control freak energy — it’s freedom energy.",
    "Lazy today, stressed tomorrow. Efficient today, chill tomorrow.",
    "Your tasks don’t hate you. They just want attention.",
    "Savings look boring now — and incredibly sexy later.",
    "If it takes less than 2 minutes, do it. Stop negotiating.",
    "Your brain lies. Your records don’t.",
    "Success is basically: plan, repeat, get mocked, win.",
    "You’re not behind — you just stopped showing up.",
    "The goal isn’t hustle. The goal is peace — and peace loves structure.",
    "Track your expenses, unlock your potential.",
    "Today's savings are tomorrow's opportunities.",
  ];

  String get _randomQuote => _quotes[DateTime.now().day % _quotes.length];

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appProvider = Provider.of<AppProvider>(context);
    
    // Calculate stats
    final totalTransactions = appProvider.transactions.length;
    final totalTasks = appProvider.tasks.length;
    final completedTasks = appProvider.tasks.where((t) => t.completed).length;
    final pendingTasks = totalTasks - completedTasks;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1D29),
                      ),
                    ),
                    // Theme Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => themeProvider.toggleTheme(),
                        icon: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: isDark ? Colors.amber : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // User Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00BFA6), Color(0xFF00E5CC)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BFA6).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hi, ${user?.email?.split('@').first ?? 'User'}! 👋',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.email ?? 'user@example.com',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Motivational Quote
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.format_quote_rounded, color: Color(0xFF6C63FF)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quote of the Day',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6C63FF),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _randomQuote,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Analytics Section
                Text(
                  'Your Analytics',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1D29),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.receipt_long_rounded,
                        title: 'Transactions',
                        value: totalTransactions.toString(),
                        color: const Color(0xFF3B82F6),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.task_alt_rounded,
                        title: 'Tasks Done',
                        value: completedTasks.toString(),
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.pending_actions_rounded,
                        title: 'Pending',
                        value: pendingTasks.toString(),
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Balance',
                        value: '₹${appProvider.balance.toStringAsFixed(0)}',
                        color: const Color(0xFF00BFA6),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Settings Section
                Text(
                  'Settings',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1D29),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Theme Toggle Setting
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.amber : const Color(0xFF6B7280)).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: isDark ? Colors.amber : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dark Mode',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1A1D29),
                              ),
                            ),
                            Text(
                              isDark ? 'Currently using dark theme' : 'Currently using light theme',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isDark,
                        onChanged: (value) => themeProvider.toggleTheme(),
                        activeColor: const Color(0xFF00BFA6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Logout Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await SupabaseService.signOut();
                      Provider.of<AppProvider>(context, listen: false).signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    label: Text(
                      'Sign Out',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // App Info
                Center(
                  child: Text(
                    'HLedger v1.0.0 • Made with ❤️',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : const Color(0xFF6B7280),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1D29),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}