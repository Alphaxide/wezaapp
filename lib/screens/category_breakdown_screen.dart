// TODO Implement this library.
// lib/screens/category_breakdown_screen.dart
import 'package:flutter/material.dart';
import '../models/mpesa_message.dart';
import '../services/storage_service.dart';
import '../routes/app_router.dart';

class CategoryBreakdownScreen extends StatefulWidget {
  const CategoryBreakdownScreen({Key? key}) : super(key: key);

  @override
  State<CategoryBreakdownScreen> createState() => _CategoryBreakdownScreenState();
}

class _CategoryBreakdownScreenState extends State<CategoryBreakdownScreen> {
  final StorageService _storageService = StorageService();
  Map<MessageCategory, List<MpesaMessage>> _categorizedMessages = {};
  Map<MessageCategory, double> _categoryTotals = {};
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }
  
  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final messages = await _storageService.getAllMessages();
      final categorizedMessages = <MessageCategory, List<MpesaMessage>>{};
      final categoryTotals = <MessageCategory, double>{};
      
      // Group messages by category
      for (final category in MessageCategory.values) {
        categorizedMessages[category] = [];
        categoryTotals[category] = 0;
      }
      
      for (final message in messages) {
        categorizedMessages[message.category]?.add(message);
        
        // Add to category totals if amount exists
        if (message.amount != null) {
          categoryTotals[message.category] = 
              (categoryTotals[message.category] ?? 0) + message.amount!;
        }
      }
      
      setState(() {
        _categorizedMessages = categorizedMessages;
        _categoryTotals = categoryTotals;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Categories'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: MessageCategory.values.length,
              itemBuilder: (context, index) {
                final category = MessageCategory.values[index];
                final messages = _categorizedMessages[category] ?? [];
                final total = _categoryTotals[category] ?? 0;
                
                // Skip empty categories
                if (messages.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return _buildCategoryCard(category, messages, total);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadCategories,
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildCategoryCard(
    MessageCategory category, 
    List<MpesaMessage> messages,
    double total,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRouter.messagesList,
            arguments: MessageListArgs(
              title: _getCategoryName(category),
              category: category,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getCategoryColor(category).withOpacity(0.2),
                    child: Icon(
                      _getCategoryIcon(category),
                      color: _getCategoryColor(category),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getCategoryName(category),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${messages.length} transaction${messages.length != 1 ? 's' : ''}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (total > 0)
                    Text(
                      'KSh ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
  
  String _getCategoryName(MessageCategory category) {
    switch (category) {
      case MessageCategory.sendMoney:
        return 'Send Money';
      case MessageCategory.receiveMoney:
        return 'Receive Money';
      case MessageCategory.buyGoods:
        return 'Buy Goods';
      case MessageCategory.payBill:
        return 'Pay Bill';
      case MessageCategory.withdrawCash:
        return 'Withdraw Cash';
      case MessageCategory.depositCash:
        return 'Deposit Cash';
      case MessageCategory.balanceInquiry:
        return 'Balance Inquiry';
      case MessageCategory.airtime:
        return 'Airtime';
      case MessageCategory.loan:
        return 'Loan';
      case MessageCategory.subscription:
        return 'Subscription';
      case MessageCategory.unclassified:
        return 'Unclassified';
      default:
        return 'Unknown';
    }
  }
  
  Color _getCategoryColor(MessageCategory category) {
    switch (category) {
      case MessageCategory.sendMoney:
        return Colors.red;
      case MessageCategory.receiveMoney:
        return Colors.green;
      case MessageCategory.buyGoods:
        return Colors.blue;
      case MessageCategory.payBill:
        return Colors.orange;
      case MessageCategory.withdrawCash:
        return Colors.purple;
      case MessageCategory.depositCash:
        return Colors.teal;
      case MessageCategory.balanceInquiry:
        return Colors.indigo;
      case MessageCategory.airtime:
        return Colors.pink;
      case MessageCategory.loan:
        return Colors.amber;
      case MessageCategory.subscription:
        return Colors.brown;
      case MessageCategory.unclassified:
      default:
        return Colors.grey;
    }
  }
  
  IconData _getCategoryIcon(MessageCategory category) {
    switch (category) {
      case MessageCategory.sendMoney:
        return Icons.send;
      case MessageCategory.receiveMoney:
        return Icons.download;
      case MessageCategory.buyGoods:
        return Icons.shopping_cart;
      case MessageCategory.payBill:
        return Icons.receipt;
      case MessageCategory.withdrawCash:
        return Icons.money_off;
      case MessageCategory.depositCash:
        return Icons.savings;
      case MessageCategory.balanceInquiry:
        return Icons.account_balance;
      case MessageCategory.airtime:
        return Icons.phone_android;
      case MessageCategory.loan:
        return Icons.account_balance_wallet;
      case MessageCategory.subscription:
        return Icons.subscriptions;
      case MessageCategory.unclassified:
      default:
        return Icons.help_outline;
    }
  }
}