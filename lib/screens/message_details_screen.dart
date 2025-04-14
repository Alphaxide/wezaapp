// TODO Implement this library.
// lib/screens/message_details_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/mpesa_message.dart';
import '../services/storage_service.dart';

class MessageDetailsScreen extends StatefulWidget {
  final String messageId;
  
  const MessageDetailsScreen({
    Key? key,
    required this.messageId,
  }) : super(key: key);

  @override
  State<MessageDetailsScreen> createState() => _MessageDetailsScreenState();
}

class _MessageDetailsScreenState extends State<MessageDetailsScreen> {
  final StorageService _storageService = StorageService();
  MpesaMessage? _message;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadMessage();
  }
  
  Future<void> _loadMessage() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final box = Hive.box<MpesaMessage>('mpesa_messages');
      final message = box.get(widget.messageId);
      
      setState(() {
        _message = message;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading message: ${e.toString()}')),
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
        title: const Text('Transaction Details'),
        actions: [
          if (_message != null)
            PopupMenuButton<MessageCategory>(
              onSelected: (category) {
                _updateCategory(category);
              },
              itemBuilder: (BuildContext context) {
                return MessageCategory.values.map((category) {
                  return PopupMenuItem<MessageCategory>(
                    value: category,
                    child: Text(_getCategoryName(category)),
                  );
                }).toList();
              },
              icon: const Icon(Icons.category),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _message == null
              ? const Center(child: Text('Message not found'))
              : _buildMessageDetails(),
    );
  }
  
  Widget _buildMessageDetails() {
    if (_message == null) return const SizedBox.shrink();
    
    final dateFormat = DateFormat('MMM d, yyyy HH:mm:ss');
    final formattedDate = dateFormat.format(_message!.timestamp);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transaction card
          Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Align(
                    alignment: Alignment.topRight,
                    child: Chip(
                      label: Text(_getCategoryName(_message!.category)),
                      backgroundColor: _getCategoryColor(_message!.category),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Amount
                  if (_message!.amount != null) ...[
                    Text(
                      'KSh ${_message!.amount!.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Transaction details
                  _buildDetailRow('Date', formattedDate),
                  if (_message!.transactionCode != null)
                    _buildDetailRow('Reference', _message!.transactionCode!),
                  if (_message!.recipientName != null)
                    _buildDetailRow('Recipient', _message!.recipientName!),
                  if (_message!.accountNumber != null)
                    _buildDetailRow('Account', _message!.accountNumber!),
                ],
              ),
            ),
          ),
          
          // Original message
          const Text(
            'Original Message',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Text(_message!.messageBody),
            ),
          ),
          
          // Delete button
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete, color: Colors.white),
              label: const Text('Delete Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
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
  
  Future<void> _updateCategory(MessageCategory newCategory) async {
    if (_message == null) return;
    
    try {
      await _storageService.updateMessageCategory(_message!.id, newCategory);
      
      // Reload the message
      await _loadMessage();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating category: ${e.toString()}')),
      );
    }
  }
  
  Future<void> _confirmDelete() async {
    if (_message == null) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (result == true) {
      try {
        await _storageService.deleteMessage(_message!.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted successfully')),
        );
        
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting message: ${e.toString()}')),
        );
      }
    }
  }
}