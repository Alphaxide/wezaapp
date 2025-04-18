import 'package:flutter/material.dart';
import "package:intl/intl.dart";
import "package:weza/addbudget_screen.dart";
import "package:weza/budgetscreenui.dart";
import "package:weza/file_picker.dart";
import "package:weza/models/mpesa_message.dart";
import "package:weza/storage/mpesa_storage.dart";
import "package:weza/storage/storage_provider.dart";
import "package:weza/utilitychart.dart";
import 'package:flutter/services.dart';
import 'package:weza/utils/mpesa_parser.dart';
import 'dart:async';
import 'service/budget_service.dart';
import 'storage/storage_provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

// SMS message handler for when a new M-Pesa message is detected
void onMpesaMessageReceived(SmsMessage message) async {
  // Check if the message is from M-Pesa
  if (_isMpesaMessage(message.body ?? "")) {
    // Initialize storage
    final storage = getStorageImplementation();
    await storage.initialize();
    
    // Parse the M-Pesa message
    final mpesaMessage = MpesaParser.parseSms(message.body ?? "");
    
    // Store the parsed message
    await storage.insertMessage(mpesaMessage);
  }
}

// Check if a message is from M-Pesa
bool _isMpesaMessage(String message) {
  // Common M-Pesa message keywords
  final mpesaKeywords = [
    'M-PESA', 'MPESA', 'confirmed', 'transaction', 'sent to',
    'received', 'withdrawn', 'paid to', 'Buy Goods',
    'Safaricom', 'Paybill', 'Till Number'
  ];
  
  message = message.toUpperCase();
  return mpesaKeywords.any((keyword) => message.contains(keyword.toUpperCase()));
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'weza_foreground',
    'Weza Foreground Service',
    description: 'Listens for M-Pesa messages',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'weza_foreground',
      initialNotificationTitle: 'Weza M-Pesa Listener',
      initialNotificationContent: 'Monitoring M-Pesa messages',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Initialize SMS query plugin
  final SmsQuery query = SmsQuery();
  
  // Set up periodic SMS checking
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    await checkForMpesaMessages(query);
  });
  
  // Initial check
  await checkForMpesaMessages(query);
}

Future<void> checkForMpesaMessages(SmsQuery query) async {
  try {
    // Get messages from the last hour
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    final messages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 20, // Limit to recent messages
    );
    
    final recentMessages = messages.where(
      (message) => message.date != null && 
                   message.date!.isAfter(oneHourAgo)
    );
    
    for (var message in recentMessages) {
      if (_isMpesaMessage(message.body ?? "")) {
        // Initialize storage
        final storage = getStorageImplementation();
        await storage.initialize();
        
        // Parse the M-Pesa message
        final mpesaMessage = MpesaParser.parseSms(message.body ?? "");
        
        // Store the parsed message if it doesn't exist
        await storage.insertMessage(mpesaMessage);
        
        // Close storage connection
        await storage.close();
      }
    }
  } catch (e) {
    print('Error checking for M-Pesa messages: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request permissions
  await [
    Permission.sms,
    Permission.notification,
  ].request();
  
  // Initialize background service
  await initializeBackgroundService();
  
  // Initialize storage for the main app
  final storage = getStorageImplementation();
  await storage.initialize();
  
  runApp(const MPesaTrackerApp());
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final SmsQuery _query = SmsQuery();
  Timer? _smsCheckTimer;
  DateTime? _lastCheckedTime;
  
  final List<Widget> _screens = [
    const DashboardScreen(),
    const TransactionsScreen(),
    const BudgetScreen(),
    const TransactionAnalysisScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSmsListener();
  }
  
  @override
  void dispose() {
    _smsCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground, check for new messages
      _checkForNewMessages();
    }
  }
  
  Future<void> _initializeSmsListener() async {
    // Request SMS permissions
    final status = await Permission.sms.request();
    
    if (status.isGranted) {
      // Since flutter_sms_inbox doesn't have a listener for new messages,
      // we'll poll for new messages periodically
      _smsCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        await _checkForNewMessages();
      });
      
      // Do an immediate check
      await _checkForNewMessages();
    }
  }
  
  Future<void> _checkForNewMessages() async {
    final now = DateTime.now();
    final checkFrom = _lastCheckedTime ?? now.subtract(const Duration(minutes: 2));
    _lastCheckedTime = now;
    
    try {
      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 10,
      );
      
      // Filter for messages that came after our last check
      final newMessages = messages.where(
        (message) => message.date != null && 
                    message.date!.isAfter(checkFrom)
      );
      
      for (var message in newMessages) {
        onMpesaMessageReceived(message);
      }
    } catch (e) {
      print('Error checking for new messages: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            backgroundColor: Colors.white,
            elevation: 0,
            height: 68,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            animationDuration: const Duration(milliseconds: 400),
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.dashboard_outlined, 
                  color: Colors.grey[600],
                ),
                selectedIcon: Icon(
                  Icons.dashboard_rounded,
                  color: primaryColor,
                ),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.receipt_long_outlined, 
                  color: Colors.grey[600],
                ),
                selectedIcon: Icon(
                  Icons.receipt_long_rounded,
                  color: primaryColor,
                ),
                label: 'Transactions',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.pie_chart_outline_rounded, 
                  color: Colors.grey[600],
                ),
                selectedIcon: Icon(
                  Icons.pie_chart_rounded,
                  color: primaryColor,
                ),
                label: 'Budget',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.analytics_outlined, 
                  color: Colors.grey[600],
                ),
                selectedIcon: Icon(
                  Icons.analytics_rounded,
                  color: primaryColor,
                ),
                label: 'Analysis',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<MpesaMessage>> _messagesFuture;
  late MessageStorage _storage;
  
  @override
  void initState() {
    super.initState();
    _storage = getStorageImplementation();
    _messagesFuture = _loadMessages();
  }
  
  Future<List<MpesaMessage>> _loadMessages() async {
    await _storage.initialize();
    return await _storage.getAllMessages();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MpesaMessage>>(
      future: _messagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        
        final messages = snapshot.data ?? [];
        return _buildDashboard(context, messages);
      },
    );
  }
  
  Widget _buildDashboard(BuildContext context, List<MpesaMessage> messages) {
    // Get current month data
    final now = DateTime.now();
    final currentMonthMessages = messages.where((msg) => 
      msg.transactionDate.month == now.month && 
      msg.transactionDate.year == now.year
    ).toList();
    
    // Calculate total expenses for current month
    final monthlyExpenses = currentMonthMessages
      .where((msg) => msg.direction == 'Outgoing')
      .fold(0.0, (total, msg) => total + msg.amount);
    
    // Calculate money in for the month
    final monthlyIncome = currentMonthMessages
      .where((msg) => msg.direction == 'Incoming')
      .fold(0.0, (total, msg) => total + msg.amount);
    
    // Get top 3 categories by spending
    final categorySpending = <String, double>{};
    for (final msg in currentMonthMessages) {
      if (msg.direction == 'Outgoing') {
        categorySpending[msg.category] = (categorySpending[msg.category] ?? 0) + msg.amount;
      }
    }
    
    final topCategories = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final top3Categories = topCategories.take(3).toList();
    
    // Get recent transactions
    final recentTransactions = currentMonthMessages
      .take(4)
      .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Weza',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 22,
            fontFamily: 'Poppins',
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              // Month selector functionality would go here
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly Expenses Header
              Container(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 36.0, top: 8.0),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Month Expenses',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(now),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'KSh ${NumberFormat('#,###.00').format(monthlyExpenses)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 36,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          monthlyExpenses > 0 ? '+4.2%' : '-2.1%',
                          style: TextStyle(
                            fontSize: 14,
                            color: monthlyExpenses > 0 ? Colors.red.shade300 : Colors.green.shade300,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Money In/Out Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        color: Colors.white,
                        child: Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Colors.green,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Money In',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'KSh ${NumberFormat('#,###.00').format(monthlyIncome)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
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
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        color: Colors.white,
                        child: Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.red,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Money Out',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'KSh ${NumberFormat('#,###.00').format(monthlyExpenses)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Recent Transactions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TransactionsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('See All'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Recent Transaction List
              if (recentTransactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      'No transactions found for this month',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: Colors.white,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentTransactions.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          indent: 76,
                          endIndent: 20,
                          thickness: 0.5,
                        ),
                        itemBuilder: (context, index) {
                          final transaction = recentTransactions[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getTransactionColor(transaction.transactionType).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                _getTransactionIcon(transaction.transactionType),
                                color: _getTransactionColor(transaction.transactionType),
                                size: 24,
                              ),
                            ),
                            title: Text(
                              transaction.senderOrReceiverName.isNotEmpty ? 
                                transaction.senderOrReceiverName : transaction.transactionType,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                DateFormat('dd MMM, HH:mm').format(transaction.transactionDate),
                                style: TextStyle(
                                  fontSize: 13, 
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            trailing: Text(
                              '${transaction.direction == 'Incoming' ? '+' : '-'} KSh ${NumberFormat('#,###.00').format(transaction.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: transaction.direction == 'Incoming' ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 32),
              
              // Top Categories
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: const Text(
                  'Top Spending Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Top Categories visualization
              if (top3Categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      'No spending categories found for this month',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: Colors.white,
                    child: Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          ...top3Categories.asMap().entries.map((entry) {
                            final index = entry.key;
                            final category = entry.value.key;
                            final amount = entry.value.value;
                            final percentage = (amount / monthlyExpenses * 100).round();
                            
                            // Assign different colors to each category
                            final colors = [
                              const Color(0xFF4E6AF3),
                              const Color(0xFF9C5DE0),
                              const Color(0xFFF5A623),
                            ];
                            
                            final icons = [
                              Icons.shopping_cart,
                              Icons.receipt_long,
                              Icons.account_balance_wallet,
                            ];
                            
                            return Column(
                              children: [
                                _CategoryProgressBar(
                                  category: category,
                                  amount: amount,
                                  percentage: percentage,
                                  color: colors[index % colors.length],
                                  icon: _getCategoryIcon(category) ?? icons[index % icons.length],
                                ),
                                if (index < top3Categories.length - 1)
                                  const SizedBox(height: 20),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 90), // Extra padding for bottom navigation
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
  
  Color _getTransactionColor(String transactionType) {
    switch (transactionType) {
      case 'Receive Money':
      case 'Deposit':
        return Colors.green;
      case 'Send Money':
      case 'Buy Goods':
      case 'PayBill':
      case 'Withdraw Cash':
      case 'ATM Withdrawal':
        return Colors.red;
      case 'Buy Airtime':
        return Colors.blue;
      case 'Loan Disbursement':
        return Colors.purple;
      case 'Loan Repayment':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getTransactionIcon(String transactionType) {
    switch (transactionType) {
      case 'Receive Money':
        return Icons.arrow_downward_rounded;
      case 'Send Money':
        return Icons.arrow_upward_rounded;
      case 'Buy Goods':
        return Icons.shopping_cart;
      case 'PayBill':
        return Icons.receipt;
      case 'Withdraw Cash':
        return Icons.account_balance;
      case 'ATM Withdrawal':
        return Icons.atm;
      case 'Buy Airtime':
        return Icons.phone_android;
      case 'Deposit':
        return Icons.payments;
      case 'Loan Disbursement':
        return Icons.monetization_on;
      case 'Loan Repayment':
        return Icons.money_off;
      default:
        return Icons.swap_horiz;
    }
  }
  
  IconData? _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_car;
      case 'Shopping':
        return Icons.shopping_cart;
      case 'Utilities':
        return Icons.bolt;
      case 'Entertainment':
        return Icons.movie;
      case 'Rent':
        return Icons.home;
      case 'Education':
        return Icons.school;
      case 'Health':
        return Icons.local_hospital;
      case 'Income':
        return Icons.account_balance_wallet;
      case 'Business':
        return Icons.business;
      default:
        return null;
    }
  }
  
  @override
  void dispose() {
    _storage.close();
    super.dispose();
  }
}

class _CategoryProgressBar extends StatelessWidget {
  final String category;
  final double amount;
  final int percentage;
  final Color color;
  final IconData icon;

  const _CategoryProgressBar({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Text(
              'KSh ${NumberFormat('#,###').format(amount)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  color: color,
                  minHeight: 10,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$percentage%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late Future<List<MpesaMessage>> _messagesFuture;
  late MessageStorage _storage;
  String _selectedFilter = 'All';
  
  @override
  void initState() {
    super.initState();
    _storage = getStorageImplementation();
    _messagesFuture = _loadMessages();
  }
  
  Future<List<MpesaMessage>> _loadMessages() async {
    await _storage.initialize();
    final messages = await _storage.getAllMessages();
    
    // Sort by transaction date (most recent first)
    messages.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    
    return messages;
  }
  
  List<MpesaMessage> _filterMessages(List<MpesaMessage> messages) {
    if (_selectedFilter == 'All') {
      return messages;
    } else if (_selectedFilter == 'Incoming') {
      return messages.where((msg) => msg.direction == 'Incoming').toList();
    } else if (_selectedFilter == 'Outgoing') {
      return messages.where((msg) => msg.direction == 'Outgoing').toList();
    } else {
      // Filter by transaction type if not a direction filter
      return messages.where((msg) => msg.transactionType == _selectedFilter).toList();
    }
  }

  // Helper method to get monthly summaries
  Map<String, double> _getMonthSummaries(List<MpesaMessage> messages) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    
    // Filter transactions for current month
    final thisMonthMessages = messages.where((msg) {
      final msgDate = DateTime(msg.transactionDate.year, msg.transactionDate.month);
      return msgDate.isAtSameMomentAs(currentMonth);
    }).toList();
    
    // Calculate totals
    double totalAmount = 0;
    double incomingAmount = 0;
    double outgoingAmount = 0;
    
    for (final msg in thisMonthMessages) {
      if (msg.direction == 'Incoming') {
        incomingAmount += msg.amount;
      } else {
        outgoingAmount += msg.amount;
      }
      totalAmount += msg.amount;
    }
    
    return {
      'total': totalAmount,
      'in': incomingAmount,
      'out': outgoingAmount,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Transactions',
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
      ),
      body: FutureBuilder<List<MpesaMessage>>(
        future: _messagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final messages = snapshot.data ?? [];
          
          if (messages.isEmpty) {
            return const Center(
              child: Text('No transactions found', style: TextStyle(color: Colors.grey)),
            );
          }
          
          // Calculate month summaries
          final monthlySummaries = _getMonthSummaries(messages);
          
          // Get unique transaction types for filter
          final transactionTypes = ['All', 'Incoming', 'Outgoing'];
          final uniqueTypes = messages
              .map((msg) => msg.transactionType)
              .toSet()
              .toList();
          transactionTypes.addAll(uniqueTypes);
          
          final filteredMessages = _filterMessages(messages);
          
          return SafeArea(
            child: Column(
              children: [
                // Gradient header extension with transaction summaries
                Container(
                  padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0, top: 8.0),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TransactionSummaryItem(
                        label: 'This Month',
                        amount: monthlySummaries['total'] ?? 0.0,
                        icon: Icons.swap_horiz_rounded,
                        color: Colors.white,
                      ),
                      _TransactionSummaryItem(
                        label: 'In',
                        amount: monthlySummaries['in'] ?? 0.0,
                        icon: Icons.arrow_downward_rounded,
                        color: Colors.green.shade300,
                      ),
                      _TransactionSummaryItem(
                        label: 'Out',
                        amount: monthlySummaries['out'] ?? 0.0,
                        icon: Icons.arrow_upward_rounded,
                        color: Colors.red.shade300,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Transaction filter tabs with improved styling
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: transactionTypes.map((type) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            selected: _selectedFilter == type,
                            label: Text(type),
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = type;
                              });
                            },
                            selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                            checkmarkColor: Theme.of(context).primaryColor,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: _selectedFilter == type
                                    ? Theme.of(context).primaryColor.withOpacity(0.5)
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Section header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: const Text('This Month'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Transactions list with improved UI
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: filteredMessages.isEmpty
                            ? const Center(
                                child: Text(
                                  'No transactions match the selected filter',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: filteredMessages.length,
                                separatorBuilder: (context, index) => const Divider(
                                  height: 1,
                                  indent: 76,
                                  endIndent: 20,
                                  thickness: 0.5,
                                ),
                                itemBuilder: (context, index) {
                                  final transaction = filteredMessages[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    leading: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _getTransactionColor(transaction.transactionType).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        _getTransactionIcon(transaction.transactionType),
                                        color: _getTransactionColor(transaction.transactionType),
                                        size: 24,
                                      ),
                                    ),
                                    title: Text(
                                      transaction.senderOrReceiverName.isNotEmpty ? 
                                        transaction.senderOrReceiverName : transaction.transactionType,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        if (transaction.account.isNotEmpty)
                                          Text(
                                            'Acc: ${transaction.account}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                        if (transaction.account.isNotEmpty)
                                          const SizedBox(height: 2),
                                        Text(
                                          DateFormat('dd MMM yyyy, HH:mm').format(transaction.transactionDate),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Text(
                                      '${transaction.direction == 'Incoming' ? '+' : '-'} KSh ${NumberFormat('#,###.00').format(transaction.amount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: transaction.direction == 'Incoming' ? Colors.green[700] : Colors.red[700],
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
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'Receive Money':
      case 'Deposit':
        return Colors.green[700]!;
      case 'Send Money':
        return Colors.red[700]!;
      case 'PayBill':
        return const Color(0xFFF5A623); // Warmer orange
      case 'Withdraw Cash':
      case 'ATM Withdrawal':
        return const Color(0xFF9C5DE0); // Refined purple
      case 'Buy Goods':
        return Colors.blue[700]!;
      case 'Buy Airtime':
        return Colors.teal[700]!;
      case 'Loan Disbursement':
        return Colors.green[800]!;
      case 'Loan Repayment':
        return Colors.orange[800]!;
      case 'Reversal':
        return Colors.indigo[700]!;
      default:
        return const Color(0xFF4E6AF3); // More appealing blue
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'Receive Money':
        return Icons.arrow_downward_rounded;
      case 'Send Money':
        return Icons.arrow_upward_rounded;
      case 'PayBill':
        return Icons.receipt_long_rounded;
      case 'Withdraw Cash':
      case 'ATM Withdrawal':
        return Icons.account_balance_wallet_rounded;
      case 'Buy Goods':
        return Icons.shopping_cart_rounded;
      case 'Buy Airtime':
        return Icons.phone_android_rounded;
      case 'Deposit':
        return Icons.payments_rounded;
      case 'Loan Disbursement':
        return Icons.monetization_on_rounded;
      case 'Loan Repayment':
        return Icons.money_off_csred_rounded;
      case 'Reversal':
        return Icons.restore_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }
  
  @override
  void dispose() {
    _storage.close();
    super.dispose();
  }
}

class _TransactionSummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _TransactionSummaryItem({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon, 
            color: color, 
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'KSh ${NumberFormat('#,###.00').format(amount)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
// Transaction Details Screen
class TransactionDetailsScreen extends StatelessWidget {
  final MpesaMessage transaction;

  const TransactionDetailsScreen({
    Key? key,
    required this.transaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Transaction Details',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // Transaction amount with icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(transaction.direction).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  transaction.direction == 'Incoming' 
                      ? Icons.arrow_downward_rounded 
                      : Icons.arrow_upward_rounded,
                  color: _getStatusColor(transaction.direction),
                  size: 36,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Amount
              Text(
                '${transaction.direction == 'Incoming' ? '+' : '-'} KSh ${NumberFormat('#,###.00').format(transaction.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                  color: _getStatusColor(transaction.direction),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Transaction type
              Text(
                transaction.transactionType,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              
              const SizedBox(height: 6),
              
              // Date
              Text(
                DateFormat('dd MMM yyyy, HH:mm').format(transaction.transactionDate),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Details card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.white,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Status row
                      _detailRow(
                        'Status',
                        'Completed',
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                      const SizedBox(height: 20),
                      
                      // Transaction code row
                      _detailRow(
                        'Transaction ID',
                        transaction.transactionCode,
                        Icons.confirmation_number_outlined,
                        Colors.blue,
                      ),
                      const SizedBox(height: 20),
                      
                      // Sender/Receiver row
                      _detailRow(
                        transaction.direction == 'Incoming' ? 'From' : 'To',
                        transaction.senderOrReceiverName.isNotEmpty 
                            ? transaction.senderOrReceiverName 
                            : 'Not specified',
                        Icons.person_outline,
                        Colors.indigo,
                      ),
                      
                      if (transaction.phoneNumber.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        // Phone number
                        _detailRow(
                          'Phone',
                          transaction.phoneNumber,
                          Icons.phone,
                          Colors.teal,
                        ),
                      ],
                      
                      if (transaction.account.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        // Account number
                        _detailRow(
                          'Account',
                          transaction.account,
                          Icons.account_balance_outlined,
                          Colors.amber[800]!,
                        ),
                      ],
                      
                      if (transaction.transactionCost > 0) ...[
                        const SizedBox(height: 20),
                        // Transaction cost
                        _detailRow(
                          'Transaction Fee',
                          'KSh ${NumberFormat('#,###.00').format(transaction.transactionCost)}',
                          Icons.attach_money,
                          Colors.orange,
                        ),
                      ],
                      
                      if (transaction.usedFuliza) ...[
                        const SizedBox(height: 20),
                        // Fuliza amount
                        _detailRow(
                          'Fuliza Used',
                          'KSh ${NumberFormat('#,###.00').format(transaction.fulizaAmount)}',
                          Icons.account_balance_wallet_outlined,
                          Colors.purple,
                        ),
                      ],
                      

                      const SizedBox(height: 20),
                      // Category
                      _detailRow(
                        'Category',
                        transaction.category,
                        Icons.category_outlined,
                        Colors.blue[800]!,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Original message card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.white,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Original Message',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        transaction.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String direction) {
    return direction == 'Incoming' ? Colors.green[700]! : Colors.red[700]!;
  }
}

