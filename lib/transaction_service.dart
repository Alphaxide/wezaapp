// transaction_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:weza/storage/mpesa_storage.dart';
import 'package:weza/storage/storage_provider.dart';
import 'package:weza/models/mpesa_message.dart';
import 'transaction_model.dart';

class TransactionService {
  static final MessageStorage _storage = getStorageImplementation();

  static Future<List<Transaction>> loadTransactions() async {
    await _storage.initialize();
    final messages = await _storage.getAllMessages();
    return messages.map(_convertMessageToTransaction).toList();
  }

  static Transaction _convertMessageToTransaction(MpesaMessage message) {
    return Transaction(
      id: message.id,
      type: _mapTransactionType(message.transactionType),
      amount: message.amount,
      category: message.category ?? 'Uncategorized',
      date: message.transactionDate,
      recipient: message.senderOrReceiverName ?? 'Unknown',
      transactionCode: message.transactionCode,
      balance: message.balance,
    );
  }

  static String _mapTransactionType(String mpesaType) {
    switch (mpesaType.toLowerCase()) {
      case 'sent':
      case 'paybill':
      case 'withdraw':
      case 'buy goods':
      case 'withdraw cash':
      case 'atm withdrawal':
      case 'buy airtime':
      case 'loan repayment':
      case 'pochi la biashara':
      case 'send money':
        return 'send';
      case 'receive money':
      case 'deposit':
      case 'loan disbursement':
      case 'fuliza repayment':
      case 'reversal':
      case 'incoming':
        return 'Incoming';
      default:
        return mpesaType.toLowerCase();
    }
  }

  static List<Transaction> filterByTimeFrame(
    List<Transaction> transactions,
    String timeFrame,
  ) {
    final now = DateTime.now();
    DateTime startDate;

    switch (timeFrame) {
      case 'Last Month':
        startDate = DateTime(now.year, now.month - 1);
        break;
      case 'Last 3 Months':
        startDate = DateTime(now.year, now.month - 3);
        break;
      case 'Last 6 Months':
        startDate = DateTime(now.year, now.month - 6);
        break;
      case 'Last Year':
        startDate = DateTime(now.year - 1);
        break;
      default:
        return transactions;
    }

    return transactions.where((t) => t.date.isAfter(startDate)).toList();
  }

  static Map<String, double> getCategoryBreakdown(List<Transaction> transactions) {
    final breakdown = <String, double>{};
    for (final transaction in transactions) {
      if (transaction.type != 'Incoming') {
        breakdown.update(
          transaction.category,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }
    return breakdown;
  }

  static Map<DateTime, double> getMonthlySpendingData(List<Transaction> transactions) {
    final monthlyData = <DateTime, double>{};
    
    for (final transaction in transactions) {
      if (transaction.type != 'Incoming') {
        final monthStart = DateTime(transaction.date.year, transaction.date.month);
        monthlyData.update(
          monthStart,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }
    
    // Fill missing months
    final now = DateTime.now();
    final oldestDate = transactions.isNotEmpty 
        ? transactions.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b)
        : now;
    
    DateTime current = DateTime(oldestDate.year, oldestDate.month);
    while (current.isBefore(now)) {
      monthlyData.putIfAbsent(current, () => 0.0);
      current = DateTime(current.year, current.month + 1);
    }
    
    return monthlyData;
  }

  static Widget buildMonthlySpendingChart(Map<DateTime, double> monthlyData) {
    final sortedMonths = monthlyData.keys.toList()..sort();
    
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final date = sortedMonths[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(DateFormat('MMM').format(date)),
                );
              },
              interval: 1,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: sortedMonths.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                monthlyData[entry.value] ?? 0.0,
              );
            }).toList(),
            isCurved: true,
            color: Colors.blue,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  static Widget buildCategoryBreakdownChart(Map<String, double> breakdown) {
    final total = breakdown.values.fold(0.0, (sum, amount) => sum + amount);
    if (total == 0) return const Center(child: Text("No data available"));
    
    final pieSections = breakdown.entries.map((entry) {
      final percentage = (entry.value / total * 100).toStringAsFixed(1);
      
      return PieChartSectionData(
        color: _getCategoryColor(entry.key),
        value: entry.value,
        title: '$percentage%',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: pieSections,
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  static Color getTypeColor(String type) {
    switch (type) {
      case 'send':
      case 'paybill':
      case 'withdraw':
        return Colors.red;
      case 'Incoming':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static IconData getTypeIcon(String type) {
    switch (type) {
      case 'send':
        return Icons.arrow_upward;
      case 'Incoming':
        return Icons.arrow_downward;
      case 'paybill':
        return Icons.receipt;
      default:
        return Icons.money_off;
    }
  }

  static Color _getCategoryColor(String category) {
    final colors = Colors.primaries;
    final index = category.hashCode % colors.length;
    return colors[index].shade400;
  }
}

class Transaction {
  final int? id;
  final String type; // 'send'/'Incoming'/'paybill' etc.
  final double amount;
  final String category;
  final DateTime date;
  final String recipient;
  final String transactionCode;
  final double balance;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.recipient,
    required this.transactionCode,
    required this.balance,
  });

  // Optional: Add formatted date getter
  String get formattedDate => DateFormat('dd MMM yyyy').format(date);
}