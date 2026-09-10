import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/milk_monitoring/presentation/providers/milk_provider.dart';
import 'features/milk_monitoring/presentation/screens/milk_monitoring_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        themeMode: ThemeMode.system,
        home: const MilkMonitoringScreen(),
      ),
    );
  }
}
