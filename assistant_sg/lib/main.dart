import 'package:flutter/material.dart';
import 'screens/setup_screen.dart';

void main() => runApp(const AssistantSGApp());

class AssistantSGApp extends StatelessWidget {
  const AssistantSGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AssistantSG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const SetupScreen(),
    );
  }
}
