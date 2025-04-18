import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:weza/storage/mpesa_storage.dart';
import '../models/mpesa_message.dart';
import 'dart:io';

class SqliteStorage implements MessageStorage {
  // Singleton setup
  static final SqliteStorage _instance = SqliteStorage._internal();

  factory SqliteStorage() => _instance;

  SqliteStorage._internal();

  static Database? _database;
  bool _closed = false;

  Future<Database> get database async {
    if (_database != null && !_closed) return _database!;
    _database = await _initDatabase();
    _closed = false;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'mpesa_messages.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mpesa_messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transactionCode TEXT,
        transactionType TEXT,
        senderOrReceiverName TEXT,
        phoneNumber TEXT,
        amount REAL,
        balance REAL,
        account TEXT,
        message TEXT,
        transactionDate INTEGER,
        category TEXT,
        direction TEXT,
        transactionCost REAL DEFAULT 0.0,
        agentDetails TEXT DEFAULT '',
        isReversal INTEGER DEFAULT 0,
        fulizaAmount REAL DEFAULT 0.0,
        usedFuliza INTEGER DEFAULT 0,
        isLoan INTEGER DEFAULT 0,
        loanType TEXT DEFAULT ''
      )
    ''');
  }

  Future<void> _ensureDatabaseIsOpen() async {
    if (_closed || _database == null) {
      _database = await _initDatabase();
      _closed = false;
    }
  }

  @override
  Future<void> initialize() async {
    await _ensureDatabaseIsOpen();
  }

  @override
  Future<int> insertMessage(MpesaMessage message) async {
    await _ensureDatabaseIsOpen();
    try {
      final db = await database;
      return await db.insert('mpesa_messages', message.toMap());
    } on DatabaseException catch (e) {
      if (e.toString().contains('database is closed') || e.toString().contains('DatabaseException')) {
        await _ensureDatabaseIsOpen();
        final db = await database;
        return await db.insert('mpesa_messages', message.toMap());
      }
      rethrow;
    }
  }

  @override
  Future<List<MpesaMessage>> getAllMessages() async {
    await _ensureDatabaseIsOpen();
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('mpesa_messages');
      return List.generate(maps.length, (i) {
        return MpesaMessage.fromMap(maps[i]);
      });
    } on DatabaseException catch (e) {
      if (e.toString().contains('database is closed') || e.toString().contains('DatabaseException')) {
        await _ensureDatabaseIsOpen();
        final db = await database;
        final List<Map<String, dynamic>> maps = await db.query('mpesa_messages');
        return List.generate(maps.length, (i) {
          return MpesaMessage.fromMap(maps[i]);
        });
      }
      rethrow;
    }
  }

  @override
  Future<MpesaMessage?> getMessage(int id) async {
    await _ensureDatabaseIsOpen();
    try {
      final db = await database;
      final maps = await db.query(
        'mpesa_messages',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return MpesaMessage.fromMap(maps.first);
      }
      return null;
    } on DatabaseException catch (e) {
      if (e.toString().contains('database is closed') || e.toString().contains('DatabaseException')) {
        await _ensureDatabaseIsOpen();
        final db = await database;
        final maps = await db.query(
          'mpesa_messages',
          where: 'id = ?',
          whereArgs: [id],
        );

        if (maps.isNotEmpty) {
          return MpesaMessage.fromMap(maps.first);
        }
      }
      rethrow;
    }
    return null;
  }

  @override
  Future<void> deleteMessage(int id) async {
    await _ensureDatabaseIsOpen();
    try {
      final db = await database;
      await db.delete(
        'mpesa_messages',
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (e.toString().contains('database is closed') || e.toString().contains('DatabaseException')) {
        await _ensureDatabaseIsOpen();
        final db = await database;
        await db.delete(
          'mpesa_messages',
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> updateMessage(MpesaMessage message) async {
    await _ensureDatabaseIsOpen();
    try {
      final db = await database;
      await db.update(
        'mpesa_messages',
        message.toMap(),
        where: 'id = ?',
        whereArgs: [message.id],
      );
    } on DatabaseException catch (e) {
      if (e.toString().contains('database is closed') || e.toString().contains('DatabaseException')) {
        await _ensureDatabaseIsOpen();
        final db = await database;
        await db.update(
          'mpesa_messages',
          message.toMap(),
          where: 'id = ?',
          whereArgs: [message.id],
        );
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<List<MpesaMessage>> getMessagesByCategory(String category) async {
    await _ensureDatabaseIsOpen();
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'mpesa_messages',
        where: 'category = ?',
        whereArgs: [category],
      );
      return List.generate(maps.length, (i) {
        return MpesaMessage.fromMap(maps[i]);
      });
    } on DatabaseException catch (e) {
      if (e.toString().contains('database is closed') || e.toString().contains('DatabaseException')) {
        await _ensureDatabaseIsOpen();
        final db = await database;
        final List<Map<String, dynamic>> maps = await db.query(
          'mpesa_messages',
          where: 'category = ?',
          whereArgs: [category],
        );
        return List.generate(maps.length, (i) {
          return MpesaMessage.fromMap(maps[i]);
        });
      }
      rethrow;
    }
  }

  @override
  Future<List<MpesaMessage>> getMessagesByTransactionType(String transactionType) async {
    await _ensureDatabaseIsOpen();
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'mpesa_messages',
        where: 'transactionType = ?',
        whereArgs: [transactionType],
      );
      return List.generate(maps.length, (i) {
        return MpesaMessage.fromMap(maps[i]);
      });
    } on DatabaseException catch (e) {
      if (e.toString().contains('database is closed') || e.toString().contains('DatabaseException')) {
        await _ensureDatabaseIsOpen();
        final db = await database;
        final List<Map<String, dynamic>> maps = await db.query(
          'mpesa_messages',
          where: 'transactionType = ?',
          whereArgs: [transactionType],
        );
        return List.generate(maps.length, (i) {
          return MpesaMessage.fromMap(maps[i]);
        });
      }
      rethrow;
    }
  }

 

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}