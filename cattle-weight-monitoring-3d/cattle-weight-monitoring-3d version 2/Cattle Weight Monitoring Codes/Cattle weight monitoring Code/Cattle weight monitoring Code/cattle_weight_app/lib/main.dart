import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

// Override default HTTP client to accept self-signed certificates or bypass SSL check if needed (useful for development)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const KisanProCattleApp());
}

class KisanProCattleApp extends StatelessWidget {
  const KisanProCattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kisan Pro Cattle Weight & 3D',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF006D60),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006D60),
          primary: const Color(0xFF006D60),
          secondary: const Color(0xFFEBEAD8),
          background: const Color(0xFFFAF7E8),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF7E8),
        cardTheme: const CardTheme(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        dropdownMenuTheme: const DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: MaterialStatePropertyAll(Color(0xFFFAF7E8)),
          ),
        ),
        dialogTheme: const DialogTheme(
          backgroundColor: Color(0xFFFAF7E8),
          surfaceTintColor: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF006D60),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        // Premium typography configuration
        fontFamily: 'Roboto',
      ),
      home: FutureBuilder<bool>(
        future: ApiService().isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF006D60),
                ),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data == true) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

