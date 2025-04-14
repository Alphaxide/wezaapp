// lib/services/storage_service.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/mpesa_message.dart';

class StorageService {
  static const String _messagesBoxName = 'mpesa_messages';
  
  // Initialize Hive
  static Future<void> initHive() async {
    // Initialize Hive
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    await Hive.initFlutter();
    
    // Register adapters
    Hive.registerAdapter(MpesaMessageAdapter());
    Hive.registerAdapter(MessageCategoryAdapter());
    
    // Open boxes
    await Hive.openBox<MpesaMessage>(_messagesBoxName);
  }
  
  // Save a message
  Future<void> saveMessage(MpesaMessage message) async {
    final box = Hive.box<MpesaMessage>(_messagesBoxName);
    // Use the message ID as key to prevent duplicates
    await box.put(message.id, message);
  }
  
  // Get all messages
  Future<List<MpesaMessage>> getAllMessages() async {
    final box = Hive.box<MpesaMessage>(_messagesBoxName);
    return box.values.toList();
  }
  
  // Get messages by category
  Future<List<MpesaMessage>> getMessagesByCategory(MessageCategory category) async {
    final box = Hive.box<MpesaMessage>(_messagesBoxName);
    return box.values.where((message) => message.category == category).toList();
  }
  
  // Delete a message
  Future<void> deleteMessage(String id) async {
    final box = Hive.box<MpesaMessage>(_messagesBoxName);
    await box.delete(id);
  }
  
  // Update message category
  Future<void> updateMessageCategory(String id, MessageCategory newCategory) async {
    final box = Hive.box<MpesaMessage>(_messagesBoxName);
    final message = box.get(id);
    
    if (message != null) {
      final updatedMessage = MpesaMessage(
        id: message.id,
        messageBody: message.messageBody,
        timestamp: message.timestamp,
        sender: message.sender,
        category: newCategory,
        amount: message.amount,
        transactionCode: message.transactionCode,
        recipientName: message.recipientName,
        accountNumber: message.accountNumber,
      );
      
      await box.put(id, updatedMessage);
    }
  }
}