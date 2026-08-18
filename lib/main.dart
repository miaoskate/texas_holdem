import 'package:flutter/material.dart';
import 'ui/main_menu.dart';

void main() {
  runApp(const TexasHoldemApp());
}

class TexasHoldemApp extends StatelessWidget {
  const TexasHoldemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '德州扑克',
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1a3a2a),
      ),
      home: const MainMenu(),
      debugShowCheckedModeBanner: false,
    );
  }
}
