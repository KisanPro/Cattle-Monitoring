import 'package:flutter/material.dart';

enum AlertType { criticalLoss, rapidGain }

class CattleAlert {
  final String cowId;
  final String name;
  final AlertType type;
  final int count;
  final String message;

  CattleAlert({
    required this.cowId,
    required this.name,
    required this.type,
    required this.count,
    required this.message,
  });
}

class AlertsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> historyList;

  const AlertsScreen({super.key, required this.historyList});

  List<CattleAlert> _calculateAlerts() {
    // 1. Group records by cow ID
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var r in historyList) {
      final cowId = r['cow_id'] ?? '';
      if (cowId.isNotEmpty) {
        grouped.putIfAbsent(cowId, () => []).add(r);
      }
    }

    final List<CattleAlert> alerts = [];

    // TEST ALERTS (For demonstration purposes)
    alerts.add(CattleAlert(
      cowId: "MOCK-001",
      name: "Lakshmi",
      type: AlertType.criticalLoss,
      count: 3,
      message: "TEST ALERT: Cattle Lakshmi (ID: MOCK-001) has shown a continuous, drastic weight loss of 35.0 kg (-8.5%) over the last 3 measurements. Immediate health check recommended.",
    ));
    alerts.add(CattleAlert(
      cowId: "MOCK-002",
      name: "Ganga",
      type: AlertType.rapidGain,
      count: 4,
      message: "TEST ALERT: Cattle Ganga (ID: MOCK-002) has shown a continuous, rapid weight gain of 42.0 kg (+10.2%) over the last 4 measurements. Check feeding levels or pregnancy status.",
    ));

    // 2. Scan each cow's history for trends
    grouped.forEach((cowId, list) {
      // Sort oldest to newest
      list.sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));

      final int n = list.length;
      if (n >= 3) {
        // Find continuous decrease ending at the most recent reading (index n-1)
        int decCount = 1;
        for (int i = n - 1; i > 0; i--) {
          final double curr = (list[i]['weight_kg'] as num).toDouble();
          final double prev = (list[i - 1]['weight_kg'] as num).toDouble();
          if (curr < prev) {
            decCount++;
          } else {
            break;
          }
        }

        // Find continuous increase ending at the most recent reading (index n-1)
        int incCount = 1;
        for (int i = n - 1; i > 0; i--) {
          final double curr = (list[i]['weight_kg'] as num).toDouble();
          final double prev = (list[i - 1]['weight_kg'] as num).toDouble();
          if (curr > prev) {
            incCount++;
          } else {
            break;
          }
        }

        final String name = list[n - 1]['name'] ?? 'Unnamed';

        if (decCount >= 3) {
          final double wOld = (list[n - decCount]['weight_kg'] as num).toDouble();
          final double wNew = (list[n - 1]['weight_kg'] as num).toDouble();
          final double diff = wOld - wNew;
          final double pct = wOld > 0 ? (diff / wOld) * 100 : 0.0;

          // Vet threshold: Critical weight loss >= 8% over the trend duration
          if (pct >= 8.0) {
            alerts.add(CattleAlert(
              cowId: cowId,
              name: name,
              type: AlertType.criticalLoss,
              count: decCount,
              message: "Cattle $name (ID: $cowId) has shown a continuous, drastic weight loss of ${diff.toStringAsFixed(1)} kg (-${pct.toStringAsFixed(1)}%) over the last $decCount consecutive measurements. Immediate health check recommended.",
            ));
          }
        } else if (incCount >= 3) {
          final double wOld = (list[n - incCount]['weight_kg'] as num).toDouble();
          final double wNew = (list[n - 1]['weight_kg'] as num).toDouble();
          final double diff = wNew - wOld;
          final double pct = wOld > 0 ? (diff / wOld) * 100 : 0.0;

          // Vet threshold: Rapid weight gain >= 10% over the trend duration
          if (pct >= 10.0) {
            alerts.add(CattleAlert(
              cowId: cowId,
              name: name,
              type: AlertType.rapidGain,
              count: incCount,
              message: "Cattle $name (ID: $cowId) has shown a continuous, rapid weight gain of ${diff.toStringAsFixed(1)} kg (+${pct.toStringAsFixed(1)}%) over the last $incCount consecutive measurements. Check feeding levels or pregnancy status.",
            ));
          }
        }
      }
    });

    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _calculateAlerts();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006D60),
        foregroundColor: Colors.white,
        title: const Text('Herd Health Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Text(
              'ACTIVE ALERTS (${alerts.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006D60),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Alerts list
            Expanded(
              child: alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.green[600]),
                          const SizedBox(height: 16),
                          const Text(
                            'Your herd is healthy!',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No critical weight loss or gain trends detected.',
                            style: TextStyle(color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: alerts.length,
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        final isLoss = alert.type == AlertType.criticalLoss;

                        return Card(
                          elevation: 2,
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isLoss ? Colors.red[300]! : Colors.orange[300]!,
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left icon
                                CircleAvatar(
                                  backgroundColor: isLoss ? Colors.red[50] : Colors.orange[50],
                                  child: Icon(
                                    isLoss ? Icons.warning_amber_rounded : Icons.trending_up,
                                    color: isLoss ? Colors.red[800] : Colors.orange[800],
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Alert details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            isLoss ? 'CRITICAL WEIGHT LOSS' : 'RAPID WEIGHT GAIN',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isLoss ? Colors.red[800] : Colors.orange[800],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isLoss ? Colors.red[50] : Colors.orange[50],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${alert.count} days',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isLoss ? Colors.red[800] : Colors.orange[800],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        alert.message,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
