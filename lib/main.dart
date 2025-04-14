import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:weza/utilitychart.dart";

void main() {
  runApp(const MPesaTrackerApp());
}


class CategoryDetailsScreen extends StatelessWidget {
  final String category;
  final Color categoryColor;
  final IconData categoryIcon;

  const CategoryDetailsScreen({
    Key? key,
    required this.category,
    required this.categoryColor,
    required this.categoryIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Filter transactions for this category
    final categoryTransactions = seedTransactions
        .where((transaction) => transaction.category == category)
        .toList();
    
    // Calculate total amount for this category
    final totalAmount = categoryTransactions.fold(
        0.0, (sum, transaction) => sum + transaction.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text('$category Transactions'),
      ),
      body: Column(
        children: [
          // Category summary card
          Card(
            margin: const EdgeInsets.all(16.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          categoryIcon,
                          color: categoryColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${categoryTransactions.length} transactions',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Spent:',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        'KSh ${NumberFormat('#,###.00').format(totalAmount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Time period filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('Time Period: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: 'All Time',
                  onChanged: (String? newValue) {},
                  items: <String>['All Time', 'This Month', 'Last Month', 'This Year']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // Transactions list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: categoryTransactions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final transaction = categoryTransactions[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getTransactionColor(transaction.type).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getTransactionIcon(transaction.type),
                      color: _getTransactionColor(transaction.type),
                    ),
                  ),
                  title: Text(
                    transaction.recipient,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Ref: ${transaction.reference}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(transaction.date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    'KSh ${NumberFormat('#,###.00').format(transaction.amount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    // Navigate to transaction details
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionDetailsScreen(
                          transaction: transaction,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getTransactionColor(String type) {
    switch (type) {
      case 'receive':
        return Colors.green;
      case 'send':
        return Colors.red;
      case 'paybill':
        return Colors.orange;
      case 'withdraw':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
  
  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'receive':
        return Icons.arrow_downward;
      case 'send':
        return Icons.arrow_upward;
      case 'paybill':
        return Icons.receipt;
      case 'withdraw':
        return Icons.money;
      default:
        return Icons.swap_horiz;
    }
  }
}

// Transaction Labeling System
class TransactionLabeler {
  // Store transaction labeling rules
  static final Map<String, String> _recipientCategoryMap = {
    // Common recipients to categories
    'KPLC': 'Utilities',
    'SAFARICOM': 'Bills',
    'DSTV': 'Entertainment',
    'NAIROBI WATER': 'Utilities',
    'ZUKU': 'Bills',
    'UBER': 'Transport',
    'BOLT': 'Transport',
    'JUMIA': 'Shopping',
    'CARREFOUR': 'Shopping',
    'NAIVAS': 'Shopping',
    'KCB': 'Banking',
    'EQUITY': 'Banking',
    'ABSA': 'Banking',
    'MPESA AGENT': 'Cash',
    'ATM': 'Cash',
    // Add more common Kenya-specific recipients
  };
  
  // Store transaction keyword rules
  static final Map<String, String> _keywordCategoryMap = {
    'electricity': 'Utilities',
    'water': 'Utilities',
    'bill': 'Bills',
    'subscription': 'Entertainment',
    'taxi': 'Transport',
    'matatu': 'Transport',
    'fare': 'Transport',
    'food': 'Food & Dining',
    'restaurant': 'Food & Dining',
    'groceries': 'Shopping',
    'supermarket': 'Shopping',
    'salary': 'Income',
    'payment': 'Income',
    'withdraw': 'Cash',
    'school': 'Education',
    'fees': 'Education',
    'medical': 'Healthcare',
    'hospital': 'Healthcare',
    'pharmacy': 'Healthcare',
    // Add more keywords for Kenya-specific transactions
  };
  
  // Auto-assign category based on recipient and SMS content
  static String suggestCategory(String recipient, String smsContent, String transactionType) {
    // First check if recipient is directly in our map
    String recipientUpper = recipient.toUpperCase();
    
    // Direct recipient match
    for (var entry in _recipientCategoryMap.entries) {
      if (recipientUpper.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Check for keywords in SMS content
    String smsLower = smsContent.toLowerCase();
    for (var entry in _keywordCategoryMap.entries) {
      if (smsLower.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Default categories based on transaction type
    switch (transactionType) {
      case 'receive':
        return 'Income';
      case 'send':
        return 'Friends & Family';
      case 'paybill':
        return 'Bills';
      case 'withdraw':
        return 'Cash';
      default:
        return 'Other';
    }
  }
  
  // Method to learn from user categorizations
  static void learnFromUserCategorization(String recipient, String category) {
    // Add this categorization to our map for future suggestions
    _recipientCategoryMap[recipient.toUpperCase()] = category;
  }
  
  // Parse M-Pesa SMS to extract transaction details
  static Map<String, dynamic>? parseMpesaSms(String smsContent) {
    try {
      // Common patterns in M-Pesa SMS messages
      smsContent = smsContent.toUpperCase();
      
      // Determine transaction type
      String transactionType;
      if (smsContent.contains('YOU HAVE RECEIVED')) {
        transactionType = 'receive';
      } else if (smsContent.contains('YOU HAVE SENT')) {
        transactionType = 'send';
      } else if (smsContent.contains('PAID TO')) {
        transactionType = 'paybill';
      } else if (smsContent.contains('WITHDRAW') || smsContent.contains('DEBITED')) {
        transactionType = 'withdraw';
      } else {
        transactionType = 'other';
      }
      
      // Extract amount 
      final amountRegex = RegExp(r'KSH([\d,]+)');
      final amountMatch = amountRegex.firstMatch(smsContent);
      String? amountStr = amountMatch?.group(1)?.replaceAll(',', '');
      double amount = amountStr != null ? double.parse(amountStr) : 0;
      
      // Extract recipient/sender based on transaction type
      String recipient = '';
      if (transactionType == 'receive') {
        final fromRegex = RegExp(r'FROM\s+([A-Z0-9\s]+)\s+ON');
        final fromMatch = fromRegex.firstMatch(smsContent);
        recipient = fromMatch?.group(1)?.trim() ?? 'Unknown';
      } else if (transactionType == 'send') {
        final toRegex = RegExp(r'TO\s+([A-Z0-9\s]+)\s+ON');
        final toMatch = toRegex.firstMatch(smsContent);
        recipient = toMatch?.group(1)?.trim() ?? 'Unknown';
      } else if (transactionType == 'paybill') {
        final toRegex = RegExp(r'TO\s+([A-Z0-9\s]+)\.');
        final toMatch = toRegex.firstMatch(smsContent);
        recipient = toMatch?.group(1)?.trim() ?? 'Unknown';
      }
      
      // Extract reference if any (usually for paybill)
      String reference = '';
      final refRegex = RegExp(r'REF.\s+([A-Z0-9]+)');
      final refMatch = refRegex.firstMatch(smsContent);
      if (refMatch != null) {
        reference = refMatch.group(1) ?? '';  
      }
      
      // Try to extract date and time
      DateTime date = DateTime.now();
      
      // Determine category based on extracted info
      String category = suggestCategory(recipient, smsContent, transactionType);
      
      return {
        'type': transactionType,
        'amount': amount,
        'recipient': recipient,
        'reference': reference,
        'date': date,
        'category': category,
        'description': _generateDescription(transactionType, recipient),
      };
    } catch (e) {
      print('Error parsing SMS: $e');
      return null;
    }
  }
  
  static String _generateDescription(String transactionType, String recipient) {
    switch (transactionType) {
      case 'receive':
        return 'Received from $recipient';
      case 'send':
        return 'Sent to $recipient';
      case 'paybill':
        return 'Paid to $recipient';
      case 'withdraw':
        return 'Withdrawal';
      default:
        return 'Transaction with $recipient';
    }
  }
}

// SMS Labeling Screen
class TransactionLabelingScreen extends StatefulWidget {
  final String smsContent;
  final Map<String, dynamic>? parsedData;

  const TransactionLabelingScreen({
    Key? key, 
    required this.smsContent,
    this.parsedData,
  }) : super(key: key);

  @override
  State<TransactionLabelingScreen> createState() => _TransactionLabelingScreenState();
}

class _TransactionLabelingScreenState extends State<TransactionLabelingScreen> {
  late TextEditingController _amountController;
  late TextEditingController _recipientController;
  late TextEditingController _referenceController;
  late TextEditingController _descriptionController;
  String _selectedCategory = 'Other';
  String _transactionType = 'other';
  DateTime _transactionDate = DateTime.now();
  bool _isAutoLabeled = false;
  
  final List<String> _categories = [
    'Income',
    'Food & Dining',
    'Transport',
    'Utilities',
    'Entertainment',
    'Shopping',
    'Bills',
    'Education',
    'Healthcare',
    'Family',
    'Friends',
    'Cash',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize with parsed data if available or default values
    if (widget.parsedData != null) {
      _amountController = TextEditingController(text: widget.parsedData!['amount'].toString());
      _recipientController = TextEditingController(text: widget.parsedData!['recipient']);
      _referenceController = TextEditingController(text: widget.parsedData!['reference']);
      _descriptionController = TextEditingController(text: widget.parsedData!['description']);
      _selectedCategory = widget.parsedData!['category'];
      _transactionType = widget.parsedData!['type'];
      _transactionDate = widget.parsedData!['date'];
      _isAutoLabeled = true;
    } else {
      _amountController = TextEditingController();
      _recipientController = TextEditingController();
      _referenceController = TextEditingController();
      _descriptionController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    _referenceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Label Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original SMS
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.message, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'Original SMS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        if (_isAutoLabeled)
                          Chip(
                            label: const Text('Auto-labeled'),
                            backgroundColor: Colors.green.withOpacity(0.2),
                            avatar: const Icon(Icons.auto_awesome, color: Colors.green, size: 16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(widget.smsContent),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Transaction type
            const Text(
              'Transaction Type',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TransactionTypeChip(
                    label: 'Money In',
                    type: 'receive',
                    selected: _transactionType == 'receive',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _transactionType = 'receive';
                        });
                      }
                    },
                  ),
                  _TransactionTypeChip(
                    label: 'Money Out',
                    type: 'send',
                    selected: _transactionType == 'send',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _transactionType = 'send';
                        });
                      }
                    },
                  ),
                  _TransactionTypeChip(
                    label: 'Bill Payment',
                    type: 'paybill',
                    selected: _transactionType == 'paybill',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _transactionType = 'paybill';
                        });
                      }
                    },
                  ),
                  _TransactionTypeChip(
                    label: 'Withdrawal',
                    type: 'withdraw',
                    selected: _transactionType == 'withdraw',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _transactionType = 'withdraw';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Transaction details
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaction Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (KSh)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.monetization_on),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _recipientController,
                      decoration: const InputDecoration(
                        labelText: 'Recipient/Sender',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Reference Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.confirmation_number),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Category selection
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Category',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _categories.map((category) {
                        return ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Date and time selection
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date & Time',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(_transactionDate),
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        // Show date-time picker
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _transactionDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        
                        if (pickedDate != null) {
                          // Show time picker
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_transactionDate),
                          );
                          
                          if (pickedTime != null) {
                            setState(() {
                              _transactionDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Create transaction with current data
                  final newTransaction = Transaction(
                    id: 'TX${DateTime.now().millisecondsSinceEpoch}',
                    type: _transactionType,
                    recipient: _recipientController.text,
                    amount: double.tryParse(_amountController.text) ?? 0,
                    date: _transactionDate,
                    description: _descriptionController.text,
                    category: _selectedCategory,
                    reference: _referenceController.text,
                  );
                  
                  // Learn from this categorization for future auto-labeling
                  TransactionLabeler.learnFromUserCategorization(
                    _recipientController.text, 
                    _selectedCategory
                  );
                  
                  // Return the new transaction to the caller
                  Navigator.pop(context, newTransaction);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTypeChip extends StatelessWidget {
  final String label;
  final String type;
  final bool selected;
  final Function(bool)? onSelected;

  const _TransactionTypeChip({
    required this.label,
    required this.type,
    this.selected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColorForType(type);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        selectedColor: color.withOpacity(0.2),
        checkmarkColor: color,
        avatar: Icon(
          _getIconForType(type),
          color: selected ? color : Colors.grey,
          size: 18,
        ),
      ),
    );
  }
  
  Color _getColorForType(String type) {
    switch (type) {
      case 'receive':
        return Colors.green;
      case 'send':
        return Colors.red;
      case 'paybill':
        return Colors.orange;
      case 'withdraw':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
  
  IconData _getIconForType(String type) {
    switch (type) {
      case 'receive':
        return Icons.arrow_downward;
      case 'send':
        return Icons.arrow_upward;
      case 'paybill':
        return Icons.receipt;
      case 'withdraw':
        return Icons.money;
      default:
        return Icons.swap_horiz;
    }
  }
}

class MPesaTrackerApp extends StatelessWidget {
  const MPesaTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weza',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A86B), // M-Pesa green
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class Transaction {
  final String id;
  final String type; // send, receive, paybill, etc.
  final String recipient;
  final double amount;
  final DateTime date;
  final String description;
  final String category;
  final String reference;

  Transaction({
    required this.id,
    required this.type,
    required this.recipient,
    required this.amount,
    required this.date,
    required this.description,
    required this.category,
    required this.reference,
  });
}


String autoLabelCategory(String recipient, String description, String type) {
  recipient = recipient.toLowerCase();
  description = description.toLowerCase();
  
  // Utility companies
  if (recipient.contains('kplc') || 
      recipient.contains('kenya power') || 
      description.contains('electricity')) {
    return 'Utilities';
  }
  
  if (recipient.contains('safaricom') || 
      recipient.contains('airtel') || 
      recipient.contains('telkom') ||
      description.contains('airtime') ||
      description.contains('data bundle')) {
    return 'Telecommunications';
  }
  
  if (recipient.contains('water') || 
      description.contains('water bill')) {
    return 'Utilities';
  }
  
  // Transportation
  if (recipient.contains('uber') || 
      recipient.contains('bolt') || 
      recipient.contains('little') ||
      description.contains('taxi') ||
      description.contains('fare') ||
      description.contains('transport')) {
    return 'Transport';
  }
  
  // Food and shopping
  if (recipient.contains('supermarket') || 
      recipient.contains('market') || 
      recipient.contains('shop') ||
      recipient.contains('store')) {
    return 'Shopping';
  }
  
  if (recipient.contains('restaurant') || 
      recipient.contains('cafe') || 
      recipient.contains('food') ||
      description.contains('lunch') ||
      description.contains('dinner')) {
    return 'Food & Dining';
  }
  
  // Default categories based on transaction type
  if (type == 'receive') {
    return 'Income';
  }
  
  if (type == 'withdraw') {
    return 'Cash';
  }
  
  // Default
  return 'Other';
}


// Seed data
final List<Transaction> seedTransactions = [
  Transaction(
    id: 'QJL7HPIHX2',
    type: 'send',
    recipient: 'John Doe',
    amount: 1500,
    date: DateTime.now().subtract(const Duration(hours: 2)),
    description: 'Sent to John Doe',
    category: 'Friends',
    reference: 'Lunch payment',
  ),
  Transaction(
    id: 'QJL7HPIHX3',
    type: 'receive',
    recipient: 'Mary Smith',
    amount: 2000,
    date: DateTime.now().subtract(const Duration(days: 1)),
    description: 'Received from Mary Smith',
    category: 'Income',
    reference: 'Project payment',
  ),
  Transaction(
    id: 'QJL7HPIHX4',
    type: 'paybill',
    recipient: 'KPLC',
    amount: 1200,
    date: DateTime.now().subtract(const Duration(days: 2)),
    description: 'Paid to KPLC',
    category: 'Utilities',
    reference: 'Electricity bill',
  ),

  Transaction(
    id: 'QJL7HPIHX6',
    type: 'paybill',
    recipient: 'KPLC',
    amount: 1200,
    date: DateTime.now().subtract(const Duration(days: 2)),
    description: 'Paid to KPLC',
    category: 'Utilities',
    reference: 'Electricity bill',
  ),
  Transaction(
    id: 'QJL7HPIHX5',
    type: 'withdraw',
    recipient: 'ATM',
    amount: 3000,
    date: DateTime.now().subtract(const Duration(days: 3)),
    description: 'Withdrawal',
    category: 'Cash',
    reference: 'Weekend expenses',
  ),
  Transaction(
    id: 'QJL7HPIHX6',
    type: 'paybill',
    recipient: 'Safaricom',
    amount: 1000,
    date: DateTime.now().subtract(const Duration(days: 5)),
    description: 'Paid to Safaricom',
    category: 'Bills',
    reference: 'Phone bill',
  ),
  Transaction(
    id: 'QJL7HPIHX7',
    type: 'send',
    recipient: 'James Kamau',
    amount: 500,
    date: DateTime.now().subtract(const Duration(days: 7)),
    description: 'Sent to James Kamau',
    category: 'Family',
    reference: 'Transport',
  ),
  Transaction(
    id: 'QJL7HPIHX8',
    type: 'receive',
    recipient: 'Employer',
    amount: 35000,
    date: DateTime.now().subtract(const Duration(days: 15)),
    description: 'Received from Employer',
    category: 'Salary',
    reference: 'April Salary',
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const DashboardScreen(),
    const TransactionsScreen(),
    const BudgetScreen(),
    const TransactionAnalysisScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.tab),
            label: 'Analysis',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate total money in and out
    double totalIn = seedTransactions
        .where((t) => t.type == 'receive')
        .fold(0, (total, t) => total + t.amount);
    
    double totalOut = seedTransactions
        .where((t) => t.type != 'receive')
        .fold(0, (total, t) => total + t.amount);
    
    // Get recent transactions
    final recentTransactions = seedTransactions.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weza'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Balance',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'KSh ${NumberFormat('#,###.00').format(totalIn - totalOut)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Money In/Out Cards
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 2,
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
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_downward,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Money In',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'KSh ${NumberFormat('#,###.00').format(totalIn)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      elevation: 2,
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
                                    color: Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_upward,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Money Out',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'KSh ${NumberFormat('#,###.00').format(totalOut)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Recent Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('See All'),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Recent Transaction List
              Card(
                elevation: 2,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentTransactions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final transaction = recentTransactions[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getTransactionColor(transaction.type).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getTransactionIcon(transaction.type),
                          color: _getTransactionColor(transaction.type),
                        ),
                      ),
                      title: Text(transaction.recipient),
                      subtitle: Text(
                        DateFormat('dd MMM, HH:mm').format(transaction.date),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        '${transaction.type == 'receive' ? '+' : '-'} KSh ${NumberFormat('#,###.00').format(transaction.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: transaction.type == 'receive' ? Colors.green : Colors.red,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Spending by Category
              const Text(
                'Spending by Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Sample category bars
                      _CategoryProgressBar(
                        category: 'Utilities',
                        amount: 1200,
                        percentage: 30,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      _CategoryProgressBar(
                        category: 'Bills',
                        amount: 1000,
                        percentage: 25,
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 16),
                      _CategoryProgressBar(
                        category: 'Cash',
                        amount: 3000,
                        percentage: 45,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Color _getTransactionColor(String type) {
    switch (type) {
      case 'receive':
        return Colors.green;
      case 'send':
        return Colors.red;
      case 'paybill':
        return Colors.orange;
      case 'withdraw':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
  
  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'receive':
        return Icons.arrow_downward;
      case 'send':
        return Icons.arrow_upward;
      case 'paybill':
        return Icons.receipt;
      case 'withdraw':
        return Icons.money;
      default:
        return Icons.swap_horiz;
    }
  }
}

class _CategoryProgressBar extends StatelessWidget {
  final String category;
  final double amount;
  final int percentage;
  final Color color;

  const _CategoryProgressBar({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'KSh ${NumberFormat('#,###.00').format(amount)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Container(
              height: 8,
              width: MediaQuery.of(context).size.width * percentage / 100,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$percentage%',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Transaction filter tabs
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(label: 'All', selected: true),
                  _FilterChip(label: 'Sent'),
                  _FilterChip(label: 'Received'),
                  _FilterChip(label: 'Bills'),
                  _FilterChip(label: 'Withdrawals'),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: seedTransactions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final transaction = seedTransactions[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getTransactionColor(transaction.type).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getTransactionIcon(transaction.type),
                      color: _getTransactionColor(transaction.type),
                    ),
                  ),
                  title: Text(
                    transaction.description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Ref: ${transaction.reference}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(transaction.date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${transaction.type == 'receive' ? '+' : '-'} KSh ${NumberFormat('#,###.00').format(transaction.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: transaction.type == 'receive' ? Colors.green : Colors.red,
                    ),
                  ),
                 onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => TransactionDetailsScreen(
        transaction: transaction,
      ),
    ),
  );
},

                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Show dialog to paste SMS or request SMS permission
          _showSmsInputDialog(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
    );
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'receive':
        return Colors.green;
      case 'send':
        return Colors.red;
      case 'paybill':
        return Colors.orange;
      case 'withdraw':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'receive':
        return Icons.arrow_downward;
      case 'send':
        return Icons.arrow_upward;
      case 'paybill':
        return Icons.receipt;
      case 'withdraw':
        return Icons.money;
      default:
        return Icons.swap_horiz;
    }
  }

  void _showSmsInputDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String smsText = '';
        return AlertDialog(
          title: const Text('Add Transaction from SMS'),
          content: TextField(
            maxLines: 4,
            onChanged: (value) => smsText = value,
            decoration: const InputDecoration(
              hintText: 'Paste your transaction SMS here...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Parse and save the transaction from smsText
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  _FilterChip({
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        checkmarkColor: Theme.of(context).colorScheme.primary,
        label: Text(label),
        selected: selected,
        onSelected: (bool value) {},
      ),
    );
  }
}

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Monthly budget overview
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'April 2025',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Budget',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'KSh 45,000.00',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Spent',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'KSh 27,200.00',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Remaining',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'KSh 17,800.00',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '60% of budget used',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Category budgets
            const Text(
              'Category Budgets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Category budget cards
          // In the BudgetScreen class, modify your _CategoryBudgetCard
// to navigate to the CategoryDetailsScreen when tapped
// Category budget cards
_CategoryBudgetCard(
  category: 'Food & Dining',
  budgeted: 15000,
  spent: 12300,
  color: Colors.orange,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailsScreen(
          category: 'Food & Dining',
          categoryColor: Colors.orange,
          categoryIcon: Icons.restaurant,
        ),
      ),
    );
  },
),

const SizedBox(height: 16),

_CategoryBudgetCard(
  category: 'Utilities',
  budgeted: 8000,
  spent: 6500,
  color: Colors.blue,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailsScreen(
          category: 'Utilities',
          categoryColor: Colors.blue,
          categoryIcon: Icons.bolt,
        ),
      ),
    );
  },
),

const SizedBox(height: 16),

_CategoryBudgetCard(
  category: 'Transport',
  budgeted: 12000,
  spent: 5400,
  color: Colors.green,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailsScreen(
          category: 'Transport',
          categoryColor: Colors.green,
          categoryIcon: Icons.directions_car,
        ),
      ),
    );
  },
),
            
            const SizedBox(height: 16),
            
            const SizedBox(height: 16),
            
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('View All Categories'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _CategoryBudgetCard extends StatelessWidget {
  final String category;
  final double budgeted;
  final double spent;
  final Color color;
  final VoidCallback onTap;

  const _CategoryBudgetCard({
    required this.category,
    required this.budgeted,
    required this.spent,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (spent / budgeted * 100).clamp(0, 100).toInt();
    
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
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
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(category),
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'KSh ${NumberFormat('#,###.00').format(spent)} of KSh ${NumberFormat('#,###.00').format(budgeted)}',
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getPercentageColor(percentage),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: spent / budgeted,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(_getPercentageColor(percentage)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant;
      case 'Utilities':
        return Icons.bolt;
      case 'Transport':
        return Icons.directions_car;
      case 'Entertainment':
        return Icons.movie;
      default:
        return Icons.category;
    }
  }
  
  Color _getPercentageColor(int percentage) {
    if (percentage < 50) {
      return Colors.green;
    } else if (percentage < 75) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant;
      case 'Utilities':
        return Icons.bolt;
      case 'Transport':
        return Icons.directions_car;
      case 'Entertainment':
        return Icons.movie;
      default:
        return Icons.category;
    }
  }
  
  Color _getPercentageColor(int percentage) {
    if (percentage < 50) {
      return Colors.green;
    } else if (percentage < 75) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile avatar and info
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Color(0xFF00A86B),
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'John Mwangi',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'john.mwangi@example.com',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Settings list
            Card(
              elevation: 2,
              child: Column(
                children: [
                  const _SettingsTile(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                  ),
                  const Divider(height: 1),
                  const _SettingsTile(
                    icon: Icons.attach_money,
                    title: 'Budget Settings',
                    subtitle: 'Set monthly budgets and alerts',
                  ),
                  const Divider(height: 1),
                  const _SettingsTile(
                    icon: Icons.category,
                    title: 'Categories',
                    subtitle: 'Customize transaction categories',
                  ),
                  const Divider(height: 1),
                  const _SettingsTile(
                    icon: Icons.file_download,
                    title: 'Export Data',
                    subtitle: 'Download transactions as CSV or PDF',
                  ),
                  const Divider(height: 1),
                  const _SettingsTile(
                    icon: Icons.security,
                    title: 'Security',
                    subtitle: 'Set app lock and privacy settings',
                  ),
                  const Divider(height: 1),
                  const _SettingsTile(
                    icon: Icons.sync,
                    title: 'SMS Sync Settings',
                    subtitle: 'Configure automatic M-Pesa SMS sync',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // App Info
            Card(
              elevation: 2,
              child: Column(
                children: [
                  const _SettingsTile(
                    icon: Icons.info,
                    title: 'About App',
                    subtitle: 'Version 1.0.0',
                  ),
                  const Divider(height: 1),
                  const _SettingsTile(
                    icon: Icons.help,
                    title: 'Help & Support',
                    subtitle: 'Get assistance with the app',
                  ),
                  const Divider(height: 1),
                  const _SettingsTile(
                    icon: Icons.star,
                    title: 'Rate the App',
                    subtitle: 'Share your feedback',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Logout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}

// New SMS Message Parsing Screen
class SmsParseScreen extends StatelessWidget {
  const SmsParseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Sync'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'M-Pesa SMS Messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // SMS permission status card
            Card(
              elevation: 2,
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SMS Permission Granted',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'App will automatically sync M-Pesa messages',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // SMS sync settings
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sync Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Auto-sync new messages'),
                      subtitle: const Text('Sync messages as they arrive'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    SwitchListTile(
                      title: const Text('Parse transaction details'),
                      subtitle: const Text('Extract amount, reference, and category'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    SwitchListTile(
                      title: const Text('Sync historical messages'),
                      subtitle: const Text('Fetch past M-Pesa messages'),
                      value: false,
                      onChanged: (value) {},
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Recent SMS messages
            const Text(
              'Recent Messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: Card(
                elevation: 2,
                child: ListView(
                  children: [
                    _SmsMessageTile(
                      message: 'MPESA confirmation. KCB5XXXX confirmed. You have received Ksh2,000 from MARY SMITH on 11/4/25 at 10:23 AM. New M-PESA balance is Ksh15,320.00.',
                      parsed: true,
                      date: DateTime.now().subtract(const Duration(hours: 1)),
                    ),
                    const Divider(height: 1),
                    _SmsMessageTile(
                      message: 'MPESA confirmation. KCB5XXXX confirmed. You have sent Ksh1,500 to JOHN DOE on 11/4/25 at 8:45 AM. New M-PESA balance is Ksh13,320.00.',
                      parsed: true,
                      date: DateTime.now().subtract(const Duration(hours: 3)),
                    ),
                    const Divider(height: 1),
                    _SmsMessageTile(
                      message: 'MPESA confirmation. KCB5XXXX confirmed. Ksh1,200 paid to KPLC PREPAID. on 9/4/25 at 5:13 PM. Ref. AB123456. New M-PESA balance is Ksh14,820.00.',
                      parsed: true,
                      date: DateTime.now().subtract(const Duration(days: 2)),
                    ),
                    const Divider(height: 1),
                    _SmsMessageTile(
                      message: 'Your M-PESA account was debited with Ksh3,000 on 8/4/25 at 2:30 PM. Use PIN at ATM to withdraw. New M-PESA balance is Ksh16,020.00.',
                      parsed: true,
                      date: DateTime.now().subtract(const Duration(days: 3)),
                    ),
                    const Divider(height: 1),
                    _SmsMessageTile(
                      message: 'MPESA confirmation. KCB5XXXX confirmed. Ksh1,000 paid to SAFARICOM. on 6/4/25 at 9:05 AM. Ref. XY987654. New M-PESA balance is Ksh19,020.00.',
                      parsed: true,
                      date: DateTime.now().subtract(const Duration(days: 5)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Manual Sync',
        child: const Icon(Icons.sync),
      ),
    );
  }
}

class _SmsMessageTile extends StatelessWidget {
  final String message;
  final bool parsed;
  final DateTime date;

  const _SmsMessageTile({
    required this.message,
    required this.parsed,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.all(16.0),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: parsed ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          parsed ? Icons.check_circle : Icons.warning,
          color: parsed ? Colors.green : Colors.orange,
        ),
      ),
      title: Text(
        message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Text(
          DateFormat('dd MMM yyyy, HH:mm').format(date),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ),
      trailing: parsed
          ? const Icon(Icons.check, color: Colors.green)
          : TextButton(
              onPressed: () {},
              child: const Text('Parse'),
            ),
      onTap: () {},
    );
  }
}

// Add Transaction Screen
class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction type selector
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaction Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _TransactionTypeButton(
                            title: 'Send',
                            icon: Icons.arrow_upward,
                            color: Colors.red,
                            selected: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TransactionTypeButton(
                            title: 'Receive',
                            icon: Icons.arrow_downward,
                            color: Colors.green,
                            selected: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TransactionTypeButton(
                            title: 'Paybill',
                            icon: Icons.receipt,
                            color: Colors.orange,
                            selected: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Transaction details form
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaction Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Amount (KSh)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Recipient/Sender',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Reference/Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      value: 'Income',
                      items: [
                        'Income',
                        'Food & Dining',
                        'Transport',
                        'Utilities',
                        'Entertainment',
                        'Shopping',
                        'Family',
                        'Friends',
                        'Other',
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {},
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () {
                        // Show date picker
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date & Time',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // SMS message (optional)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SMS Message (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add),
                          label: const Text('Add SMS'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const TextField(
                      decoration: InputDecoration(
                        hintText: 'Paste M-Pesa SMS message here for automatic parsing...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save Transaction'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTypeButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool selected;

  const _TransactionTypeButton({
    required this.title,
    required this.icon,
    required this.color,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: selected ? color : Colors.grey,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? color : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: selected ? color : Colors.grey,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Transaction Details Screen
class TransactionDetailsScreen extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailsScreen({
    Key? key,
    required this.transaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction header
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getTransactionColor(transaction.type).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getTransactionIcon(transaction.type),
                        color: _getTransactionColor(transaction.type),
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${transaction.type == 'receive' ? '+' : '-'} KSh ${NumberFormat('#,###.00').format(transaction.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        color: transaction.type == 'receive' ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getTransactionTypeTitle(transaction.type),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Transaction details
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _DetailRow(
                      title: 'Date & Time',
                      value: DateFormat('dd MMM yyyy, HH:mm').format(transaction.date),
                      icon: Icons.calendar_today,
                    ),
                    const Divider(),
                    _DetailRow(
                      title: 'Recipient/Sender',
                      value: transaction.recipient,
                      icon: Icons.person,
                    ),
                    const Divider(),
                    _DetailRow(
                      title: 'Reference',
                      value: transaction.reference,
                      icon: Icons.description,
                    ),
                    const Divider(),
                    _DetailRow(
                      title: 'Category',
                      value: transaction.category,
                      icon: Icons.category,
                    ),
                    const Divider(),
                    _DetailRow(
                      title: 'Transaction ID',
                      value: transaction.id,
                      icon: Icons.confirmation_number,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Original SMS message
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Original SMS Message',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getSampleSmsText(transaction),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.receipt),
                    label: const Text('Export'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getTransactionColor(String type) {
    switch (type) {
      case 'receive':
        return Colors.green;
      case 'send':
        return Colors.red;
      case 'paybill':
        return Colors.orange;
      case 'withdraw':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
  
  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'receive':
        return Icons.arrow_downward;
      case 'send':
        return Icons.arrow_upward;
      case 'paybill':
        return Icons.receipt;
      case 'withdraw':
        return Icons.money;
      default:
        return Icons.swap_horiz;
    }
  }
  
  String _getTransactionTypeTitle(String type) {
    switch (type) {
      case 'receive':
        return 'Money Received';
      case 'send':
        return 'Money Sent';
      case 'paybill':
        return 'Bill Payment';
      case 'withdraw':
        return 'Withdrawal';
      default:
        return 'Transaction';
    }
  }
  
  String _getSampleSmsText(Transaction transaction) {
    switch (transaction.type) {
      case 'receive':
        return 'MPESA confirmation. KCB5XXXX confirmed. You have received Ksh${transaction.amount} from ${transaction.recipient} on ${DateFormat('dd/MM/yy').format(transaction.date)} at ${DateFormat('hh:mm a').format(transaction.date)}. New M-PESA balance is Ksh15,320.00.';
      case 'send':
        return 'MPESA confirmation. KCB5XXXX confirmed. You have sent Ksh${transaction.amount} to ${transaction.recipient} on ${DateFormat('dd/MM/yy').format(transaction.date)} at ${DateFormat('hh:mm a').format(transaction.date)}. New M-PESA balance is Ksh13,820.00.';
      case 'paybill':
        return 'MPESA confirmation. KCB5XXXX confirmed. Ksh${transaction.amount} paid to ${transaction.recipient}. on ${DateFormat('dd/MM/yy').format(transaction.date)} at ${DateFormat('hh:mm a').format(transaction.date)}. Ref. ${transaction.reference}. New M-PESA balance is Ksh14,820.00.';
      case 'withdraw':
        return 'Your M-PESA account was debited with Ksh${transaction.amount} on ${DateFormat('dd/MM/yy').format(transaction.date)} at ${DateFormat('hh:mm a').format(transaction.date)}. Use PIN at ATM to withdraw. New M-PESA balance is Ksh12,820.00.';
      default:
        return 'MPESA transaction of Ksh${transaction.amount} on ${DateFormat('dd/MM/yy').format(transaction.date)} at ${DateFormat('hh:mm a').format(transaction.date)}. Ref: ${transaction.reference}.';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}