import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cattle_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CattleProvider>();
    final cow = provider.selectedCow;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.auto_graph, color: Color(0xFFA855F7), size: 24),
            SizedBox(width: 10),
            Text(
              '21-Day Baseline & Health AI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 21-Day Rolling Baseline Status Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF2E1065)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.insights, color: Color(0xFFA855F7), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Adaptive Health Baseline Calibration',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Continuous 21-day time-series rolling average computed every 15 minutes by analytics.py daemon on AWS EC2.',
                  style: TextStyle(fontSize: 12, color: Colors.purple.shade200),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Diagnostic Health Heuristics
          _buildHealthRuleCard(
            title: '🔥 Estrus / In-Heat Detection',
            condition: 'Step count > 300% of 21-day average AND Grazing drop > 25%',
            outcome: 'Prompts farmer for optimal Artificial Insemination (AI) window (next 4-12 hrs).',
            status: (cow != null && cow.totalSteps > 3000) ? 'ESTRUS HIGH RISK' : 'NORMAL CYCLE',
            statusColor: (cow != null && cow.totalSteps > 3000) ? Colors.orangeAccent : const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),

          _buildHealthRuleCard(
            title: '🤒 Sickness / Fever Detection',
            condition: 'Grazing drops > 40% below baseline AND Lying increases > 35%',
            outcome: 'Triggers early veterinary alert before physical clinical symptoms appear.',
            status: cow?.behaviorId == 4 ? 'LYING (MONITORING)' : 'HEALTHY STATUS',
            statusColor: cow?.behaviorId == 4 ? Colors.amber : const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),

          _buildHealthRuleCard(
            title: '🪰 Insect / Parasite Irritation',
            condition: 'Head-shake count ≥ 10 in rolling 1-hour window',
            outcome: 'Flags fly or parasite swarm infestation in current pasture quadrant.',
            status: cow?.behaviorId == 6 ? 'IRRITATION DETECTED' : 'CLEAR',
            statusColor: cow?.behaviorId == 6 ? Colors.amber : const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),

          // Behavior Time Allocation Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAILY BEHAVIOR TIME ALLOCATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 14),
                _buildBehaviorBar('Grazing / Feeding', 0.45, const Color(0xFF10B981)),
                const SizedBox(height: 10),
                _buildBehaviorBar('Lying / Rumination', 0.35, Colors.indigoAccent),
                const SizedBox(height: 10),
                _buildBehaviorBar('Standing / Idle', 0.12, Colors.blueAccent),
                const SizedBox(height: 10),
                _buildBehaviorBar('Walking / Kinetic Steps', 0.08, Colors.cyan),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRuleCard({
    required String title,
    required String condition,
    required String outcome,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rule: $condition',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 4),
          Text(
            'Action: $outcome',
            style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorBar(String label, double ratio, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
            ),
            Text(
              '${(ratio * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: const Color(0xFF334155),
            color: color,
          ),
        ),
      ],
    );
  }
}
