import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:weza/storage/storage_provider.dart';
import 'package:weza/utils/mpesa_parser.dart';
import 'package:weza/models/mpesa_message.dart';

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
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SmsQuery _query = SmsQuery();
  Timer? _smsCheckTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeSmsListener();
  }
  
  @override
  void dispose() {
    _smsCheckTimer?.cancel();
    super.dispose();
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
  
  DateTime? _lastCheckedTime;
  
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
    return MaterialApp(
      title: 'Weza App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weza M-Pesa Tracker'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'M-Pesa SMS Monitor Active',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              'The app is now listening for M-Pesa messages',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}