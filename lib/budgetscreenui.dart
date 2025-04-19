import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:weza/addbudget_screen.dart';
import '../models/budget.dart';
import '../service/budget_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({Key? key}) : super(key: key);

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final BudgetService _budgetService = BudgetService();
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Budget> _budgets = [];
  double _totalBudget = 0.0;
  double _totalSpent = 0.0;
  int _remainingDays = 0;
  String _currentMonth = '';
  Map<String, double> _categorySpending = {};

  @override
  void initState() {
    super.initState();
    print("BudgetScreen: Initializing");
    _loadData();
  }

  Future<void> _loadData() async {
    print("BudgetScreen: Loading data started");
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      print("BudgetScreen: Initializing budget service");
      await _budgetService.initialize();
      
      print("BudgetScreen: Fetching current month budgets");
      final budgets = await _budgetService.getCurrentMonthBudgets();
      
      print("BudgetScreen: Fetching total budget");
      final totalBudget = await _budgetService.getCurrentMonthTotalBudget();
      
      print("BudgetScreen: Fetching total spending");
      final totalSpent = await _budgetService.getCurrentMonthTotalSpending();
      
      print("BudgetScreen: Getting remaining days");
      final remainingDays = _budgetService.getRemainingDaysInMonth();
      
      print("BudgetScreen: Getting current month name");
      final currentMonth = _budgetService.getCurrentMonthName();

      // Load spending for each category with null safety
      print("BudgetScreen: Loading category spending");
      Map<String, double> categorySpending = {};
      
      if (budgets != null && budgets.isNotEmpty) {
        for (var budget in budgets) {
          if (budget.category != null) {
            print("BudgetScreen: Loading spending for category: ${budget.category}");
            try {
              final spent = await _budgetService.getSpendingForCategory(budget.category);
              categorySpending[budget.category] = spent ?? 0.0;
            } catch (e) {
              print("BudgetScreen: Error loading spending for ${budget.category}: $e");
              categorySpending[budget.category] = 0.0;
            }
          }
        }
      } else {
        print("BudgetScreen: No budgets found or null");
      }

      if (!mounted) return;
      
      setState(() {
        _budgets = budgets ?? [];
        _totalBudget = totalBudget ?? 0.0;
        _totalSpent = totalSpent ?? 0.0;
        _remainingDays = remainingDays ?? 0;
        _currentMonth = currentMonth ?? 'Current Month';
        _categorySpending = categorySpending;
        _isLoading = false;
      });
      
      print("BudgetScreen: Data loaded successfully");
      print("BudgetScreen: Budgets count: ${_budgets.length}");
      print("BudgetScreen: Total budget: $_totalBudget");
      print("BudgetScreen: Total spent: $_totalSpent");
      
    } catch (e) {
      print("BudgetScreen: Error loading data: $e");
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      // Show error message to user
      _showErrorSnackBar("Failed to load budget data. Please try again.");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () { Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddBudgetCategoryScreen(),
              ),
            );
         
        },
        label: const Text('Create Budget'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading budget data...", style: TextStyle(color: Colors.grey))
          ],
        )
      );
    }
    
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text("Error loading data", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_errorMessage, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text("Try Again"),
            )
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBudgetSummaryCard(),
              const SizedBox(height: 24),
              Text(
                'Category Budgets',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _budgets.isEmpty
                  ? _buildNoBudgetsMessage()
                  : _buildCategoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoBudgetsMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No budgets created yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first budget to start tracking',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSummaryCard() {
    final remaining = _totalBudget - _totalSpent;
    final progress = _totalBudget > 0 ? (_totalSpent / _totalBudget).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color.fromARGB(255, 17, 203, 141), Color.fromARGB(237, 26, 124, 39)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _currentMonth,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_remainingDays days left',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BudgetSummaryItem(
                    icon: Icons.account_balance_wallet,
                    label: 'Total Budget',
                    amount: _totalBudget,
                  ),
                  _BudgetSummaryItem(
                    icon: Icons.shopping_cart,
                    label: 'Spent',
                    amount: _totalSpent,
                  ),
                  _BudgetSummaryItem(
                    icon: Icons.savings,
                    label: 'Remaining',
                    amount: remaining,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% used',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      _buildStatusIndicator(progress),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white38,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getProgressColor(progress),
                      ),
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(double progress) {
    String status;
    Color color;

    if (progress < 0.75) {
      status = 'On track';
      color = Colors.green;
    } else if (progress < 0.9) {
      status = 'Caution';
      color = Colors.orange;
    } else {
      status = 'Over budget';
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    try {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _budgets.length,
        itemBuilder: (context, index) {
          try {
            final budget = _budgets[index];
            if (budget == null || budget.category == null) {
              print("BudgetScreen: Skipping null budget or category at index $index");
              return const SizedBox.shrink();
            }
            
            final spent = _categorySpending[budget.category] ?? 0.0;
            final progress = budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;
            
            return _CategoryBudgetCard(
              category: budget.category,
              budgeted: budget.amount,
              spent: spent,
              progress: progress,
              onTap: () {
                print("BudgetScreen: Category ${budget.category} tapped");
                try {
                  Navigator.pushNamed(
                    context,
                    '/category_detail',
                    arguments: {
                      'category': budget.category,
                      'budget': budget,
                      'spent': spent,
                    },
                  ).then((value) {
                    print("BudgetScreen: Returned from category detail with value: $value");
                    _loadData();
                  });
                } catch (e) {
                  print("BudgetScreen: Error navigating to category detail: $e");
                  _showErrorSnackBar("Navigation error. Please try again.");
                }
              },
            );
          } catch (e) {
            print("BudgetScreen: Error rendering budget at index $index: $e");
            return const SizedBox.shrink();
          }
        },
      );
    } catch (e) {
      print("BudgetScreen: Error building category list: $e");
      return Center(
        child: Text("Error displaying categories: ${e.toString()}"),
      );
    }
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.75) {
      return Colors.green;
    } else if (progress < 0.9) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  void dispose() {
    print("BudgetScreen: Disposing");
    try {
      _budgetService.close();
    } catch (e) {
      print("BudgetScreen: Error closing budget service: $e");
    }
    super.dispose();
  }
}

class _BudgetSummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;

  const _BudgetSummaryItem({
    required this.icon,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'KSh ',
      decimalDigits: 0,
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currencyFormat.format(amount),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _CategoryBudgetCard extends StatelessWidget {
  final String category;
  final double budgeted;
  final double spent;
  final double progress;
  final VoidCallback onTap;

  const _CategoryBudgetCard({
    required this.category,
    required this.budgeted,
    required this.spent,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'KSh ',
      decimalDigits: 0,
    );
    final remaining = budgeted - spent;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(category),
                      color: _getCategoryColor(category),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% of budget used',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(progress),
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAmountInfo('Budgeted', currencyFormat.format(budgeted), Colors.grey[700]!),
                  _buildAmountInfo('Spent', currencyFormat.format(spent), Colors.red),
                  _buildAmountInfo('Remaining', currencyFormat.format(remaining), Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInfo(String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'food & dining':
        return Icons.restaurant;
      case 'transport':
      case 'transportation':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'utilities':
        return Icons.bolt;
      case 'entertainment':
        return Icons.movie;
      case 'rent':
      case 'housing':
        return Icons.home;
      case 'education':
        return Icons.school;
      case 'health':
      case 'healthcare':
        return Icons.medical_services;
      case 'income':
        return Icons.attach_money;
      case 'business':
        return Icons.business;
      case 'personal':
        return Icons.person;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'food & dining':
        return Colors.orange;
      case 'transport':
      case 'transportation':
        return Colors.blue;
      case 'shopping':
        return Colors.purple;
      case 'utilities':
        return Colors.amber;
      case 'entertainment':
        return Colors.pink;
      case 'rent':
      case 'housing':
        return Colors.indigo;
      case 'education':
        return Colors.teal;
      case 'health':
      case 'healthcare':
        return Colors.red;
      case 'income':
        return Colors.green;
      case 'business':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.75) {
      return Colors.green;
    } else if (progress < 0.9) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}