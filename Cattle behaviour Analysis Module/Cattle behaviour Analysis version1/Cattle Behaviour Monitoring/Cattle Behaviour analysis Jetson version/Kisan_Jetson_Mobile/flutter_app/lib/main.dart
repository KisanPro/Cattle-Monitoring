import 'package:flutter/material.dart';
import 'screens/dashboard.dart';

void main() {
  runApp(const KisanMobileApp());
}

class KisanMobileApp extends StatelessWidget {
  const KisanMobileApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kisan CattleVision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F4E8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006857),
          primary: const Color(0xFF006857),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF006857),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
