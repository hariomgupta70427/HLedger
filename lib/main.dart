import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'providers/app_provider.dart';
import 'models/transaction.dart';
import 'models/task.dart';
import 'features/transactions/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SupabaseService.initialize();
  await NotificationService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: MaterialApp(
        title: 'HLedger',
        theme: ThemeData(
          useMaterial3: true,
          primarySwatch: Colors.teal,
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA6),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFA6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'HLedger',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Smart Ledger for Smarter You',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Get Started'),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_balance_wallet,
                size: 80,
                color: Color(0xFF00BFA6),
              ),
              const SizedBox(height: 16),
              const Text(
                'HLedger',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your Chat. Your Tasks. Your Transactions. Sorted.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isSignUp ? 'Sign Up' : 'Login'),
                ),
              ),
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                  });
                },
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Login'
                      : 'Don\'t have an account? Sign Up',
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Divider with "OR"
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.grey)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.grey)),
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
                    side: const BorderSide(color: Colors.grey),
                  ),
                  icon: Image.network(
                    'https://www.google.com/favicon.ico',
                    height: 24,
                    width: 24,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
                  ),
                  label: const Text(
                    'Sign in with Google',
                    style: TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                ),
              ),
            ],
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khaata Book'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionDialog(context),
        backgroundColor: const Color(0xFF00BFA6),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Consumer<AppProvider>(
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
                _buildBalanceCard(provider),
                Expanded(child: _buildTransactionsList(provider)),
              ],
            ),
          );
        },
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

  Widget _buildBalanceCard(AppProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BFA6), Color(0xFF00ACC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BFA6).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Net Balance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${provider.balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceItem('Credit', provider.totalCredit, Colors.green[300]!),
              _buildBalanceItem('Debit', provider.totalDebit, Colors.red[300]!),
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

  Widget _buildTransactionsList(AppProvider provider) {
    if (provider.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No transactions yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add a transaction',
              style: TextStyle(color: Colors.grey),
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
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isCredit = transaction.isCredit;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCredit ? Colors.green[100] : Colors.red[100],
          child: Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: isCredit ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          transaction.person,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _formatDateTime(transaction.timestamp),
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isCredit ? Colors.green : Colors.red,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showAddTransactionDialog(context, existing: transaction);
                } else if (value == 'delete') {
                  _deleteTransaction(context, transaction);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Row(
                  children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')],
                )),
                const PopupMenuItem(value: 'delete', child: Row(
                  children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))],
                )),
              ],
            ),
          ],
        ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        backgroundColor: const Color(0xFFF8F9FA),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00BFA6),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF00BFA6),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        backgroundColor: const Color(0xFF00BFA6),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00BFA6)),
            );
          }

          final pendingTasks = provider.tasks.where((t) => !t.completed).toList();
          final completedTasks = provider.tasks.where((t) => t.completed).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTaskList(pendingTasks, false, provider),
              _buildTaskList(completedTasks, true, provider),
            ],
          );
        },
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, {Task? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    DateTime? selectedDate = existing?.dueDate;
    bool reminder = existing?.reminder ?? false;
    final isEditing = existing != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Task' : 'Add Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    prefixIcon: Icon(Icons.task),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF00BFA6)),
                  title: Text(
                    selectedDate != null 
                        ? 'Due: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : 'Select Due Date (optional)',
                    style: TextStyle(
                      color: selectedDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                  trailing: selectedDate != null 
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setDialogState(() => selectedDate = null),
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
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Set Reminder'),
                  subtitle: Text(
                    reminder ? 'You will be notified on due date' : 'No reminder set',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: reminder,
                  activeColor: const Color(0xFF00BFA6),
                  secondary: Icon(
                    reminder ? Icons.notifications_active : Icons.notifications_off,
                    color: reminder ? const Color(0xFF00BFA6) : Colors.grey,
                  ),
                  onChanged: (value) => setDialogState(() => reminder = value),
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
              onPressed: () => _saveTask(context, titleController.text, selectedDate, reminder, existing),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA6)),
              child: Text(isEditing ? 'Update' : 'Add', style: const TextStyle(color: Colors.white)),
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

  Widget _buildTaskList(List<Task> tasks, bool isCompleted, AppProvider provider) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompleted ? Icons.check_circle_outline : Icons.task_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isCompleted ? 'No completed tasks' : 'No pending tasks',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              isCompleted 
                  ? 'Complete some tasks to see them here'
                  : 'Tap + to add a task',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildTaskCard(task, provider);
        },
      ),
    );
  }

  Widget _buildTaskCard(Task task, AppProvider provider) {
    final isOverdue = task.dueDate != null && 
                     task.dueDate!.isBefore(DateTime.now()) && 
                     !task.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          onChanged: (value) => _toggleTaskCompletion(task, provider),
          activeColor: const Color(0xFF00BFA6),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: task.completed ? TextDecoration.lineThrough : null,
            color: task.completed ? Colors.grey : null,
          ),
        ),
        subtitle: task.dueDate != null
            ? Text(
                'Due: ${_formatDueDate(task.dueDate!)}',
                style: TextStyle(
                  color: isOverdue ? Colors.red : Colors.grey,
                  fontWeight: isOverdue ? FontWeight.w500 : null,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.reminder && !task.completed)
              const Icon(Icons.notifications_active, color: Color(0xFF00BFA6), size: 20),
            if (isOverdue)
              const Icon(Icons.warning, color: Colors.red, size: 20),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showAddTaskDialog(context, existing: task);
                } else if (value == 'delete') {
                  _deleteTask(context, task);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Row(
                  children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')],
                )),
                const PopupMenuItem(value: 'delete', child: Row(
                  children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))],
                )),
              ],
            ),
          ],
        ),
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
    final difference = dueDate.difference(now);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays == -1) {
      return 'Yesterday (Overdue)';
    } else if (difference.inDays < 0) {
      return '${-difference.inDays} days overdue';
    } else if (difference.inDays < 7) {
      return 'In ${difference.inDays} days';
    } else {
      return '${dueDate.day}/${dueDate.month}/${dueDate.year}';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Color(0xFF00BFA6),
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                user?.email ?? 'User',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'User ID: ${user?.id.substring(0, 8) ?? 'Unknown'}...',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 40),
              
              // Logout Button
              SizedBox(
                width: double.infinity,
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
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                'HLedger v1.0.0',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}