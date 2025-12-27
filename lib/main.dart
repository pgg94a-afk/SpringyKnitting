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
          seedColor: const Color(0xFFF1F0EF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: const Color(0xFFF1F0EF),
      ),
      home: const HomeScreen(),
    );
  }
}
