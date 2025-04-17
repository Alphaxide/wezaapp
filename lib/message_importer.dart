// lib/utils/mpesa_importer.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import '../models/mpesa_message.dart';
import '../storage/mpesa_storage.dart';
import '../storage/storage_provider.dart';
import '../utils/mpesa_parser.dart';

class MpesaImporter {
  final MessageStorage _messageStorage;
  
  MpesaImporter({MessageStorage? messageStorage}) 
      : _messageStorage = messageStorage ?? getStorageImplementation();
  
  /// Initialize the storage
  Future<void> initialize() async {
    await _messageStorage.initialize();
  }
  
  /// Import M-Pesa messages from a JSON file
  /// Returns the number of successfully imported messages
  Future<int> importFromJsonFile() async {
    try {
      // Use file picker to select JSON file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result == null || result.files.isEmpty) {
        return 0; // User canceled the picker
      }
      
      String content;
      if (kIsWeb) {
        // For web, read the file content directly from picked file bytes
        final bytes = result.files.first.bytes;
        if (bytes == null) return 0;
        content = utf8.decode(bytes);
      } else {
        // For mobile/desktop, read from the file path
        final path = result.files.first.path;
        if (path == null) return 0;
        final file = File(path);
        content = await file.readAsString();
      }
      
      return await _parseAndSaveMessages(content);
    } catch (e) {
      print('Error importing M-Pesa messages: $e');
      return 0;
    }
  }
  
  /// Import M-Pesa messages from an asset file
  /// Useful for pre-loading data or testing
  Future<int> importFromAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      return await _parseAndSaveMessages(content);
    } catch (e) {
      print('Error importing M-Pesa messages from asset: $e');
      return 0;
    }
  }
  
  /// Parse the JSON content and save messages to storage
  Future<int> _parseAndSaveMessages(String jsonContent) async {
    try {
      final jsonData = json.decode(jsonContent);
      final messages = jsonData['mpesa_messages'] as List;
      int importedCount = 0;
      
      for (var messageData in messages) {
        try {
          // Check if it's raw message text or a structured message
          if (messageData['raw_message'] == true) {
            final message = messageData['message'] as String;
            final parsedMessage = MpesaParser.parseSms(message);
            await _messageStorage.insertMessage(parsedMessage);
            importedCount++;
          } else {
            // Handle structured messages (already parsed)
            final parsedMessage = MpesaMessage(
              transactionCode: messageData['transactionCode'] ?? '',
              transactionType: messageData['transactionType'] ?? '',
              senderOrReceiverName: messageData['senderOrReceiverName'] ?? '',
              phoneNumber: messageData['phoneNumber'] ?? '',
              amount: (messageData['amount'] ?? 0.0) is int 
                  ? (messageData['amount'] as int).toDouble() 
                  : messageData['amount'] ?? 0.0,
              balance: (messageData['balance'] ?? 0.0) is int 
                  ? (messageData['balance'] as int).toDouble() 
                  : messageData['balance'] ?? 0.0,
              account: messageData['account'] ?? '',
              message: messageData['message'] ?? '',
              transactionDate: messageData['transactionDate'] != null 
                  ? DateTime.parse(messageData['transactionDate'])
                  : DateTime.now(),
              category: messageData['category'] ?? 'Uncategorized',
              direction: messageData['direction'] ?? '',
              transactionCost: (messageData['transactionCost'] ?? 0.0) is int 
                  ? (messageData['transactionCost'] as int).toDouble() 
                  : messageData['transactionCost'] ?? 0.0,
              agentDetails: messageData['agentDetails'] ?? '',
              isReversal: messageData['isReversal'] ?? false,
              fulizaAmount: (messageData['fulizaAmount'] ?? 0.0) is int 
                  ? (messageData['fulizaAmount'] as int).toDouble() 
                  : messageData['fulizaAmount'] ?? 0.0,
              usedFuliza: messageData['usedFuliza'] ?? false,
              isLoan: messageData['isLoan'] ?? false,
              loanType: messageData['loanType'] ?? '',
            );
            
            await _messageStorage.insertMessage(parsedMessage);
            importedCount++;
          }
        } catch (e) {
          print('Error processing message: $e');
          // Continue with next message
        }
      }
      
      return importedCount;
    } catch (e) {
      print('Error parsing JSON content: $e');
      return 0;
    }
  }
  
  /// Import M-Pesa messages directly from a list of message strings
  Future<int> importFromMessageList(List<String> messages) async {
    int importedCount = 0;
    
    for (var message in messages) {
      try {
        final parsedMessage = MpesaParser.parseSms(message);
        await _messageStorage.insertMessage(parsedMessage);
        importedCount++;
      } catch (e) {
        print('Error parsing message: $e');
        // Continue with next message
      }
    }
    
    return importedCount;
  }
  
  /// Check if a transaction already exists in the database to avoid duplicates
  Future<bool> _transactionExists(String transactionCode) async {
    final messages = await _messageStorage.getAllMessages();
    return messages.any((message) => message.transactionCode == transactionCode);
  }
  
  /// Close resources
  Future<void> close() async {
    await _messageStorage.close();
  }
}