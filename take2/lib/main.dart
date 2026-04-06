import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';  // 👈 ADD THIS
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();   // 👈 ADD THIS
  await Firebase.initializeApp();              // 👈 ADD THIS
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
