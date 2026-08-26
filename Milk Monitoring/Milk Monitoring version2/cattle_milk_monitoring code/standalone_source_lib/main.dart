import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'features/milk_monitoring/presentation/providers/milk_provider.dart';
import 'features/milk_monitoring/presentation/screens/milk_monitoring_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safeguarded for local test setups lacking Google Services files)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase Initialization Alert: $e. Running in local simulation mode.');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MilkProvider()),
      ],
      child: MaterialApp(
        title: 'KisanPro Milk Monitoring',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system, // Automatically matches user OS preference
        home: const MilkMonitoringScreen(),
      ),
    );
  }
}
