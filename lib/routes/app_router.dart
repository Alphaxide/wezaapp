// TODO Implement this library.
// lib/routes/app_router.dart
import 'package:flutter/material.dart';
import 'package:weza/models/mpesa_message.dart';
import '../screens/home_screen.dart';
import '../screens/messages_list_screen.dart';
import '../screens/message_details_screen.dart';
import '../screens/category_breakdown_screen.dart';
import '../screens/settings_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String messagesList = '/messages';
  static const String messageDetails = '/message-details';
  static const String categoryBreakdown = '/category-breakdown';
  static const String settingspage = '/settings';
  
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      
      case messagesList:
        final args = settings.arguments as MessageListArgs?;
        return MaterialPageRoute(
          builder: (_) => MessagesListScreen(
            category: args?.category,
            title: args?.title ?? 'All Messages',
          ),
        );
      
      case messageDetails:
        final messageId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => MessageDetailsScreen(messageId: messageId),
        );
      
      case categoryBreakdown:
        return MaterialPageRoute(
          builder: (_) => const CategoryBreakdownScreen(),
        );
      
      case settingspage:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settingspage.name}'),
            ),
          ),
        );
    }
  }
}

class MessageListArgs {
  final String? title;
  final MessageCategory? category;
  
  MessageListArgs({this.title, this.category});
}