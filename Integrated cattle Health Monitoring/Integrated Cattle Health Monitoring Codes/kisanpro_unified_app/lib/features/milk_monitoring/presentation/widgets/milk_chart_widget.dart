import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/milk_record_model.dart';

class MilkChartWidget extends StatelessWidget {
  final List<MilkRecordModel> records;
  final String chartType; // "weekly", "monthly", "session"

  const MilkChartWidget({
    super.key,
    required this.records,
    required this.chartType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, color: AppTheme.textMuted, size: 48),
            SizedBox(height: 8),
            Text("No record data available for charts", style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    switch (chartType) {
      case 'weekly':
        return _buildWeeklyBarChart(isDark);
      case 'monthly':
        return _buildMonthlyLineChart(isDark);
      case 'session':
        return _buildSessionPieChart(isDark);
      default:
        return _buildWeeklyBarChart(isDark);
    }
  }

  // --- WEEKLY BAR CHART ---
  Widget _buildWeeklyBarChart(bool isDark) {
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    
    // Group records by day
    final Map<String, double> dayTotals = {};
    for (final record in records) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.timestamp);
      dayTotals[dateKey] = (dayTotals[dateKey] ?? 0.0) + record.quantity;
    }

    List<BarChartGroupData> barGroups = [];
    double maxVal = 10.0;

    for (int i = 0; i < 7; i++) {
      final day = last7Days[i];
      final key = DateFormat('yyyy-MM-dd').format(day);
      final val = dayTotals[key] ?? 0.0;
      if (val > maxVal) maxVal = val;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              gradient: AppTheme.primaryGradient,
              width: 14,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxVal * 1.1,
                color: isDark ? AppTheme.borderDark.withOpacity(0.3) : AppTheme.borderLight,
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.1,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => isDark ? AppTheme.surfaceDark : Colors.white,
            tooltipBorder: const BorderSide(color: AppTheme.primary, width: 1),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = last7Days[group.x];
              final dayStr = DateFormat('EEEE').format(date);
              return BarTooltipItem(
                "$dayStr\n${rod.toY.toStringAsFixed(1)} Liters",
                TextStyle(
                  color: isDark ? AppTheme.textDark : AppTheme.textLight,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (val, meta) => Text(
                val.toInt().toString(),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                if (val < 0 || val >= 7) return const SizedBox();
                final date = last7Days[val.toInt()];
                final label = DateFormat('E').format(date); // Mon, Tue
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(
            color: isDark ? AppTheme.borderDark.withOpacity(0.3) : AppTheme.borderLight,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  // --- MONTHLY LINE CHART ---
  Widget _buildMonthlyLineChart(bool isDark) {
    final now = DateTime.now();
    final List<DateTime> last30Days = List.generate(30, (i) => now.subtract(Duration(days: 29 - i)));

    final Map<String, double> dayTotals = {};
    for (final record in records) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.timestamp);
      dayTotals[dateKey] = (dayTotals[dateKey] ?? 0.0) + record.quantity;
    }

    List<FlSpot> spots = [];
    double maxVal = 10.0;

    for (int i = 0; i < 30; i++) {
      final day = last30Days[i];
      final key = DateFormat('yyyy-MM-dd').format(day);
      final val = dayTotals[key] ?? 0.0;
      if (val > maxVal) maxVal = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? AppTheme.borderDark.withOpacity(0.2) : AppTheme.borderLight.withOpacity(0.5),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => FlLine(
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
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 6, // Labels every 6 days
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= 30) return const SizedBox();
                final date = last30Days[index];
                final label = DateFormat('dd/MM').format(date);
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    label,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: isDark ? AppTheme.borderDark.withOpacity(0.4) : AppTheme.borderLight,
            width: 1,
          ),
        ),
        minX: 0,
        maxX: 29,
        minY: 0,
        maxY: maxVal * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: AppTheme.primaryGradient,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
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
                final date = last30Days[spot.x.toInt()];
                final dateStr = DateFormat('MMM dd, yyyy').format(date);
                return LineTooltipItem(
                  "$dateStr\n${spot.y.toStringAsFixed(1)} Liters",
                  TextStyle(
                    color: isDark ? AppTheme.textDark : AppTheme.textLight,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // --- SESSION PIE CHART (Morning vs Evening) ---
  Widget _buildSessionPieChart(bool isDark) {
    double morningTotal = 0.0;
    double eveningTotal = 0.0;

    for (final r in records) {
      if (r.milkTime == 'Morning') {
        morningTotal += r.quantity;
      } else {
        eveningTotal += r.quantity;
      }
    }

    final total = morningTotal + eveningTotal;
    if (total == 0) return const Center(child: Text("No data for sessions"));

    final morningPct = (morningTotal / total) * 100;
    final eveningPct = (eveningTotal / total) * 100;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  color: AppTheme.morningColor,
                  value: morningTotal,
                  title: '${morningPct.toStringAsFixed(1)}%',
                  radius: 35,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                PieChartSectionData(
                  color: AppTheme.eveningColor,
                  value: eveningTotal,
                  title: '${eveningPct.toStringAsFixed(1)}%',
                  radius: 35,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendRow("Morning", morningTotal, AppTheme.morningColor),
              const SizedBox(height: 12),
              _buildLegendRow("Evening", eveningTotal, AppTheme.eveningColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendRow(String title, double val, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text("${val.toStringAsFixed(1)} L", style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
