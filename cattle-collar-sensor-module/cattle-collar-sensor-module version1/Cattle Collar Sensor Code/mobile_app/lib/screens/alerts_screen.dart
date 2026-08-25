import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cattle_provider.dart';
import '../models/alert_model.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CattleProvider>();
    final alerts = provider.alertsList;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            const Text(
              'Live Anomaly Alerts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            if (provider.unacknowledgedAlertsCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.unacknowledgedAlertsCount}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
      body: alerts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 56, color: Color(0xFF10B981)),
                  SizedBox(height: 12),
                  Text(
                    'No Active Anomaly Alerts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'All livestock collars operating within normal baseline.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _buildAlertCard(context, provider, alert);
              },
            ),
    );
  }

  Widget _buildAlertCard(
      BuildContext context, CattleProvider provider, AlertModel alert) {
    Color severityColor = const Color(0xFF38BDF8);
    IconData severityIcon = Icons.info_outline;

    if (alert.isCritical) {
      severityColor = Colors.redAccent;
      severityIcon = Icons.error_outline;
    } else if (alert.isWarning) {
      severityColor = Colors.amber;
      severityIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alert.acknowledged
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: alert.acknowledged
              ? const Color(0xFF334155)
              : severityColor.withOpacity(0.5),
          width: alert.acknowledged ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(severityIcon, color: severityColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    alert.alertType.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: severityColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alert.cowId,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.message,
            style: TextStyle(
              fontSize: 13,
              color: alert.acknowledged ? const Color(0xFF94A3B8) : Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                alert.timestamp,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              if (!alert.acknowledged)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: severityColor.withOpacity(0.2),
                    foregroundColor: severityColor,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: severityColor),
                    ),
                  ),
                  onPressed: () => provider.acknowledgeAlert(alert.id),
                  child: const Text('Acknowledge', style: TextStyle(fontSize: 11)),
                )
              else
                const Row(
                  children: [
                    Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text(
                      'Acknowledged',
                      style: TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
