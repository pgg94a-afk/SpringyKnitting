import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SpringyKnitApp());
}

class SpringyKnitApp extends StatelessWidget {
  const SpringyKnitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpringyKnit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB6C1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const HomeScreen(),
    );
  }
}
