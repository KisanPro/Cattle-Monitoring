import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cattle_provider.dart';

class FertilityScreen extends StatelessWidget {
  const FertilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CattleProvider>();
    final countdown = provider.aiCountdown;

    String hours = countdown.inHours.toString().padLeft(2, '0');
    String minutes = (countdown.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (countdown.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF044E36),
        elevation: 2,
        title: const Text(
          'Fertility & Rumination Monitor',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // 1. Fertility & AI Window (AM-PM Rule) Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB), // Soft warm cream
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.favorite, color: Color(0xFFDC2626), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Fertility & AI Window (AM-PM Rule)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Countdown Timer Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'OPTIMAL BREEDING COUNTDOWN (12H WINDOW)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${hours}h ${minutes}m ${seconds}s',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Heat Intensity Score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Heat Intensity Score:',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                    Text(
                      '${provider.heatIntensityScore} / 100 (NORMAL LUTEAL PHASE)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Advice Banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AM-PM Rule Advice: Estrus surge detected at 06:00 PM. Recommend Artificial Insemination (AI) between 06:00 AM & 09:00 AM today.',
                          style: TextStyle(fontSize: 10, color: Color(0xFF991B1B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Nutrition & Rumination Monitor Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.eco, color: Color(0xFF044E36), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Nutrition & Rumination Monitor',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF044E36),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Multi-Segment Activity Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 78,
                        child: Container(
                          height: 24,
                          color: const Color(0xFF0D9488),
                          alignment: Alignment.center,
                          child: const Text(
                            '7.8h Feed',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 272,
                        child: Container(
                          height: 24,
                          color: const Color(0xFF065F46),
                          alignment: Alignment.center,
                          child: const Text(
                            '27.2h Rumination',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 20,
                        child: Container(
                          height: 24,
                          color: const Color(0xFF0284C7),
                          alignment: Alignment.center,
                          child: const Text(
                            '2h Rest',
                            style: TextStyle(fontSize: 8, color: Colors.white),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 36,
                        child: Container(
                          height: 24,
                          color: const Color(0xFFF59E0B),
                          alignment: Alignment.center,
                          child: const Text(
                            '3.6h Walk',
                            style: TextStyle(fontSize: 8, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Feed Efficiency Index: 98% (Healthy Rumen Chewing)\nNormal Target: 7.0 - 9.0 hrs/day',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Daily Activity & Behavior Breakdown Donut Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DAILY ACTIVITY & BEHAVIOR BREAKDOWN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF044E36),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Last 24 Hours',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Donut Chart Canvas
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(
                        painter: DonutChartPainter(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
                          _buildLegendRow('Grazing', '17.8%', const Color(0xFF0D9488)),
                          const SizedBox(height: 4),
                          _buildLegendRow('Standing', '68.5%', const Color(0xFF065F46)),
                          const SizedBox(height: 4),
                          _buildLegendRow('Lying', '6.8%', const Color(0xFF0284C7)),
                          const SizedBox(height: 4),
                          _buildLegendRow('Walking', '4.1%', const Color(0xFF2563EB)),
                          const SizedBox(height: 4),
                          _buildLegendRow('Super-Active', '1.4%', const Color(0xFFDB2777)),
                          const SizedBox(height: 4),
                          _buildLegendRow('Head Shake', '1.4%', const Color(0xFF7C3AED)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String name, String pct, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
            ),
          ],
        ),
        Text(
          pct,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Segments: Standing (68.5%), Grazing (17.8%), Lying (6.8%), Walking (4.1%), Super-Active (1.4%), HeadShake (1.4%)
    final segments = [
      {'pct': 0.685, 'color': const Color(0xFF065F46)},
      {'pct': 0.178, 'color': const Color(0xFF0D9488)},
      {'pct': 0.068, 'color': const Color(0xFF0284C7)},
      {'pct': 0.041, 'color': const Color(0xFF2563EB)},
      {'pct': 0.014, 'color': const Color(0xFFDB2777)},
      {'pct': 0.014, 'color': const Color(0xFF7C3AED)},
    ];

    double startAngle = -pi / 2;

    for (var seg in segments) {
      final sweepAngle = (seg['pct'] as double) * 2 * pi;
      paint.color = seg['color'] as Color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
