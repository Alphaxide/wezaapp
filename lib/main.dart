import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:weza/storage/storage_provider.dart';
import 'package:weza/utils/mpesa_parser.dart';
import 'package:weza/models/mpesa_message.dart';

// SMS message handler for when app is in foreground
void onMessageReceived(SmsMessage message) async {
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

  // Initialize telephony
  final telephony = Telephony.instance;
  
  // Set up periodic SMS checking
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    await checkForMpesaMessages(telephony);
  });
  
  // Initial check
  await checkForMpesaMessages(telephony);
}

Future<void> checkForMpesaMessages(Telephony telephony) async {
  try {
    final messages = await telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      filter: SmsFilter.where(SmsColumn.DATE)
          .greaterThan(DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch.toString()),
    );
    
    for (var message in messages) {
      if (_isMpesaMessage(message.body ?? "")) {
        // Initialize storage
        final storage = getStorageImplementation();
        await storage.initialize();
        
        // Parse the M-Pesa message
        final mpesaMessage = MpesaParser.parseSms(message.body ?? "");
        
        // Store the parsed message if it doesn't exist
        // You might want to check here if this message is already processed
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
  final Telephony telephony = Telephony.instance;
  
  @override
  void initState() {
    super.initState();
    _initializeSmsListener();
  }
  
  Future<void> _initializeSmsListener() async {
    // Request SMS permissions
    final permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    
    if (permissionsGranted ?? false) {
      // Listen for incoming SMS in foreground
      telephony.listenIncomingSms(
        onNewMessage: onMessageReceived,
        listenInBackground: true,
      );
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