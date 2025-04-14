// lib/services/sms_service.dart
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models.dart';
import 'message_classifier.dart';
import 'storage_service.dart';

class SMSService {
  final SmsQuery _query = SmsQuery();
  final StorageService _storageService = StorageService();
  
  // MPESA sender IDs
  static const List<String> mpesaSenders = ['MPESA', 'SAFARICOM'];
  
  // Request SMS permissions
  Future<bool> requestSmsPermission() async {
    var status = await Permission.sms.status;
    
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }
    
    return status.isGranted;
  }
  
  // Fetch all M-Pesa SMS messages
  Future<List<MpesaMessage>> fetchMpesaSMS() async {
    // Ensure we have permissions
    final hasPermission = await requestSmsPermission();
    if (!hasPermission) {
      throw Exception('SMS permission not granted');
    }
    
    // Fetch all SMS messages from M-Pesa senders
    final messages = <MpesaMessage>[];
    
    for (final sender in mpesaSenders) {
      final smsMessages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        address: sender,
      );
      
      for (final sms in smsMessages) {
        final mpesaMessage = MpesaMessage.fromSMS(
          sms.body ?? '',
          sms.address ?? '',
          sms.date ?? DateTime.now(),
        );
        
        // Classify the message
        final classifiedMessage = MessageClassifier.classifyMpesaMessage(mpesaMessage);
        
        // Save the message
        await _storageService.saveMessage(classifiedMessage);
        
        messages.add(classifiedMessage);
      }
    }
    
    return messages;
  }
  
  // Get all saved M-Pesa messages
  Future<List<MpesaMessage>> getAllSavedMessages() {
    return _storageService.getAllMessages();
  }
  
  // Get messages by category
  Future<List<MpesaMessage>> getMessagesByCategory(MessageCategory category) {
    return _storageService.getMessagesByCategory(category);
  }
}