import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/milk_record_model.dart';
import '../providers/milk_provider.dart';
import '../widgets/milk_summary_card.dart';
import '../widgets/milk_entry_card.dart';
import '../widgets/recent_entry_tile.dart';
import '../widgets/cattle_report_modal.dart';
import 'milk_analytics_screen.dart';
import 'milk_history_screen.dart';
import 'milk_report_screen.dart';

class MilkMonitoringScreen extends StatefulWidget {
  const MilkMonitoringScreen({super.key});

  @override
  State<MilkMonitoringScreen> createState() => _MilkMonitoringScreenState();
}

class _MilkMonitoringScreenState extends State<MilkMonitoringScreen> {
  int _currentTab = 0;

  final List<Widget> _pages = [
    const DashboardTab(),
    const MilkAnalyticsScreen(),
    const MilkHistoryScreen(),
    const MilkReportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 850;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/logo.jpg',
                height: 32,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.agriculture, color: AppTheme.primary, size: 24);
                },
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Kisan Pro",
                  style: AppTheme.headlineStyle(isDark: false, size: 16).copyWith(color: Colors.white),
                ),
                const Text(
                  "Milk Monitoring System",
                  style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // DB Mode Switcher
          Consumer<MilkProvider>(
            builder: (context, provider, child) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: provider.isMockMode 
                      ? Colors.orange.withOpacity(0.12)
                      : AppTheme.accentMint.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: provider.isMockMode ? Colors.orange : AppTheme.accentMint,
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    provider.toggleMockMode();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.isMockMode 
                              ? "Local Simulation Mode enabled (mock data)."
                              : "Live Cloud Firestore Synchronization active.",
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        provider.isMockMode ? Icons.science_outlined : Icons.cloud_done_outlined,
                        color: provider.isMockMode ? Colors.orange : AppTheme.accentMint,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.isMockMode ? "Simulation" : "Cloud Sync",
                        style: TextStyle(
                          color: provider.isMockMode ? Colors.orange : AppTheme.accentMint,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: isWide 
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentTab,
                  onDestinationSelected: (idx) => setState(() => _currentTab = idx),
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: AppTheme.primary, size: 24),
                  unselectedIconTheme: const IconThemeData(color: AppTheme.textMuted, size: 22),
                  selectedLabelTextStyle: GoogleFonts.outfit(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                  unselectedLabelTextStyle: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 11),
                  backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text("Dashboard"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.analytics_outlined),
                      selectedIcon: Icon(Icons.analytics),
                      label: Text("Farm Analytics"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history_edu_outlined),
                      selectedIcon: Icon(Icons.history_edu),
                      label: Text("Milking Logbook"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.picture_as_pdf_outlined),
                      selectedIcon: Icon(Icons.picture_as_pdf),
                      label: Text("PDF Reports"),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1, color: AppTheme.borderLight),
                Expanded(
                  child: _pages[_currentTab],
                ),
              ]
            )
          : _pages[_currentTab],
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              currentIndex: _currentTab,
              onTap: (idx) => setState(() => _currentTab = idx),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: AppTheme.textMuted,
              selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11),
              backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: "Dashboard",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_outlined),
                  activeIcon: Icon(Icons.analytics),
                  label: "Farm Analytics",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_outlined),
                  activeIcon: Icon(Icons.history),
                  label: "Milking Logbook",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  activeIcon: Icon(Icons.picture_as_pdf),
                  label: "PDF Reports",
                ),
              ],
            ),
    );
  }
}

// Internal Dashboard Tab widget containing super app components
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 950;

    return Consumer<MilkProvider>(
      builder: (context, provider, child) {
        final records = provider.records;
        final analytics = provider.analytics;
        final recentGroups = provider.groupRecordsByCattleAndDay(records).take(5).toList();

        // Economics Calculations
        double grossRevenue = 0.0;
        final todayRecs = provider.todayEntries;
        for (final r in todayRecs) {
          grossRevenue += provider.calculateRate(r.fat, r.snf) * r.quantity;
        }
        if (grossRevenue == 0.0 && analytics.dailyTotal > 0) {
          grossRevenue = analytics.dailyTotal * provider.baseMilkPrice;
        }
        final double estFeedCost = analytics.dailyTotal * 18.5; // Average cattle feed cost per liter ratio
        final double netProfit = grossRevenue > estFeedCost ? grossRevenue - estFeedCost : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SUPER APP HEADER PANEL (Farmer profile, location, weather)
              _buildFarmerHeader(isDark),
              const SizedBox(height: 20),

              // 2. AI SMART FARM INSIGHTS (Horizontal scrolling warnings/tips)
              _buildAIInsightsBar(isDark, records),
              const SizedBox(height: 20),

              // 3. TODAY'S PRODUCTION SUMMARY
              MilkSummaryCard(
                dailyTotal: analytics.dailyTotal,
                morningTotal: analytics.morningMilk,
                eveningTotal: analytics.eveningMilk,
              ),
              const SizedBox(height: 20),



              // 4. ECONOMICS AND PROFIT TRACKER
              _buildEconomicsTracker(context, provider, isDark, analytics.dailyTotal, grossRevenue, netProfit),
              const SizedBox(height: 20),

              // 5. RESPONSIVE DUAL COLUMN (Quick add form vs live feed)
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          flex: 4,
                          child: MilkEntryCard(),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 5,
                          child: _buildRecentLogsColumn(context, recentGroups, provider.isLoading),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const MilkEntryCard(),
                        const SizedBox(height: 20),
                        _buildRecentLogsColumn(context, recentGroups, provider.isLoading),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  // Header Component
  Widget _buildFarmerHeader(bool isDark) {
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    
    return Row(
      children: [
        // Rounded Farmer Profile Image placeholder
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary, width: 2),
            color: Colors.white,
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/farmer.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.person, color: AppTheme.primary, size: 28),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Welcome text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome, Rajesh Kumar",
                style: AppTheme.headlineStyle(isDark: isDark, size: 18),
              ),
              Text(
                formattedDate,
                style: AppTheme.bodyStyle(isDark: isDark, size: 12, isMuted: true),
              ),
            ],
          ),
        ),

        // Weather widget indicating agricultural context
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: AppTheme.cardDecoration(isDark: isDark, borderRadius: 12, showShadow: false),
          child: const Row(
            children: [
              Icon(Icons.wb_sunny, color: Colors.orange, size: 18),
              SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("32°C", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text("Milking Alert", style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _calculateCattleAlerts(List<MilkRecordModel> allRecords) {
    final List<Map<String, dynamic>> calculatedAlerts = [];
    if (allRecords.isEmpty) return calculatedAlerts;

    // Group records by cow
    final Map<String, List<MilkRecordModel>> cowRecordsMap = {};
    for (final r in allRecords) {
      final name = r.cattleName;
      if (!cowRecordsMap.containsKey(name)) {
        cowRecordsMap[name] = [];
      }
      cowRecordsMap[name]!.add(r);
    }

    // Sort records for each cow by timestamp (newest first)
    cowRecordsMap.forEach((name, list) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });

    // Check each cow's metrics
    cowRecordsMap.forEach((name, list) {
      if (list.isEmpty) return;

      final latest = list.first;
      final cowId = latest.cattleId;

      // 1. Yield Drop Alert: Latest yield is 20% lower than the cow's historical average
      if (list.length >= 3) {
        final previousRecords = list.skip(1).toList();
        final double sum = previousRecords.fold(0.0, (s, r) => s + r.quantity);
        final double avg = sum / previousRecords.length;
        if (latest.quantity < avg * 0.8 && latest.quantity > 0) {
          final dropPct = ((avg - latest.quantity) / avg) * 100;
          calculatedAlerts.add({
            "type": "error",
            "title": "Yield Decreased: $name ($cowId)",
            "message": "Milking volume decreased by ${dropPct.toStringAsFixed(1)}% (${latest.quantity.toStringAsFixed(1)}L vs avg ${avg.toStringAsFixed(1)}L).",
            "color": AppTheme.accentRose,
            "icon": Icons.warning_amber_rounded,
          });
        }
      }

      // 1b. Continuous Yield Loss Alert: Yield decreased for 3 consecutive sessions
      if (list.length >= 3) {
        final current = list[0].quantity;
        final prev1 = list[1].quantity;
        final prev2 = list[2].quantity;
        if (current < prev1 && prev1 < prev2 && current > 0) {
          calculatedAlerts.add({
            "type": "error",
            "title": "Yield Decreased: $name ($cowId) 📉",
            "message": "Milking volume decreased for 3 consecutive sessions (${prev2.toStringAsFixed(1)}L → ${prev1.toStringAsFixed(1)}L → ${current.toStringAsFixed(1)}L).",
            "color": AppTheme.accentRose,
            "icon": Icons.trending_down_rounded,
          });
        }
      }

      // 2. Peak Yield Milestone / High Performance Congratulatory Alert
      if (list.length >= 2) {
        final double highestPast = list.skip(1).fold(0.0, (max, r) => r.quantity > max ? r.quantity : max);
        if (latest.quantity > highestPast) {
          if (latest.quantity >= 15.0) {
            calculatedAlerts.add({
              "type": "peak",
              "title": "Super Champion Peak: $name ($cowId) 🎉",
              "message": "Congratulations! $name hit an incredible new historic peak yield of ${latest.quantity.toStringAsFixed(1)}L (previous best: ${highestPast.toStringAsFixed(1)}L). Good progress!",
              "color": Colors.amber,
              "icon": Icons.workspace_premium,
            });
          } else if (latest.quantity > 8.0) {
            calculatedAlerts.add({
              "type": "peak",
              "title": "New Peak Milestone: $name ($cowId) 🌟",
              "message": "Great progress! $name achieved a new peak milking volume of ${latest.quantity.toStringAsFixed(1)}L (previous best: ${highestPast.toStringAsFixed(1)}L). Keep it up!",
              "color": Colors.amber,
              "icon": Icons.workspace_premium,
            });
          }
        } else if (latest.quantity >= 15.0) {
          calculatedAlerts.add({
            "type": "peak",
            "title": "High Yield Performer: $name ($cowId) 🌟",
            "message": "Congratulations! $name maintained a high yield of ${latest.quantity.toStringAsFixed(1)}L. Excellent milk progress!",
            "color": Colors.amber,
            "icon": Icons.star,
          });
        }
      } else if (latest.quantity >= 15.0) {
        calculatedAlerts.add({
          "type": "peak",
          "title": "High Yield Performer: $name ($cowId) 🌟",
          "message": "Congratulations! $name logged a high yield of ${latest.quantity.toStringAsFixed(1)}L. Excellent progress!",
          "color": Colors.amber,
          "icon": Icons.star,
        });
      }

      // 3. Quality Alert: FAT or SNF levels below standard
      if (latest.fat < 3.5 || latest.snf < 8.0) {
        calculatedAlerts.add({
          "type": "quality",
          "title": "Quality Alert: $name ($cowId)",
          "message": "Quality parameters are low (Fat: ${latest.fat}%, SNF: ${latest.snf}%). Check diet/concentrate intake.",
          "color": Colors.orange,
          "icon": Icons.analytics_outlined,
        });
      }
    });

    // 4. Milking Missed Alert: No entries in the last 24 hours for active cows
    cowRecordsMap.forEach((name, list) {
      if (list.isNotEmpty) {
        final lastMilked = list.first.timestamp;
        final hoursSince = DateTime.now().difference(lastMilked).inHours;
        if (hoursSince > 24) {
          calculatedAlerts.add({
            "type": "missed",
            "title": "Milking Missed: $name (${list.first.cattleId})",
            "message": "No milk entry recorded for over $hoursSince hours. Last session was ${DateFormat('dd MMM hh:mm a').format(lastMilked)}.",
            "color": Colors.indigo,
            "icon": Icons.alarm_on,
          });
        }
      }
    });

    // Add generic agricultural tips if alerts are few
    if (calculatedAlerts.length < 2) {
      calculatedAlerts.add({
        "type": "tip",
        "title": "Milking Tip",
        "message": "Maintaining uniform milking intervals (e.g. exactly 12 hours) optimizes overall fat and SNF yield.",
        "color": AppTheme.accentMint,
        "icon": Icons.lightbulb_outline,
      });
      calculatedAlerts.add({
        "type": "tip",
        "title": "Feeding Recommendation",
        "message": "Feeding concentrates 20-30 minutes before milking stimulates milk let-down reflex.",
        "color": AppTheme.accentMint,
        "icon": Icons.restaurant,
      });
    }

    return calculatedAlerts;
  }

  // AI insights scrolling banner (dynamic alerts)
  Widget _buildAIInsightsBar(bool isDark, List<MilkRecordModel> records) {
    final alerts = _calculateCattleAlerts(records);

    return SizedBox(
      height: 64, // Taller to fit double lines beautifully
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: alerts.length,
        itemBuilder: (context, idx) {
          final alert = alerts[idx];
          final color = alert['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.35), width: 0.8),
            ),
            child: Row(
              children: [
                Icon(alert['icon'] as IconData, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        alert['title'] as String,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert['message'] as String,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Economics Margin calculator
  Widget _buildEconomicsTracker(BuildContext context, MilkProvider provider, bool isDark, double todayYield, double grossRev, double netProfit) {
    final int displayGross = grossRev.round();
    final int displayFeed = (todayYield * 18.5).round();
    final int displayNet = displayGross > displayFeed ? displayGross - displayFeed : 0;

    return Container(
      decoration: AppTheme.cardDecoration(isDark: isDark, borderRadius: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "FARM ECONOMICS & MARGINS",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Base Price: ₹${provider.baseMilkPrice.toStringAsFixed(1)}/L",
                  style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Slider to adjust price dynamically
          Row(
            children: [
              const Icon(Icons.toll_outlined, color: AppTheme.textMuted, size: 18),
              Expanded(
                child: Slider(
                  value: provider.baseMilkPrice,
                  min: 30.0,
                  max: 80.0,
                  divisions: 50,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.borderLight,
                  onChanged: (val) {
                    provider.baseMilkPrice = val;
                  },
                ),
              ),
              const Text("₹80", style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 6),

          // Quality Billing toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.rule_folder_outlined, color: AppTheme.textMuted, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Quality-Based Billing (FAT & SNF Formula)",
                        style: TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: provider.useQualityPricing,
                activeColor: AppTheme.primary,
                onChanged: (val) {
                  provider.useQualityPricing = val;
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Economics grid
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Est. Gross Revenue", style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      "₹$displayGross",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: AppTheme.borderLight),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Feed Cost Overhead", style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      "₹$displayFeed",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.accentRose),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: AppTheme.borderLight),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Daily Net Profit", style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      "₹$displayNet",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Recent logs column
  Widget _buildRecentLogsColumn(BuildContext context, List<List<MilkRecordModel>> recentGroups, bool isLoading) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: AppTheme.cardDecoration(
        isDark: isDark,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "RECENT ENTRIES",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMuted),
              ),
              Text(
                "Tap entry to view report",
                style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isLoading && recentGroups.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30.0),
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primary)),
              ),
            )
          else if (recentGroups.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: AppTheme.textMuted, size: 40),
                    SizedBox(height: 12),
                    Text(
                      "No milking records added today.\nFill the form above to add your first record.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentGroups.length,
              itemBuilder: (context, idx) {
                final group = recentGroups[idx];
                return RecentEntryTile(
                  records: group,
                  onTap: () => CattleReportModal.show(context, group.first.cattleName, group.first.cattleId),
                );
              },
            ),
        ],
      ),
    );
  }

}
