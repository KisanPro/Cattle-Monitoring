import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/providers/farmer_auth_provider.dart';
import 'features/auth/screens/farmer_login_screen.dart';
import 'features/registry/providers/cattle_registry_provider.dart';
import 'features/registry/screens/cattle_registration_screen.dart';

import 'features/ai_health/presentation/screens/ai_health_screen.dart';
import 'features/milk_monitoring/presentation/screens/milk_monitoring_screen.dart';
import 'features/vaccination_monitoring/presentation/screens/vaccination_dashboard_screen.dart';
import 'features/weight_monitoring/home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AiHealthScreen(),
    const MilkMonitoringScreen(),
    const VaccinationDashboardScreen(),
    const HomeScreen(),
  ];

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Farmer Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text('Are you sure you want to sign out from the KisanPro Farm Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<FarmerAuthProvider>().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const FarmerLoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<CattleRegistryProvider>();
    final auth = context.watch<FarmerAuthProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 1,
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.agriculture, size: 16, color: Color(0xFF6EE7B7)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    auth.farmName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Farmer: ${auth.farmerName} • ID: ${auth.farmId}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFFD1FAE5)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Farmer Profile & Action Menu
          PopupMenuButton<String>(
            tooltip: 'Farmer Profile & Options',
            icon: const Icon(Icons.account_circle, color: Colors.white, size: 26),
            onSelected: (val) {
              if (val == 'register') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CattleRegistrationScreen()),
                );
              } else if (val == 'logout') {
                _showSignOutDialog();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.farmerName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Farm: ${auth.farmId}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                    Text('${registry.cattles.length} Registered Cattles', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'register',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primary),
                    SizedBox(width: 10),
                    Text('Register New Cattle', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Farmer Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: _currentIndex == 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: Container(
                  color: const Color(0xFF00544A),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pets, size: 15, color: Color(0xFFA7F3D0)),
                          SizedBox(width: 4),
                          Text(
                            'CATTLE:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA7F3D0)),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: const Color(0xFF00544A),
                            value: registry.selectedCattleId,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            items: registry.cattles.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.cattleId,
                                child: Text(
                                  '${c.cattleId} • ${c.name} (${c.breed.split(' ').first})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                registry.selectCattle(val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: const Color(0xFF8C9B97),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.health_and_safety_outlined),
              activeIcon: Icon(Icons.health_and_safety),
              label: 'AI Health 360°',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.water_drop_outlined),
              activeIcon: Icon(Icons.water_drop),
              label: 'Milk Yield',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.vaccines_outlined),
              activeIcon: Icon(Icons.vaccines),
              label: 'Vaccination',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.monitor_weight_outlined),
              activeIcon: Icon(Icons.monitor_weight),
              label: 'Weight & 3D',
            ),
          ],
        ),
      ),
    );
  }
}
