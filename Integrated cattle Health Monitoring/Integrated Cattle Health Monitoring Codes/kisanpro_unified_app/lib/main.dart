import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/providers/farmer_auth_provider.dart';
import 'features/auth/screens/farmer_login_screen.dart';
import 'features/registry/providers/cattle_registry_provider.dart';

import 'features/milk_monitoring/presentation/providers/milk_provider.dart';
import 'features/vaccination_monitoring/data/repositories/vaccination_repository.dart';
import 'features/vaccination_monitoring/presentation/providers/vaccination_provider.dart';
import 'main_navigation_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  const String activeFarmerId = '8088032780_Samruddhi_Farm';

  runApp(
    MultiProvider(
      providers: [
        // Farmer Auth Provider
        ChangeNotifierProvider<FarmerAuthProvider>(
          create: (_) => FarmerAuthProvider(),
        ),

        // Central Cattle Registry Provider (Holds the 5 seeded cattle & registration)
        ChangeNotifierProvider<CattleRegistryProvider>(
          create: (_) => CattleRegistryProvider(),
        ),

        // Milk Provider
        ChangeNotifierProvider<MilkProvider>(
          create: (_) => MilkProvider(),
        ),

        // Vaccination Repository & Provider
        Provider<VaccinationRepository>(
          create: (_) => VaccinationRepository(farmerId: activeFarmerId),
        ),
        ChangeNotifierProxyProvider<VaccinationRepository, VaccinationProvider>(
          create: (context) => VaccinationProvider(
            repository:
                Provider.of<VaccinationRepository>(context, listen: false),
          ),
          update: (context, repository, previous) =>
              previous ?? VaccinationProvider(repository: repository),
        ),
      ],
      child: const KisanProUnifiedApp(),
    ),
  );
}

class KisanProUnifiedApp extends StatelessWidget {
  const KisanProUnifiedApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<FarmerAuthProvider>().isLoggedIn;

    return MaterialApp(
      title: 'KisanPro Unified Cattle Monitoring',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? const MainNavigationScreen() : const FarmerLoginScreen(),
    );
  }
}
