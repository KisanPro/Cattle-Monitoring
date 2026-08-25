import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/cattle_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/radar_screen.dart';
import 'screens/fertility_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KisanProApp());
}

class KisanProApp extends StatelessWidget {
  const KisanProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CattleProvider(),
      child: MaterialApp(
        title: 'KISAN PRO',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF1F5F9),
          primaryColor: const Color(0xFF044E36),
          textTheme: GoogleFonts.interTextTheme(
            ThemeData.light().textTheme,
          ),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF044E36),
            secondary: Color(0xFF0D9488),
            surface: Colors.white,
          ),
        ),
        home: const MainNavigationScreen(),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    RadarScreen(),
    FertilityScreen(),
    AlertsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final alertCount = context.watch<CattleProvider>().unacknowledgedAlertsCount;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: const Color(0xFFE6F4EA),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
              (Set<WidgetState> states) => TextStyle(
                fontSize: 10,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? const Color(0xFF044E36)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          child: NavigationBar(
            height: 62,
            backgroundColor: Colors.white,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, color: Color(0xFF64748B), size: 20),
                selectedIcon: Icon(Icons.dashboard, color: Color(0xFF044E36), size: 22),
                label: 'Posture',
              ),
              const NavigationDestination(
                icon: Icon(Icons.radar_outlined, color: Color(0xFF64748B), size: 20),
                selectedIcon: Icon(Icons.radar, color: Color(0xFF044E36), size: 22),
                label: 'GPS Radar',
              ),
              const NavigationDestination(
                icon: Icon(Icons.favorite_outline, color: Color(0xFF64748B), size: 20),
                selectedIcon: Icon(Icons.favorite, color: Color(0xFF044E36), size: 22),
                label: 'Fertility',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: alertCount > 0,
                  label: Text('$alertCount'),
                  child: const Icon(Icons.notifications_none, color: Color(0xFF64748B), size: 20),
                ),
                selectedIcon: Badge(
                  isLabelVisible: alertCount > 0,
                  label: Text('$alertCount'),
                  child: const Icon(Icons.notifications, color: Color(0xFFDC2626), size: 22),
                ),
                label: 'Alerts',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined, color: Color(0xFF64748B), size: 20),
                selectedIcon: Icon(Icons.settings, color: Color(0xFF044E36), size: 22),
                label: 'Config',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
