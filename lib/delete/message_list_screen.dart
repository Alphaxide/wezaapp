// lib/screens/messages_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mpesa_message.dart';
import '../services/sms_service.dart';
import '../routes/app_router.dart';

class MessagesListScreen extends StatefulWidget {
  final MessageCategory? category;
  final String title;
  
  const MessagesListScreen({
    Key? key,
    this.category,
    required this.title,
  }) : super(key: key);

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  final SMSService _smsService = SMSService();
  List<MpesaMessage> _messages = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadMessages();
  }
  
  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (widget.category != null) {
        _messages = await _smsService.getMessagesByCategory(widget.category!);
      } else {
        _messages = await _smsService.getAllSavedMessages();
      }
      
      // Sort by date (newest first)
      _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading messages: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? const Center(child: Text('No messages found'))
              : ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageItem(message);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadMessages,
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildMessageItem(MpesaMessage message) {
    final dateFormat = DateFormat('MMM d, y HH:mm');
    final formattedDate = dateFormat.format(message.timestamp);
    
    // Choose icon based on category
    IconData categoryIcon;
    Color categoryColor;
    
    switch (message.category) {
      case MessageCategory.sendMoney:
        categoryIcon = Icons.send;
        categoryColor = Colors.red;
        break;
      case MessageCategory.receiveMoney:
        categoryIcon = Icons.download;
        categoryColor = Colors.green;
        break;
      case MessageCategory.buyGoods:
        categoryIcon = Icons.shopping_cart;
        categoryColor = Colors.blue;
        break;
      case MessageCategory.payBill:
        categoryIcon = Icons.receipt;
        categoryColor = Colors.orange;
        break;
      case MessageCategory.withdrawCash:
        categoryIcon = Icons.money_off;
        categoryColor = Colors.purple;
        break;
      case MessageCategory.depositCash:
        categoryIcon = Icons.savings;
        categoryColor = Colors.teal;
        break;
      default:
        categoryIcon = Icons.message;
        categoryColor = Colors.grey;
        break;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: categoryColor.withOpacity(0.2),
          child: Icon(categoryIcon, color: categoryColor),
        ),
        title: Text(
          message.amount != null 
              ? 'KSh ${message.amount!.toStringAsFixed(2)}'
              : 'M-Pesa Transaction',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.transactionCode != null) 
              Text('Ref: ${message.transactionCode}'),
            Text(formattedDate, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRouter.messageDetails,
            arguments: message.id,
          );
        },
      ),
    );
  }
}