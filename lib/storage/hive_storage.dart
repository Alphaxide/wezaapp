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

  @override
  Future<void> initialize() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);

    if (_box.isNotEmpty) {
      final maxId = _box.keys.cast<int>().reduce((curr, next) => curr > next ? curr : next);
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
    final id = message.id ?? _idCounter++;
    final messageWithId = message.copyWith(id: id);
    await _box.put(id, messageWithId.toMap());
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
    await _box.delete(id);
  }

  @override
  Future<void> updateMessage(MpesaMessage message) async {
    _checkInitialized();
    if (message.id != null) {
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
