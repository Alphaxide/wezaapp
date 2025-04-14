// TODO Implement this library.

// lib/models/mpesa_message.dart
import 'package:hive/hive.dart';


@HiveType(typeId: 0)
class MpesaMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String messageBody;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final String sender;

  @HiveField(4)
  final MessageCategory category;

  @HiveField(5)
  final double? amount;

  @HiveField(6)
  final String? transactionCode;

  @HiveField(7)
  final String? recipientName;

  @HiveField(8)
  final String? accountNumber;

  MpesaMessage({
    required this.id,
    required this.messageBody,
    required this.timestamp,
    required this.sender,
    required this.category,
    this.amount,
    this.transactionCode,
    this.recipientName,
    this.accountNumber,
  });

  factory MpesaMessage.fromSMS(String body, String sender, DateTime timestamp) {
    // Generate a unique ID
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Initial category before classification
    final category = MessageCategory.unclassified;
    
    // Extract transaction details
    final amountRegExp = RegExp(r'Ksh[.|\s]?([0-9,.]+)');
    final transactionCodeRegExp = RegExp(r'([A-Z0-9]{10})');
    final recipientNameRegExp = RegExp(r'to\s+([A-Za-z\s]+)');
    final accountNumberRegExp = RegExp(r'account\s+([A-Za-z0-9]+)');
    
    // Extract amount
    final amountMatch = amountRegExp.firstMatch(body);
    double? amount;
    if (amountMatch != null) {
      final amountStr = amountMatch.group(1)?.replaceAll(',', '');
      amount = double.tryParse(amountStr ?? '');
    }
    
    // Extract transaction code
    final transactionCodeMatch = transactionCodeRegExp.firstMatch(body);
    final transactionCode = transactionCodeMatch?.group(1);
    
    // Extract recipient name
    final recipientNameMatch = recipientNameRegExp.firstMatch(body);
    final recipientName = recipientNameMatch?.group(1);
    
    // Extract account number
    final accountNumberMatch = accountNumberRegExp.firstMatch(body);
    final accountNumber = accountNumberMatch?.group(1);

    return MpesaMessage(
      id: id,
      messageBody: body,
      timestamp: timestamp,
      sender: sender,
      category: category,
      amount: amount,
      transactionCode: transactionCode,
      recipientName: recipientName,
      accountNumber: accountNumber,
    );
  }
}

@HiveType(typeId: 1)
enum MessageCategory {
  @HiveField(0)
  sendMoney,
  
  @HiveField(1)
  receiveMoney,
  
  @HiveField(2)
  buyGoods,
  
  @HiveField(3)
  payBill,
  
  @HiveField(4)
  withdrawCash,
  
  @HiveField(5)
  depositCash,
  
  @HiveField(6)
  balanceInquiry,
  
  @HiveField(7)
  airtime,
  
  @HiveField(8)
  loan,
  
  @HiveField(9)
  subscription,
  
  @HiveField(10)
  unclassified
}
class MpesaMessageAdapter extends TypeAdapter<MpesaMessage> {
  @override
  final int typeId = 0;

  @override
  MpesaMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return MpesaMessage(
      id: fields[0] as String,
      messageBody: fields[1] as String,
      timestamp: fields[2] as DateTime,
      sender: fields[3] as String,
      category: fields[4] as MessageCategory,
      amount: fields[5] as double?,
      transactionCode: fields[6] as String?,
      recipientName: fields[7] as String?,
      accountNumber: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MpesaMessage obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id);
      // ... write the rest of the fields ...
  }
}

class MessageCategoryAdapter extends TypeAdapter<MessageCategory> {
  @override
  final int typeId = 1;

  @override
  MessageCategory read(BinaryReader reader) {
    return MessageCategory.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, MessageCategory obj) {
    writer.writeByte(obj.index);
  }
}