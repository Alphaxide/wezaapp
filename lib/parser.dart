import 'package:flutter/material.dart';
import 'package:weza/main.dart';
import 'package:weza/storage/mpesa_storage.dart';

class ParserUi extends StatelessWidget {
  final MessageStorage storage;

  const ParserUi({Key? key, required this.storage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M-Pesa Message Analyzer',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(storage: storage),
    );
  }
}
