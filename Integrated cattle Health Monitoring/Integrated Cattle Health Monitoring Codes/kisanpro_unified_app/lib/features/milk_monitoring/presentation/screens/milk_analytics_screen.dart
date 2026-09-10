import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/milk_record_model.dart';
import '../providers/milk_provider.dart';
import '../widgets/cattle_report_modal.dart';
import '../../../registry/providers/cattle_registry_provider.dart';

class MilkAnalyticsScreen extends StatefulWidget {
  const MilkAnalyticsScreen({super.key});

  @override
  State<MilkAnalyticsScreen> createState() => _MilkAnalyticsScreenState();
}

class _MilkAnalyticsScreenState extends State<MilkAnalyticsScreen> {
  String _selectedPeriod = 'Weekly'; // 'Daily', 'Weekly', 'Monthly'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Consumer<MilkProvider>(
      builder: (context, provider, child) {
        final registry = context.watch<CattleRegistryProvider>();
        final records = provider.records.where((r) => registry.isCattleRegistered(r.cattleId, r.cattleName)).toList();
        
        // Scope records according to selected period
        final now = DateTime.now();
        List<MilkRecordModel> scopedRecords = [];
        if (_selectedPeriod == 'Daily') {
          scopedRecords = records.where((r) => 
            r.timestamp.year == now.year && r.timestamp.month == now.month && r.timestamp.day == now.day
          ).toList();
        } else if (_selectedPeriod == 'Weekly') {
          scopedRecords = records.where((r) => 
            r.timestamp.isAfter(now.subtract(const Duration(days: 7)))
          ).toList();
        } else {
          scopedRecords = records.where((r) => 
            r.timestamp.isAfter(now.subtract(const Duration(days: 30)))
          ).toList();
        }

        // Calculations
        final double totalMilk = scopedRecords.fold(0.0, (sum, r) => sum + r.quantity);
        final double morningMilk = scopedRecords.where((r) => r.milkTime == 'Morning').fold(0.0, (sum, r) => sum + r.quantity);
        final double eveningMilk = scopedRecords.where((r) => r.milkTime == 'Evening').fold(0.0, (sum, r) => sum + r.quantity);
        
        final daysCount = scopedRecords.map((r) => DateFormat('yyyy-MM-dd').format(r.timestamp)).toSet().length;
        final double avgDaily = daysCount > 0 ? totalMilk / daysCount : 0.0;

        // Group by Date for Chart & Best Day
        final dailyTotals = <String, double>{};
        for (final r in scopedRecords) {
          final dateKey = DateFormat('yyyy-MM-dd').format(r.timestamp);
          dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0.0) + r.quantity;
        }

        String bestDay = 'N/A';
        double maxQty = 0.0;
        dailyTotals.forEach((dateStr, qty) {
          if (qty > maxQty) {
            maxQty = qty;
            final date = DateTime.parse(dateStr);
            bestDay = DateFormat('EEEE').format(date);
          }
        });

        // Unique active cows count
        final int activeCows = scopedRecords.map((r) => r.cattleId).toSet().length;
        final double efficiency = morningMilk > 0 ? (eveningMilk / morningMilk) * 100 : 0.0;

        // Leaderboard calculation
        final Map<String, double> cattleYields = {};
        for (final r in scopedRecords) {
          cattleYields[r.cattleName] = (cattleYields[r.cattleName] ?? 0.0) + r.quantity;
        }
        final sortedCattle = cattleYields.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                "Farm Analytics Overview",
                style: AppTheme.headlineStyle(isDark: isDark, size: 22),
              ),
              const SizedBox(height: 4),
              const Text(
                "Aggregated reports on milking yield trends and session metrics.",
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Segmented Tab bar: Daily, Weekly, Monthly
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTabButton("Daily"),
                  const SizedBox(width: 8),
                  _buildTabButton("Weekly"),
                  const SizedBox(width: 8),
                  _buildTabButton("Monthly"),
                ],
              ),
              const SizedBox(height: 20),

              // Responsive layout wrapper
              isWide 
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildMainProductionCard(isDark, totalMilk, avgDaily, bestDay, scopedRecords, maxQty),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 4,
                          child: _buildSidePanel(isDark, morningMilk, eveningMilk, activeCows, efficiency, sortedCattle, records),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildMainProductionCard(isDark, totalMilk, avgDaily, bestDay, scopedRecords, maxQty),
                        const SizedBox(height: 20),
                        _buildSidePanel(isDark, morningMilk, eveningMilk, activeCows, efficiency, sortedCattle, records),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  // Segment Selector Tab Button
  Widget _buildTabButton(String tabName) {
    final isSelected = _selectedPeriod == tabName;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = tabName),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : const Color(0xFFEBE8D8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              tabName,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textLight,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Main Report Card Card (matches Lakshmi Report design)
  Widget _buildMainProductionCard(
    bool isDark,
    double totalMilk,
    double avgDaily,
    String bestDay,
    List<MilkRecordModel> scopedRecords,
    double maxQty,
  ) {
    // Generate curved LineChart data based on period
    final now = DateTime.now();
    List<FlSpot> spots = [];
    List<String> xLabels = [];
    double maxVal = 10.0;
    
    if (_selectedPeriod == 'Daily') {
      final todayRecords = List<MilkRecordModel>.from(scopedRecords)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (todayRecords.isNotEmpty) {
        if (todayRecords.length == 1) {
          maxVal = todayRecords[0].quantity;
          spots = [FlSpot(0, todayRecords[0].quantity), FlSpot(1, todayRecords[0].quantity)];
          xLabels = ["${todayRecords[0].milkTime} (Today)", "${todayRecords[0].milkTime} (Today)"];
        } else {
          for (int i = 0; i < todayRecords.length; i++) {
            final val = todayRecords[i].quantity;
            if (val > maxVal) maxVal = val;
            spots.add(FlSpot(i.toDouble(), val));
            xLabels.add(todayRecords[i].milkTime);
          }
        }
      }
    } else if (_selectedPeriod == 'Weekly') {
      final List<DateTime> last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
      final Map<String, double> dayTotals = {};
      for (final r in scopedRecords) {
        final dateKey = DateFormat('yyyy-MM-dd').format(r.timestamp);
        dayTotals[dateKey] = (dayTotals[dateKey] ?? 0.0) + r.quantity;
      }
      for (int i = 0; i < 7; i++) {
        final date = last7Days[i];
        final key = DateFormat('yyyy-MM-dd').format(date);
        final val = dayTotals[key] ?? 0.0;
        if (val > maxVal) maxVal = val;
        spots.add(FlSpot(i.toDouble(), val));
        xLabels.add(DateFormat('E').format(date)); // Mon, Tue...
      }
    } else {
      // Monthly
      final List<DateTime> last30Days = List.generate(30, (i) => now.subtract(Duration(days: 29 - i)));
      final Map<String, double> dayTotals = {};
      for (final r in scopedRecords) {
        final dateKey = DateFormat('yyyy-MM-dd').format(r.timestamp);
        dayTotals[dateKey] = (dayTotals[dateKey] ?? 0.0) + r.quantity;
      }
      for (int i = 0; i < 30; i++) {
        final date = last30Days[i];
        final key = DateFormat('yyyy-MM-dd').format(date);
        final val = dayTotals[key] ?? 0.0;
        if (val > maxVal) maxVal = val;
        spots.add(FlSpot(i.toDouble(), val));
        xLabels.add(DateFormat('dd/MM').format(date));
      }
    }

    return Container(
      decoration: AppTheme.cardDecoration(
        isDark: isDark,
        borderRadius: 20,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total Farm Yield (All Cattle)",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                totalMilk.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Liters",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, thickness: 0.5, color: AppTheme.borderLight),
          const SizedBox(height: 16),

          // Sub stats
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Daily Farm Avg", style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text("${avgDaily.toStringAsFixed(1)} Liters", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Best Farm Day", style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(bestDay, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Minimalist fl_chart curved Area Line chart
          SizedBox(
            height: 140, // Taller chart height for visual prominence
            child: spots.isEmpty
                ? const Center(child: Text("No milking logs in this period", style: TextStyle(color: AppTheme.textMuted)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isDark ? AppTheme.borderDark.withOpacity(0.2) : AppTheme.borderLight.withOpacity(0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Text(
                                  "${value.toStringAsFixed(1)}L",
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= xLabels.length) return const SizedBox();
                              
                              // Reduce labels for monthly view
                              if (_selectedPeriod == 'Monthly') {
                                if (index % 5 != 0 && index != xLabels.length - 1) {
                                  return const SizedBox();
                                }
                              }
                              
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  xLabels[index],
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: spots.length == 1 ? 1 : (spots.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxVal * 1.25,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          gradient: AppTheme.primaryGradient,
                          barWidth: 3.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: _selectedPeriod == 'Monthly' ? false : true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primary.withOpacity(0.35),
                                AppTheme.primary.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => isDark ? AppTheme.surfaceDark : Colors.white,
                          tooltipBorder: const BorderSide(color: AppTheme.primary, width: 1),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();
                              String tooltipHeader = "";
                              if (_selectedPeriod == 'Daily') {
                                final todayRecords = List<MilkRecordModel>.from(scopedRecords)
                                  ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                                if (todayRecords.isNotEmpty) {
                                  final r = todayRecords[index.clamp(0, todayRecords.length - 1)];
                                  tooltipHeader = "${r.milkTime} Milking\n";
                                }
                              } else if (_selectedPeriod == 'Weekly') {
                                final List<DateTime> last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
                                final date = last7Days[index.clamp(0, 6)];
                                tooltipHeader = "${DateFormat('EEEE, dd MMM').format(date)}\n";
                              } else {
                                final List<DateTime> last30Days = List.generate(30, (i) => now.subtract(Duration(days: 29 - i)));
                                final date = last30Days[index.clamp(0, 29)];
                                tooltipHeader = "${DateFormat('dd MMM yyyy').format(date)}\n";
                              }
                              
                              return LineTooltipItem(
                                "${tooltipHeader}Yield: ${spot.y.toStringAsFixed(1)} L",
                                TextStyle(
                                  color: isDark ? AppTheme.textDark : AppTheme.textLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Side statistics and Leaderboard panel
  Widget _buildSidePanel(
    bool isDark,
    double morningMilk,
    double eveningMilk,
    int activeCows,
    double efficiency,
    List<MapEntry<String, double>> sortedCattle,
    List<MilkRecordModel> records,
  ) {
    return Column(
      children: [
        // 2x2 Metric Grid
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMiniMetricCard(
              icon: Icons.wb_sunny_outlined,
              title: "Morning Milk",
              value: "${morningMilk.toStringAsFixed(0)} L",
            ),
            _buildMiniMetricCard(
              icon: Icons.mode_night_outlined,
              title: "Evening Milk",
              value: "${eveningMilk.toStringAsFixed(0)} L",
            ),
            _buildMiniMetricCard(
              icon: Icons.pets_outlined,
              title: "Active Cattle",
              value: "$activeCows Cows",
            ),
            _buildMiniMetricCard(
              icon: Icons.speed_outlined,
              title: "Milking Ratio",
              value: "${efficiency.toStringAsFixed(0)}%",
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Leaderboard Ranking List
        Container(
          decoration: AppTheme.cardDecoration(
            isDark: isDark,
            borderRadius: 16,
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium, color: AppTheme.orangeAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "CATTLE PRODUCTION LEADERBOARD",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (sortedCattle.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("No metrics in this period.", style: TextStyle(color: AppTheme.textMuted)),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedCattle.length,
                  itemBuilder: (context, index) {
                    final item = sortedCattle[index];
                    final rank = index + 1;
                    final double maxVal = sortedCattle.first.value;
                    final double ratio = maxVal > 0 ? (item.value / maxVal) : 0.0;
                    
                    // Resolve cattle ID dynamically
                    final matchingRecord = records.firstWhere(
                      (r) => r.cattleName.toLowerCase() == item.key.toLowerCase(),
                      orElse: () => MilkRecordModel(
                        cattleId: "KP-${200 + index}",
                        cattleName: item.key,
                        milkTime: "Morning",
                        quantity: 0.0,
                        fat: 4.2,
                        snf: 8.5,
                        timestamp: DateTime.now(),
                      ),
                    );
                    final cowId = matchingRecord.cattleId;

                    return InkWell(
                      onTap: () => CattleReportModal.show(context, item.key, cowId),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: Row(
                          children: [
                            // Rank number avatar
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: rank == 1 
                                    ? const Color(0xFFFFE0B2) // Gold
                                    : (rank == 2 
                                        ? Colors.grey[300] 
                                        : AppTheme.primary.withOpacity(0.1)),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  rank.toString(),
                                  style: TextStyle(
                                    color: rank == 1 
                                        ? const Color(0xFFE65100)
                                        : (rank == 2 ? Colors.grey[700] : AppTheme.primary),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Cow Name
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.key,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textLight),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      backgroundColor: isDark ? AppTheme.borderDark : Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation(
                                        rank == 1 ? AppTheme.primary : AppTheme.primary.withOpacity(0.5),
                                      ),
                                      minHeight: 5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Yield value
                            Expanded(
                              flex: 1,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "${item.value.toStringAsFixed(0)} L",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppTheme.primary,
                                  ),
                                ),
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
        ),
      ],
    );
  }

  Widget _buildMiniMetricCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: AppTheme.cardDecoration(
        isDark: isDark,
        borderRadius: 14,
        showShadow: false,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
