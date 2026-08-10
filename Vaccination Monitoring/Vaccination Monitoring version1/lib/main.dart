import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'features/vaccination_monitoring/data/repositories/vaccination_repository.dart';
import 'features/vaccination_monitoring/presentation/providers/vaccination_provider.dart';
import 'features/vaccination_monitoring/presentation/screens/vaccination_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to initialize Firebase if configurations are present
  // Otherwise, catch the error and fall back to MockDatabaseService automatically
  try {
    await Firebase.initializeApp();
    print("KisanPro App: Firebase initialized successfully.");
  } catch (e) {
    print("KisanPro App: Firebase initialization skipped/failed: $e");
    print("KisanPro App: Continuing in offline/mock database fallback mode.");
  }

  // Set default farmer ID for KisanPro monitoring session
  const String activeFarmerId = 'farmer_kp_789';

  runApp(
    MultiProvider(
      providers: [
        Provider<VaccinationRepository>(
          create: (_) => VaccinationRepository(farmerId: activeFarmerId),
        ),
        ChangeNotifierProxyProvider<VaccinationRepository, VaccinationProvider>(
          create: (context) => VaccinationProvider(
            repository: Provider.of<VaccinationRepository>(context, listen: false),
          ),
          update: (context, repository, previousProvider) =>
              previousProvider ?? VaccinationProvider(repository: repository),
        ),
      ],
      child: const KisanProVaccinationApp(),
    ),
  );
}

class KisanProVaccinationApp extends StatelessWidget {
  const KisanProVaccinationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KisanPro Vaccination Monitoring',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const VaccinationDashboardScreen(),
    );
  }
}
