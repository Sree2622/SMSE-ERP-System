import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(SmartKiranaApp());
}

class SmartKiranaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Kirana',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}