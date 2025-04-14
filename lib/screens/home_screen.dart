// TODO Implement this library.
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../models/mpesa_message.dart';
import '../services/sms_service.dart';
import '../routes/app_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SMSService _smsService = SMSService();
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('M-Pesa SMS Analyzer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, AppRouter.settings);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Header section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Track and categorize your M-Pesa transactions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Main actions
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildActionCard(
                    'All Messages',
                    Icons.message,
                    Colors.blue,
                    () => Navigator.pushNamed(
                      context, 
                      AppRouter.messagesList,
                      arguments: MessageListArgs(title: 'All Messages'),
                    ),
                  ),
                  _buildActionCard(
                    'Categories',
                    Icons.category,
                    Colors.orange,
                    () => Navigator.pushNamed(context, AppRouter.categoryBreakdown),
                  ),
                  _buildActionCard(
                    'Send Money',
                    Icons.send,
                    Colors.green,
                    () => Navigator.pushNamed(
                      context, 
                      AppRouter.messagesList,
                      arguments: MessageListArgs(
                        title: 'Send Money', 
                        category: MessageCategory.sendMoney,
                      ),
                    ),
                  ),
                  _buildActionCard(
                    'Receive Money',
                    Icons.download,
                    Colors.purple,
                    () => Navigator.pushNamed(
                      context, 
                      AppRouter.messagesList,
                      arguments: MessageListArgs(
                        title: 'Received Money', 
                        category: MessageCategory.receiveMoney,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchMessages,
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _smsService.fetchMpesaSMS();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messages refreshed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching messages: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}