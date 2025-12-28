import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 모드 고정 (선택사항)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SpringyKnitApp());
}

class SpringyKnitApp extends StatelessWidget {
  const SpringyKnitApp({super.key});

  // 테마 데이터를 미리 계산하여 캐싱 (성능 최적화)
  static final ThemeData _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFF1F0EF),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    fontFamily: 'Pretendard',
    scaffoldBackgroundColor: const Color(0xFFF1F0EF),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpringyKnit',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      home: const HomeScreen(),
    );
  }
}
