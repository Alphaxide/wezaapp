import 'package:hive/hive.dart';

part "
transaction.g.dart"; // Hive generates this file

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  double amount;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  String type; // "Sent", "Received"

  @HiveField(4)
  String category;

  @HiveField(5)
  String label;

  @HiveField(6)
  String counterparty;

  @HiveField(7)
  String ref;

  @HiveField(8)
  String message; // Raw SMS text (optional)

  Transaction({
    required this.id,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    required this.label,
    required this.counterparty,
    required this.ref,
    required this.message,
  });
}
