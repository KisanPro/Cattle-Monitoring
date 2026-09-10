import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/pdf_generator.dart';
import '../providers/vaccination_provider.dart';
import '../widgets/report_chart_widget.dart';

class VaccinationReportScreen extends StatefulWidget {
  final String cattleId;
  final String cattleName;

  const VaccinationReportScreen({
    Key? key,
    this.cattleId = 'KP-204',
    this.cattleName = 'Lakshmi',
  }) : super(key: key);

  @override
  State<VaccinationReportScreen> createState() => _VaccinationReportScreenState();
}

class _VaccinationReportScreenState extends State<VaccinationReportScreen> {
  String _activeTab = 'Weekly'; // 'Weekly', 'Monthly'

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VaccinationProvider>(context);

    // Focus on target cattle data (dynamic fallback to first available if default not found)
    String targetId = widget.cattleId;
    String targetName = widget.cattleName;

    if (provider.vaccinations.isNotEmpty && 
        !provider.vaccinations.any((v) => v.cattleId == targetId)) {
      final firstCattle = provider.vaccinations.first;
      targetId = firstCattle.cattleId;
      targetName = firstCattle.cattleName;
    }
    
    final filteredVaccinations = provider.vaccinations.where((v) => v.cattleId == targetId).toList();
    // Sort to ensure chronological order descending (latest first)
    filteredVaccinations.sort((a, b) => b.vaccinationDate.compareTo(a.vaccinationDate));
    
    final filteredReminders = provider.reminders.where((r) => r.description.contains(targetId)).toList();

    // Stats matching Image 2
    final totalVaccinations = filteredVaccinations.length;
    final formattedTotal = totalVaccinations < 10 ? '0$totalVaccinations' : '$totalVaccinations';
    
    final lastDose = filteredVaccinations.isNotEmpty ? filteredVaccinations.first : null;
    final lastDoseName = lastDose?.vaccineName ?? 'FMD Vaccine';
    final lastDoseDate = lastDose != null
        ? DateFormat('dd MMMM yyyy').format(lastDose.vaccinationDate)
        : '14 May 2026';

    return Scaffold(
      backgroundColor: const Color(0x991A2E2A), // Translucent dark green-grey backdrop matching Image 2
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360), // Fits mobile viewports
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE5DFD3), // Beige/Cream card background matching Image 2
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title & Subtitle
                Text(
                  '$targetName Vaccine\nReport',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTeal,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vaccination history for $targetId',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.lightText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Segmented Pill Tabs (Weekly, Monthly)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EFE3).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildTabButton('Weekly')),
                      Expanded(child: _buildTabButton('Monthly')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Core Analytics Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDCD6C8), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(fontSize: 10, color: AppTheme.lightText, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'VACCINATIONS',
                                style: TextStyle(fontSize: 10, color: AppTheme.lightText, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedTotal,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryTeal,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'LAST DOSE',
                                style: TextStyle(fontSize: 10, color: AppTheme.lightText, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lastDoseName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                              ),
                              Text(
                                lastDoseDate,
                                style: const TextStyle(fontSize: 12, color: AppTheme.lightText, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Chart
                      ReportChartWidget(type: _activeTab, vaccinations: filteredVaccinations),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Side-by-side details cards
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailCard(
                        icon: Icons.vaccines_outlined,
                        title: 'Vaccine Type',
                        value: lastDoseName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDetailCard(
                        icon: Icons.calendar_today_outlined,
                        title: 'Administered',
                        value: lastDoseDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // All Administered Doses list for this cattle
                Row(
                  children: [
                    const Icon(Icons.history, size: 14, color: AppTheme.primaryTeal),
                    const SizedBox(width: 6),
                    const Text(
                      'All Administered Doses',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$totalVaccinations doses',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.lightText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDCD6C8), width: 1),
                  ),
                  child: filteredVaccinations.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'No vaccination records found.',
                              style: TextStyle(fontSize: 11, color: AppTheme.lightText),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredVaccinations.length,
                          separatorBuilder: (context, index) => const Divider(color: Color(0xFFF3EFE3), height: 16),
                          itemBuilder: (context, index) {
                            final v = filteredVaccinations[index];
                            final dateStr = DateFormat('dd MMM yyyy').format(v.vaccinationDate);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v.vaccineName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.darkText,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Next reminder: ${DateFormat('dd MMM yyyy').format(v.nextReminderDate)}',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: AppTheme.lightText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryTeal,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => await PdfGenerator.generateVaccinationReport(
                            cattleName: targetName,
                            cattleId: targetId,
                            vaccinations: filteredVaccinations,
                            reminders: filteredReminders,
                            complianceRate: 100.0,
                            totalVaccinations: totalVaccinations,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: AppTheme.dangerRed),
                        );
                      }
                    },
                    icon: const Icon(Icons.download, size: 16, color: Colors.white),
                    label: const Text('Generate Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dangerRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: const Text(
                      'Close Preview',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabName) {
    final isActive = _activeTab == tabName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tabName;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          tabName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : AppTheme.darkText,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCD6C8), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryTeal, size: 16),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: AppTheme.lightText, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
