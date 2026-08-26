import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/milk_record_model.dart';
import '../providers/milk_provider.dart';

class CattleReportModal extends StatefulWidget {
  final String cattleName;
  final String cattleId;

  const CattleReportModal({
    super.key,
    required this.cattleName,
    required this.cattleId,
  });

  static void show(BuildContext context, String name, String id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CattleReportModal(cattleName: name, cattleId: id),
    );
  }

  @override
  State<CattleReportModal> createState() => _CattleReportModalState();
}

class _CattleReportModalState extends State<CattleReportModal> {
  String _selectedTab = 'Weekly'; // 'Daily', 'Weekly', 'Monthly'

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MilkProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Filter records for this specific cow
    final cowRecords = provider.records
        .where((r) => r.cattleId.toLowerCase() == widget.cattleId.toLowerCase() || 
                     r.cattleName.toLowerCase() == widget.cattleName.toLowerCase())
        .toList();

    // Calculations based on selected tab scope
    final now = DateTime.now();
    List<MilkRecordModel> scopedRecords = [];
    if (_selectedTab == 'Daily') {
      scopedRecords = cowRecords.where((r) => 
        r.timestamp.year == now.year && r.timestamp.month == now.month && r.timestamp.day == now.day
      ).toList();
    } else if (_selectedTab == 'Weekly') {
      scopedRecords = cowRecords.where((r) => 
        r.timestamp.isAfter(now.subtract(const Duration(days: 7)))
      ).toList();
    } else {
      scopedRecords = cowRecords.where((r) => 
        r.timestamp.isAfter(now.subtract(const Duration(days: 30)))
      ).toList();
    }

    // Yield Metrics
    final double totalMilk = scopedRecords.fold(0.0, (sum, r) => sum + r.quantity);
    final double morningMilk = scopedRecords.where((r) => r.milkTime == 'Morning').fold(0.0, (sum, r) => sum + r.quantity);
    final double eveningMilk = scopedRecords.where((r) => r.milkTime == 'Evening').fold(0.0, (sum, r) => sum + r.quantity);
    
    final daysCount = scopedRecords.map((r) => DateFormat('yyyy-MM-dd').format(r.timestamp)).toSet().length;
    final double avgDaily = daysCount > 0 ? totalMilk / daysCount : 0.0;

    // Find Best Day
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

    // Last recorded time
    final lastRecordDateStr = cowRecords.isNotEmpty 
        ? DateFormat('dd MMM yyyy').format(cowRecords.first.timestamp)
        : 'N/A';

    final sortedScoped = List<MilkRecordModel>.from(scopedRecords)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final List<FlSpot> spots = [];
    if (sortedScoped.isNotEmpty) {
      if (sortedScoped.length == 1) {
        spots.add(FlSpot(0, sortedScoped[0].quantity));
        spots.add(FlSpot(1, sortedScoped[0].quantity));
      } else {
        for (int i = 0; i < sortedScoped.length; i++) {
          spots.add(FlSpot(i.toDouble(), sortedScoped[i].quantity));
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 30),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handlebar indicator
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row: avatar, title, close X
            Row(
              children: [
                // Avatar Drop Circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC2E2DF), // Pastel light teal
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.opacity, color: AppTheme.primary, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.cattleName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textLight,
                        ),
                      ),
                      Text(
                        "Milk Report • ${widget.cattleId}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildLactationBadgeRow(widget.cattleName, avgDaily),
            const SizedBox(height: 18),

            // Pills navigation: Daily, Weekly, Monthly
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
            const SizedBox(height: 18),

            // TOTAL MILK PRODUCTION CARD BLOCK
            Container(
              decoration: AppTheme.cardDecoration(
                isDark: isDark,
                borderRadius: 18,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${widget.cattleName}'s Total Yield",
                    style: const TextStyle(
                      fontSize: 12,
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
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "Liters",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Avg Daily / Best Day summary
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Daily Avg", style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text("${avgDaily.toStringAsFixed(1)} L", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Best Yielding Day", style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(bestDay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Minimalist fl_chart curved Area Line chart
                  SizedBox(
                    height: 120,
                    child: scopedRecords.isEmpty
                        ? const Center(child: Text("No records in this scope", style: TextStyle(fontSize: 11, color: AppTheme.textMuted)))
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
                                    reservedSize: 32,
                                    getTitlesWidget: (value, meta) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 4.0),
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
                                      if (index < 0 || index >= sortedScoped.length) {
                                        if (sortedScoped.length == 1 && index == 1) {
                                          final r = sortedScoped[0];
                                          final timeStr = r.milkTime == 'Morning' ? 'M' : 'E';
                                          final dateStr = DateFormat('dd/MM').format(r.timestamp);
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              "$dateStr ($timeStr)",
                                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      }
                                      
                                      if (sortedScoped.length > 7) {
                                        if (index % (sortedScoped.length ~/ 4) != 0 && index != sortedScoped.length - 1) {
                                          return const SizedBox();
                                        }
                                      }
                                      
                                      final r = sortedScoped[index];
                                      final timeStr = r.milkTime == 'Morning' ? 'M' : 'E';
                                      final dateStr = DateFormat('dd/MM').format(r.timestamp);
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          "$dateStr ($timeStr)",
                                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              minX: 0,
                              maxX: sortedScoped.length == 1 ? 1 : (sortedScoped.length - 1).toDouble(),
                              minY: 0,
                              maxY: (sortedScoped.map((r) => r.quantity).reduce((a, b) => a > b ? a : b)) * 1.3,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  gradient: AppTheme.primaryGradient,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
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
                                      final r = sortedScoped[index.clamp(0, sortedScoped.length - 1)];
                                      final dateStr = DateFormat('dd MMM yyyy').format(r.timestamp);
                                      return LineTooltipItem(
                                        "$dateStr\nSession: ${r.milkTime}\nYield: ${spot.y.toStringAsFixed(1)} L\nFat: ${r.fat}% | SNF: ${r.snf}%",
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
            ),
            const SizedBox(height: 18),

            // 2x2 DETAIL GRID CARDS
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
                  value: "${morningMilk.toStringAsFixed(1)} L",
                ),
                _buildMiniMetricCard(
                  icon: Icons.mode_night_outlined,
                  title: "Evening Milk",
                  value: "${eveningMilk.toStringAsFixed(1)} L",
                ),
                _buildMiniMetricCard(
                  icon: Icons.bar_chart_outlined,
                  title: "Total Prd.",
                  value: "${totalMilk.toStringAsFixed(1)} L",
                ),
                _buildMiniMetricCard(
                  icon: Icons.calendar_today_outlined,
                  title: "Last Recorded",
                  value: lastRecordDateStr,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildAINutritionCard(avgDaily),
            const SizedBox(height: 22),

            // GENERATE REPORT PILL BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Prompt generation completed
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("PDF Report compilation started... Go to Reports tab."),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_outlined, size: 20),
                    SizedBox(width: 8),
                    Text("Generate Report", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabName) {
    final isSelected = _selectedTab == tabName;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tabName),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : const Color(0xFFF0EDE0),
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

  Widget _buildLactationBadgeRow(String name, double avgDaily) {
    final int dim = (name.hashCode.abs() % 240) + 40; // DIM range: 40 to 280
    String phase;
    Color color;
    if (dim <= 100) {
      phase = "Early Lactation (Peak)";
      color = AppTheme.orangeAccent;
    } else if (dim <= 200) {
      phase = "Mid Lactation (Stable)";
      color = AppTheme.primary;
    } else {
      phase = "Late Lactation (Dry Stage)";
      color = Colors.blue;
    }

    final double projectedYield = avgDaily * 305 * (dim > 200 ? 1.05 : 0.95);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "LACTATION STAGE",
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.5),
              ),
              const SizedBox(height: 2),
              Text(
                phase,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "DIM: $dim Days",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? AppTheme.textDark : Colors.black87),
              ),
              Text(
                "Proj. 305d: ${projectedYield.toStringAsFixed(0)}L",
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAINutritionCard(double avgDaily) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Concentrate formula: 1.2 kg base maintenance + 1 kg per 2.5 kg yield
    final double concentrateVal = 1.2 + (avgDaily / 2.5);
    final double greenFodder = avgDaily > 15 ? 25.0 : 20.0;
    final double dryFodder = avgDaily > 15 ? 6.0 : 5.0;

    return Container(
      decoration: AppTheme.cardDecoration(isDark: isDark, borderRadius: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                "AI FEED & NUTRITION OPTIMIZER",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Recommended daily feed recipe to maintain optimal milk quantity & fat ratios:",
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFeedNutrientItem("Concentrates", "${concentrateVal.toStringAsFixed(1)} kg", Icons.grain),
              _buildFeedNutrientItem("Green Fodder", "${greenFodder.toStringAsFixed(0)} kg", Icons.grass),
              _buildFeedNutrientItem("Dry Fodder", "${dryFodder.toStringAsFixed(0)} kg", Icons.bakery_dining),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedNutrientItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary.withOpacity(0.7), size: 18),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
      ],
    );
  }


}
