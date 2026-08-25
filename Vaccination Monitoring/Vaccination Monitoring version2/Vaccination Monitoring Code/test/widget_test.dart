import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vaccination_monitoring/main.dart';
import 'package:vaccination_monitoring/features/vaccination_monitoring/data/repositories/vaccination_repository.dart';
import 'package:vaccination_monitoring/features/vaccination_monitoring/presentation/providers/vaccination_provider.dart';
import 'package:vaccination_monitoring/features/vaccination_monitoring/presentation/screens/vaccination_dashboard_screen.dart';

void main() {
  testWidgets('App launches and displays dashboard', (WidgetTester tester) async {
    final repo = VaccinationRepository(farmerId: 'test_farmer');
    repo.useFirestore = false; // Force mock mode in test environment

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<VaccinationRepository>.value(value: repo),
          ChangeNotifierProvider<VaccinationProvider>(
            create: (_) => VaccinationProvider(repository: repo),
          ),
        ],
        child: const KisanProVaccinationApp(),
      ),
    );

    // Let streams settle
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Verify dashboard screen is displayed
    expect(find.byType(VaccinationDashboardScreen), findsOneWidget);
    // Verify brand title text is present
    expect(find.text('Vaccine Monitoring System'), findsOneWidget);
  });
}
