import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/vaccination_provider.dart';

class AiAlertsScreen extends StatefulWidget {
  const AiAlertsScreen({Key? key}) : super(key: key);

  @override
  State<AiAlertsScreen> createState() => _AiAlertsScreenState();
}

class _AiAlertsScreenState extends State<AiAlertsScreen> {
  String _selectedFilter = 'All'; // 'All', 'High', 'Medium', 'Low'

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VaccinationProvider>(context);
    final allAlerts = provider.getActiveAiAlerts();
    
    // Apply filtering
    final filteredAlerts = allAlerts.where((alert) {
      if (_selectedFilter == 'All') return true;
      return alert['riskLevel'].toString().toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();

    // Summary counts
    final highCount = allAlerts.where((a) => a['riskLevel'] == 'High').length;
    final mediumCount = allAlerts.where((a) => a['riskLevel'] == 'Medium').length;
    final lowCount = allAlerts.where((a) => a['riskLevel'] == 'Low').length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E8),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        title: const Text(
          'AI Health Alerts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Alert Summary Cards Bar
          _buildSummaryCards(highCount, mediumCount, lowCount),
          
          // 2. Filters Row
          _buildFilterRow(),
          
          // 3. Alerts List
          Expanded(
            child: filteredAlerts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredAlerts.length,
                    itemBuilder: (context, index) {
                      final alert = filteredAlerts[index];
                      return _buildAlertCard(context, alert);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(int high, int medium, int low) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HERD HEALTH STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMetricCard('High Risk', high.toString(), Colors.red[800]!, Colors.red[50]!),
              const SizedBox(width: 10),
              _buildMetricCard('Medium Risk', medium.toString(), Colors.orange[800]!, Colors.orange[50]!),
              const SizedBox(width: 10),
              _buildMetricCard('Low Risk', low.toString(), Colors.blue[800]!, Colors.blue[50]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String count, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', 'High', 'Medium', 'Low'].map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(
                  filter == 'All' ? 'All Alerts' : '$filter Risk',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppTheme.darkText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppTheme.primaryTeal,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : const Color(0xFFE5DFD0),
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green[600]),
          const SizedBox(height: 16),
          const Text(
            'No Alerts Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Your herd is healthy and up to date.'
                : 'No active $_selectedFilter Risk warnings calculated.',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Map<String, dynamic> alert) {
    final isHigh = alert['riskLevel'] == 'High';
    final isMedium = alert['riskLevel'] == 'Medium';
    final Color borderCol = isHigh
        ? Colors.red[300]!
        : isMedium
            ? Colors.orange[300]!
            : Colors.blue[300]!;

    return Card(
      color: Colors.white,
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderCol, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isHigh
                          ? Colors.red[50]
                          : isMedium
                              ? Colors.orange[50]
                              : Colors.blue[50],
                      child: Icon(
                        isHigh
                            ? Icons.warning_amber_rounded
                            : isMedium
                                ? Icons.trending_up
                                : Icons.info_outline,
                        size: 16,
                        color: isHigh
                            ? Colors.red[800]
                            : isMedium
                                ? Colors.orange[800]
                                : Colors.blue[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${alert['cattleName']} (${alert['cattleId']})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkText),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isHigh
                        ? Colors.red[50]
                        : isMedium
                            ? Colors.orange[50]
                            : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${alert['riskLevel']}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isHigh
                          ? Colors.red[800]
                          : isMedium
                              ? Colors.orange[800]
                              : Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Disease Risk: ${alert['disease']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkText),
            ),
            const SizedBox(height: 4),
            Text(
              alert['reason'],
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.fieldFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vaccines_outlined, color: AppTheme.primaryTeal, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suggested action: ${alert['vaccine']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _showDiseaseDetailsDialog(context, alert),
                icon: const Icon(Icons.help_outline, size: 14, color: Colors.white),
                label: const Text('Disease Awareness Info'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiseaseDetailsDialog(BuildContext context, Map<String, dynamic> alert) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.health_and_safety_outlined, color: AppTheme.primaryTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Disease Info: ${alert['disease']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'EXPECTED SYMPTOMS:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['symptoms'] ?? 'No symptoms data',
                  style: const TextStyle(fontSize: 13, color: AppTheme.darkText),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PREVENTION & CARE:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['prevention'] ?? 'No prevention data',
                  style: const TextStyle(fontSize: 13, color: AppTheme.darkText),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CLINICAL INTERVENTION & PRESCRIPTION:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['clinicalDetails'] ?? 'No clinical guidance',
                  style: const TextStyle(fontSize: 13, color: AppTheme.darkText),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppTheme.primaryTeal)),
            ),
          ],
        );
      },
    );
  }
}
