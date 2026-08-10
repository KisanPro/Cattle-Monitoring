import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/vaccination_model.dart';

class ReportChartWidget extends StatelessWidget {
  final String type; // 'daily', 'weekly', 'monthly'
  final List<VaccinationModel> vaccinations;

  const ReportChartWidget({
    Key? key,
    required this.type,
    required this.vaccinations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildCustomBarChart();
  }

  Widget _buildCustomBarChart() {
    // Generate identical bar heights to match the screenshot design:
    // Bar heights: 1.0, 2.0, 0.8, 2.8, 1.8, 1.5, 4.5 (highlighted latest dose)
    final List<double> barHeights = [1.0, 2.0, 0.8, 2.8, 1.8, 1.5, 4.5];

    final barGroups = List.generate(barHeights.length, (index) {
      final isLast = index == barHeights.length - 1;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: barHeights[index],
            color: isLast ? AppTheme.primaryTeal : AppTheme.primaryTeal.withOpacity(0.22),
            width: 18,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 5.0,
              color: const Color(0xFFF3EFE3).withOpacity(0.3),
            ),
          ),
        ],
      );
    });

    return SizedBox(
      height: 120,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 5.0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.primaryTeal,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY} doses',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: const FlTitlesData(
            show: false, // Hide all default axis titles to match clean screenshot design
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(
            show: false, // Hide all grids to match screenshot design
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }
}
