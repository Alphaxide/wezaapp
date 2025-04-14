// lib/services/message_classifier.dart
import 'models.dart';

class MessageClassifier {
  static MessageCategory classifyMessage(String messageBody) {
    final lowerMessage = messageBody.toLowerCase();
    
    // Pattern matching for different transaction types
    if (lowerMessage.contains('you have received')) {
      return MessageCategory.receiveMoney;
    } else if (lowerMessage.contains('sent to') || lowerMessage.contains('money sent')) {
      return MessageCategory.sendMoney;
    } else if (lowerMessage.contains('paid to') && lowerMessage.contains('till')) {
      return MessageCategory.buyGoods;
    } else if (lowerMessage.contains('paid to') && lowerMessage.contains('account')) {
      return MessageCategory.payBill;
    } else if (lowerMessage.contains('withdraw') || lowerMessage.contains('withdrawn')) {
      return MessageCategory.withdrawCash;
    } else if (lowerMessage.contains('deposit') || lowerMessage.contains('deposited')) {
      return MessageCategory.depositCash;
    } else if (lowerMessage.contains('balance is')) {
      return MessageCategory.balanceInquiry;
    } else if (lowerMessage.contains('airtime')) {
      return MessageCategory.airtime;
    } else if (lowerMessage.contains('loan') || lowerMessage.contains('fuliza')) {
      return MessageCategory.loan;
    } else if (lowerMessage.contains('subscription')) {
      return MessageCategory.subscription;
    }
    
    return MessageCategory.unclassified;
  }
  
  static MpesaMessage classifyMpesaMessage(MpesaMessage message) {
    if (message.category == MessageCategory.unclassified) {
      final newCategory = classifyMessage(message.messageBody);
      
      // Create a new message with the updated category
      return MpesaMessage(
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
    }
    
    return message;
  }
}