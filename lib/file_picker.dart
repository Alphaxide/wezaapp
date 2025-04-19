import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:weza/storage/storage_provider.dart';
import '../models/mpesa_message.dart';
import '../utils/category_helper.dart';
import '../service/budget_service.dart';
import 'package:weza/utils/mpesa_parser.dart';

class MessageParserScreen extends StatefulWidget {
  const MessageParserScreen({Key? key}) : super(key: key);

  @override
  State<MessageParserScreen> createState() => _MessageParserScreenState();
}

class _MessageParserScreenState extends State<MessageParserScreen> {
  final TextEditingController _messagesController = TextEditingController();
  final BudgetService _budgetService = BudgetService();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = false;
  bool _isParsed = false;
  List<MpesaMessage> _parsedMessages = [];
  Map<String, double> _categoryTotals = {};
  double _totalAmount = 0.0;
  int _successCount = 0;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeBudgetService();
  }

  Future<void> _initializeBudgetService() async {
    await _budgetService.initialize();
  }

  @override
  void dispose() {
    _messagesController.dispose();
    _scrollController.dispose();
    _budgetService.close();
    super.dispose();
  }

  Future<void> _parseMessages() async {
    if (_messagesController.text.isEmpty) {
      _showSnackBar('Please paste some messages first');
      return;
    }

    setState(() {
      _isLoading = true;
      _isParsed = false;
      _parsedMessages = [];
      _categoryTotals = {};
      _totalAmount = 0.0;
      _successCount = 0;
      _failedCount = 0;
    });

    try {
      // Parse the entire text as a whole
      String messageText = _messagesController.text;
      
      try {
        // Parse the full message text
        MpesaMessage parsedMessage = MpesaParser.parseSms(messageText);
        if (parsedMessage.amount > 0) {
          _parsedMessages.add(parsedMessage);
          _successCount++;
          
          // Update category totals
          String category = parsedMessage.category;
          double amount = parsedMessage.amount;
          
          // For outgoing transactions, make the amount negative
          if (parsedMessage.direction == 'Outgoing') {
            amount = -amount;
          }
          
          _categoryTotals.update(
            category, 
            (value) => value + amount, 
            ifAbsent: () => amount
          );
          
          // Update total amount
          _totalAmount += amount;
        } else {
          _failedCount++;
        }
      } catch (e) {
        _failedCount++;
        _showSnackBar('Failed to parse message: ${e.toString()}');
      }
      
      // Sort transactions by date (newest first)
      _parsedMessages.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      
      setState(() {
        _isParsed = true;
        _isLoading = false;
      });
      
      if (_successCount > 0) {
        _showSnackBar('Successfully parsed $_successCount messages');
      } else {
        _showSnackBar('No valid messages found. Please check the format.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error parsing messages: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _messagesController.clear();
      _parsedMessages = [];
      _categoryTotals = {};
      _totalAmount = 0.0;
      _isParsed = false;
      _successCount = 0;
      _failedCount = 0;
    });
  }

Future<int> _insertMpesaTransaction(MpesaMessage message) async {
  // Use the message storage provider to insert the message
  final storage = MessageStorageProvider().getStorage();
  return await storage.insertMessage(message);
}

Future<int> _saveMpesaTransactions(List<MpesaMessage> messages) async {
  int savedCount = 0;
  for (MpesaMessage message in messages) {
    await _insertMpesaTransaction(message);
    savedCount++;
  }
  return savedCount;
}

Future<void> _saveTransactions() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Save all transactions using our new function
    int savedCount = await _saveMpesaTransactions(_parsedMessages);
    
    setState(() {
      _isLoading = false;
    });
    
    _showSnackBar('Successfully saved $savedCount transactions!');
    
    // Clear the screen after saving
    _clearAll();
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
    _showSnackBar('Error saving transactions: ${e.toString()}');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Import M-Pesa Messages',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 22,
            fontFamily: 'Poppins',
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isParsed)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              onPressed: _saveTransactions,
              tooltip: 'Save Transactions',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _clearAll,
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 36.0, top: 24.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.85),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import M-Pesa Messages',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Paste your M-Pesa SMS message below to analyze and categorize it',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: !_isParsed 
                ? _buildInputSection()
                : _buildResultsSection(),
            ),
          ],
        ),
      ),
      floatingActionButton: !_isParsed 
        ? FloatingActionButton.extended(
            onPressed: _parseMessages,
            icon: const Icon(Icons.auto_graph),
            label: const Text(
              'Parse Message',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            elevation: 4,
            backgroundColor: Theme.of(context).primaryColor,
          )
        : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Paste M-Pesa Message',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Copy the message from your SMS app and paste it below',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _messagesController,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Paste your M-Pesa message here...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 70), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            Text(
              'Category Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildCategoryBreakdown(),
            const SizedBox(height: 24),
            Text(
              'Transactions (${_parsedMessages.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ..._parsedMessages.map((message) => _buildTransactionCard(message)).toList(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _totalAmount >= 0 
                ? [const Color(0xFF4CAF50), const Color(0xFF388E3C)]
                : [const Color(0xFFF44336), const Color(0xFFD32F2F)],
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
                  const Text(
                    'Summary',
                    style: TextStyle(
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
                      '${_parsedMessages.length} transactions',
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
                  _SummaryItem(
                    icon: Icons.arrow_downward,
                    label: 'Income',
                    amount: _parsedMessages
                        .where((msg) => msg.direction == 'Incoming')
                        .fold(0.0, (sum, item) => sum + item.amount),
                    isPositive: true,
                  ),
                  _SummaryItem(
                    icon: Icons.arrow_upward,
                    label: 'Expenses',
                    amount: _parsedMessages
                        .where((msg) => msg.direction == 'Outgoing')
                        .fold(0.0, (sum, item) => sum + item.amount),
                    isPositive: false,
                  ),
                  _SummaryItem(
                    icon: Icons.account_balance_wallet,
                    label: 'Net',
                    amount: _totalAmount,
                    isPositive: _totalAmount >= 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    // Sort categories by amount (absolute value)
    List<MapEntry<String, double>> sortedCategories = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return Column(
      children: sortedCategories.map((entry) {
        final category = entry.key;
        final amount = entry.value;
        final isPositive = amount >= 0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
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
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  'Ksh ${amount.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isPositive ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTransactionCard(MpesaMessage message) {
    final isIncoming = message.direction == 'Incoming';
    final amountColor = isIncoming ? Colors.green[700] : Colors.red[700];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
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
                    color: _getCategoryColor(message.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(message.category),
                    color: _getCategoryColor(message.category),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.senderOrReceiverName.isEmpty ? message.transactionType : message.senderOrReceiverName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.transactionType,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncoming ? "+" : "-"}Ksh ${message.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: amountColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(message.transactionDate),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (message.account.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Account: ${message.account}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    message.transactionCode,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${_formatTime(date)}';
  }

  String _formatTime(DateTime date) {
    String hour = (date.hour > 12) ? (date.hour - 12).toString() : date.hour.toString();
    if (hour == '0') hour = '12';
    String minute = date.minute.toString().padLeft(2, '0');
    String period = (date.hour >= 12) ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
      case 'food':
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
      case 'salary':
        return Icons.attach_money;
      case 'business':
        return Icons.business;
      case 'transfer':
        return Icons.swap_horiz;
      case 'withdrawal':
        return Icons.money_off;
      case 'deposit':
        return Icons.savings;
      case 'loan':
        return Icons.account_balance;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
      case 'food':
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
      case 'salary':
        return Colors.green;
      case 'business':
        return Colors.blueGrey;
      case 'transfer':
        return Colors.cyan;
      case 'withdrawal':
        return Colors.deepOrange;
      case 'deposit':
        return Colors.lightGreen;
      case 'loan':
        return Colors.brown;
      case 'investment':
        return Colors.lightBlue;
      default:
        return Colors.grey;
    }
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final bool isPositive;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.amount,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
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
          'Ksh ${amount.abs().toStringAsFixed(2)}',
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