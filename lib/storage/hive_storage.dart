import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:weza/storage/mpesa_storage.dart';
import '../models/mpesa_message.dart';

class HiveStorage implements MessageStorage {
  static final HiveStorage _instance = HiveStorage._internal();
  factory HiveStorage() => _instance;
  HiveStorage._internal();

  static const String _boxName = 'mpesa_messages';
  late Box<Map<dynamic, dynamic>> _box;
  int _idCounter = 0;
  
  // Index to quickly lookup transaction codes
  final Map<String, int> _transactionCodeIndex = {};

  @override
  Future<void> initialize() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);

    // Initialize the ID counter and build the transaction code index
    if (_box.isNotEmpty) {
      int maxId = 0;
      
      // Build the transaction code index and find the max ID
      for (final key in _box.keys) {
        final id = key as int;
        final map = _box.get(id);
        
        if (map != null) {
          final transactionCode = map['transactionCode'] as String;
          _transactionCodeIndex[transactionCode] = id;
          
          if (id > maxId) {
            maxId = id;
          }
        }
      }
      
      _idCounter = maxId + 1;
    }
  }

  void _checkInitialized() {
    if (!_box.isOpen) {
      throw Exception('HiveStorage not initialized. Call initialize() first.');
    }
  }

  @override
  Future<int> insertMessage(MpesaMessage message) async {
    _checkInitialized();
    
    final transactionCode = message.transactionCode;
    
    // Check if transaction already exists using our index
    if (_transactionCodeIndex.containsKey(transactionCode)) {
      return _transactionCodeIndex[transactionCode]!; // Return existing ID
    }
    
    // Generate an ID for new message if needed
    final id = message.id ?? _idCounter++;
    final messageWithId = message.copyWith(id: id);
    
    // Insert the message
    await _box.put(id, messageWithId.toMap());
    
    // Update our index
    _transactionCodeIndex[transactionCode] = id;
    
    return id;
  }

  @override
  Future<List<MpesaMessage>> getAllMessages() async {
    _checkInitialized();
    return _box.values.map((map) => MpesaMessage.fromMap(Map<String, dynamic>.from(map))).toList();
  }

  @override
  Future<MpesaMessage?> getMessage(int id) async {
    _checkInitialized();
    final map = _box.get(id);
    if (map != null) {
      return MpesaMessage.fromMap(Map<String, dynamic>.from(map));
    }
    return null;
  }

  @override
  Future<void> deleteMessage(int id) async {
    _checkInitialized();
    final map = _box.get(id);
    
    if (map != null) {
      // Remove from index before deleting
      final transactionCode = map['transactionCode'] as String;
      _transactionCodeIndex.remove(transactionCode);
    }
    
    await _box.delete(id);
  }

  @override
  Future<void> updateMessage(MpesaMessage message) async {
    _checkInitialized();
    if (message.id != null) {
      final oldMap = _box.get(message.id);
      
      if (oldMap != null) {
        final oldTransactionCode = oldMap['transactionCode'] as String;
        final newTransactionCode = message.transactionCode;
        
        // Update the index if transaction code changed
        if (oldTransactionCode != newTransactionCode) {
          _transactionCodeIndex.remove(oldTransactionCode);
          _transactionCodeIndex[newTransactionCode] = message.id!;
        }
      }
      
      await _box.put(message.id, message.toMap());
    }
  }

  @override
  Future<List<MpesaMessage>> getMessagesByCategory(String category) async {
    _checkInitialized();
    return _box.values
        .where((map) => map['category'] == category)
        .map((map) => MpesaMessage.fromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  @override
  Future<List<MpesaMessage>> getMessagesByTransactionType(String transactionType) async {
    _checkInitialized();
    return _box.values
        .where((map) => map['transactionType'] == transactionType)
        .map((map) => MpesaMessage.fromMap(Map<String, dynamic>.from(map)))
        .toList();
  }


  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}