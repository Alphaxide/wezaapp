// lib/storage/storage_provider.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:weza/storage/mpesa_storage.dart';
import 'package:weza/storage/hive_storage.dart';
import 'package:weza/storage/sqlite_storage.dart';

class MessageStorageProvider {
  static final MessageStorageProvider _instance = MessageStorageProvider._internal();
  static MessageStorage? _storage;
  
  factory MessageStorageProvider() {
    return _instance;
  }
  
  MessageStorageProvider._internal();
  
  MessageStorage getStorage() {
    if (_storage == null) {
      _storage = kIsWeb ? HiveStorage() : SqliteStorage();
      _storage!.initialize();
    }
    return _storage!;
  }
  
  Future<void> closeStorage() async {
    if (_storage != null) {
      await _storage!.close();
      _storage = null;
    }
  }
}

MessageStorage getStorageImplementation() {
  return MessageStorageProvider().getStorage();
}