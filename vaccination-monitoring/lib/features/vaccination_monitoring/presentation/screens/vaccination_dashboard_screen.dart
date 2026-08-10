import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/vaccination_model.dart';
import '../providers/vaccination_provider.dart';
import '../widgets/recent_log_tile.dart';
import 'add_vaccine_screen.dart';
import 'reminder_screen.dart';
import 'vaccination_history_screen.dart';
import 'vaccination_report_screen.dart';

class VaccinationDashboardScreen extends StatefulWidget {
  const VaccinationDashboardScreen({Key? key}) : super(key: key);

  @override
  State<VaccinationDashboardScreen> createState() => _VaccinationDashboardScreenState();
}

class _VaccinationDashboardScreenState extends State<VaccinationDashboardScreen> {
  final _vaccineFormKey = GlobalKey<FormState>();
  final _reminderFormKey = GlobalKey<FormState>();

  // Form Field Controllers (Dashboard inputs matching screenshot placeholders)
  final _cattleNameController = TextEditingController();
  final _cattleIdController = TextEditingController();
  final _vaccineNameController = TextEditingController();
  DateTime? _vaccineDate;

  final _remNameController = TextEditingController();
  final _remDescController = TextEditingController();
  DateTime? _remDate;

  @override
  void dispose() {
    _cattleNameController.dispose();
    _cattleIdController.dispose();
    _vaccineNameController.dispose();
    _remNameController.dispose();
    _remDescController.dispose();
    super.dispose();
  }

  void _submitVaccineEntry(VaccinationProvider provider) async {
    if (_vaccineFormKey.currentState!.validate()) {
      if (_vaccineDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a vaccine date'), backgroundColor: AppTheme.dangerRed),
        );
        return;
      }
      try {
        await provider.addVaccinationEntry(
          cattleId: _cattleIdController.text.trim(),
          cattleName: _cattleNameController.text.trim(),
          vaccineName: _vaccineNameController.text.trim(),
          vaccinationDate: _vaccineDate!,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vaccination logged successfully! Reminder scheduled.'),
            backgroundColor: AppTheme.primaryTeal,
          ),
        );

        _cattleIdController.clear();
        _cattleNameController.clear();
        _vaccineNameController.clear();
        setState(() {
          _vaccineDate = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppTheme.dangerRed),
        );
      }
    }
  }

  void _submitReminderEntry(VaccinationProvider provider) async {
    if (_reminderFormKey.currentState!.validate()) {
      if (_remDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a reminder date'), backgroundColor: AppTheme.dangerRed),
        );
        return;
      }
      try {
        await provider.addCustomReminder(
          vaccineName: _remNameController.text.trim(),
          reminderDate: _remDate!,
          description: _remDescController.text.trim(),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom vaccination reminder set!'),
            backgroundColor: AppTheme.primaryTeal,
          ),
        );

        _remNameController.clear();
        _remDescController.clear();
        setState(() {
          _remDate = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save reminder: $e'), backgroundColor: AppTheme.dangerRed),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isVaccine) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryTeal,
              onPrimary: Colors.white,
              onSurface: AppTheme.darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isVaccine) {
          _vaccineDate = picked;
        } else {
          _remDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VaccinationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // App shell navigation
          },
        ),
        title: const Text(
          'Vaccine Monitoring System',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (context, _, __) => const VaccinationReportScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            ),
            tooltip: 'Vaccination Report',
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VaccinationHistoryScreen()),
            ),
            tooltip: 'All Logs',
          ),
        ],
      ),
      body: Consumer<VaccinationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal));
          }

          return RefreshIndicator(
            onRefresh: () async {
              provider.checkOverdueRecords();
            },
            color: AppTheme.primaryTeal,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form 1: New Vaccine Entry Card
                  _buildNewVaccineEntryCard(provider),
                  const SizedBox(height: 16),

                  // Form 2: Vaccination Remainder(optional) Card
                  _buildVaccinationReminderCard(provider),
                  const SizedBox(height: 24),

                  // Alarms & Notifications Section
                  _buildAlarmsSection(provider),

                  // Recent Logs Section Header
                  const Text(
                    'Recent Logs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2-Column Grid Layout for Recent Logs (Limited to recently updated 2 cattle)
                  Builder(
                    builder: (context) {
                      // Filter to show only the latest vaccination record for each unique cattle ID
                      final Map<String, VaccinationModel> latestCattleVacs = {};
                      for (var vac in provider.vaccinations) {
                        final current = latestCattleVacs[vac.cattleId];
                        if (current == null || vac.vaccinationDate.isAfter(current.vaccinationDate)) {
                          latestCattleVacs[vac.cattleId] = vac;
                        }
                      }
                      final uniqueVacs = latestCattleVacs.values.toList();
                      uniqueVacs.sort((a, b) => b.vaccinationDate.compareTo(a.vaccinationDate));
                      
                      // Show only the 2 most recently updated cattle
                      final recentTwo = uniqueVacs.take(2).toList();

                      if (recentTwo.isEmpty) {
                        return const Center(child: Text('No vaccination records logged.', style: TextStyle(color: AppTheme.lightText)));
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentTwo.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.84, // Compact design matching screenshot ratio
                        ),
                        itemBuilder: (context, index) {
                          final vac = recentTwo[index];
                          return RecentLogTile(
                            vaccination: vac,
                            onTap: () {
                              // Open the dynamic pop-up report screen as a translucent route overlay
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  opaque: false,
                                  pageBuilder: (context, _, __) => VaccinationReportScreen(
                                    cattleId: vac.cattleId,
                                    cattleName: vac.cattleName,
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(opacity: animation, child: child);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // New Section: All Cattle Directory showing detailed vaccinations
                  _buildAllCattleDirectory(provider),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.lightText,
        ),
      ),
    );
  }

  Widget _buildNewVaccineEntryCard(VaccinationProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _vaccineFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header of Form
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.vaccines_outlined, color: AppTheme.accentTeal, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'New Vaccine Entry',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFF3EFE3), height: 20),

              // Cattle Name field
              _buildFieldLabel('Cattle Name'),
              TextFormField(
                controller: _cattleNameController,
                decoration: const InputDecoration(hintText: 'e.g. Lakshmi'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter cattle name' : null,
              ),
              const SizedBox(height: 12),

              // Cattle ID field
              _buildFieldLabel('Cattle ID'),
              TextFormField(
                controller: _cattleIdController,
                decoration: const InputDecoration(hintText: 'e.g. KP-204'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter cattle ID' : null,
              ),
              const SizedBox(height: 12),

              // Vaccine Name field
              _buildFieldLabel('Vaccine Name'),
              TextFormField(
                controller: _vaccineNameController,
                decoration: const InputDecoration(hintText: 'Enter Vaccine name'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter vaccine name' : null,
              ),
              const SizedBox(height: 12),

              // Vaccine Date picker
              _buildFieldLabel('Vaccine Date'),
              InkWell(
                onTap: () => _selectDate(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.fieldFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _vaccineDate == null
                            ? 'mm/dd/yyyy'
                            : DateFormat('MM/dd/yyyy').format(_vaccineDate!),
                        style: TextStyle(
                          fontSize: 13,
                          color: _vaccineDate == null ? const Color(0xFFA6B3B0) : AppTheme.darkText,
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: AppTheme.primaryTeal, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _submitVaccineEntry(provider),
                  icon: const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.white),
                  label: const Text('Save Vaccine Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVaccinationReminderCard(VaccinationProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _reminderFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header of Form
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: AppTheme.accentTeal, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Vaccination Remainder(optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFF3EFE3), height: 20),

              // Vaccine Name field
              _buildFieldLabel('Vaccine Name'),
              TextFormField(
                controller: _remNameController,
                decoration: const InputDecoration(hintText: 'Enter Vaccine name'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter vaccine name' : null,
              ),
              const SizedBox(height: 12),

              // Vaccine Date picker
              _buildFieldLabel('Vaccine Date'),
              InkWell(
                onTap: () => _selectDate(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.fieldFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _remDate == null
                            ? 'mm/dd/yyyy'
                            : DateFormat('MM/dd/yyyy').format(_remDate!),
                        style: TextStyle(
                          fontSize: 13,
                          color: _remDate == null ? const Color(0xFFA6B3B0) : AppTheme.darkText,
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: AppTheme.primaryTeal, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Description field
              _buildFieldLabel('Description'),
              TextFormField(
                controller: _remDescController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Type here'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 16),

              // Set Reminder button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _submitReminderEntry(provider),
                  icon: const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.white),
                  label: const Text('Set Vaccination Remainder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ALARMS & UPCOMING ALERTS BANNER SECTION
  Widget _buildAlarmsSection(VaccinationProvider provider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter vaccinations with next reminders within 3 days (or overdue)
    final alertVacs = provider.vaccinations.where((v) {
      final daysRemaining = v.nextReminderDate.difference(today).inDays;
      // Show alerts starting from 3 days before the reminder date
      return daysRemaining >= -30 && daysRemaining <= 3;
    }).toList();

    if (alertVacs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_active, color: AppTheme.dangerRed, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Active Alarms & Reminders',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.dangerRed,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.dangerRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${alertVacs.length}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: alertVacs.length,
          itemBuilder: (context, index) {
            final vac = alertVacs[index];
            final daysRemaining = vac.nextReminderDate.difference(today).inDays;
            
            String alertMsg;
            Color cardBg;
            Color borderCol;
            Color textCol;
            
            if (daysRemaining < 0) {
              alertMsg = 'Overdue by ${daysRemaining.abs()} days!';
              cardBg = const Color(0xFFFFEBEE); // Light pinkish red
              borderCol = const Color(0xFFEF9A9A);
              textCol = const Color(0xFFC62828);
            } else if (daysRemaining == 0) {
              alertMsg = 'DUE TODAY!';
              cardBg = const Color(0xFFFFF3E0); // Light orange
              borderCol = const Color(0xFFFFB74D);
              textCol = const Color(0xFFE65100);
            } else {
              alertMsg = 'Due in $daysRemaining days (Alert active)';
              cardBg = const Color(0xFFFFFDE7); // Light yellow
              borderCol = const Color(0xFFFFF59D);
              textCol = const Color(0xFFF57F17);
            }

            // Format date as DD/MM/YYYY
            final formattedDueDate = DateFormat('dd/MM/yyyy').format(vac.nextReminderDate);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderCol, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: textCol, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${vac.cattleName} (ID: ${vac.cattleId})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkText,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: textCol.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  alertMsg,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: textCol,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vaccine Name: ${vac.vaccineName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.darkText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Next Vaccination Due Date: $formattedDueDate',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.lightText,
                              fontWeight: FontWeight.bold,
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
        const SizedBox(height: 16),
      ],
    );
  }

  // ALL CATTLE DIRECTORY (WITH EXPANSION DETAIL LOGS)
  Widget _buildAllCattleDirectory(VaccinationProvider provider) {
    // Group all vaccinations by cattleId
    final Map<String, List<VaccinationModel>> groupedVacs = {};
    for (var vac in provider.vaccinations) {
      groupedVacs.putIfAbsent(vac.cattleId, () => []).add(vac);
    }

    final cattleIds = groupedVacs.keys.toList();
    // Sort cattle so that the one with most recent activity is first
    cattleIds.sort((a, b) {
      final lastA = groupedVacs[a]!.map((v) => v.vaccinationDate).reduce((m, d) => d.isAfter(m) ? d : m);
      final lastB = groupedVacs[b]!.map((v) => v.vaccinationDate).reduce((m, d) => d.isAfter(m) ? d : m);
      return lastB.compareTo(lastA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All Cattle Vaccination Records',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTeal,
          ),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cattleIds.length,
          itemBuilder: (context, index) {
            final cid = cattleIds[index];
            final list = groupedVacs[cid]!;
            // Sort list descending by vaccinationDate
            list.sort((a, b) => b.vaccinationDate.compareTo(a.vaccinationDate));
            
            final first = list.first;
            final totalDoses = list.length;
            final formattedTotal = totalDoses < 10 ? '0$totalDoses' : '$totalDoses';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryTeal.withOpacity(0.08),
                    radius: 20,
                    child: const Icon(Icons.pets, color: AppTheme.primaryTeal, size: 20),
                  ),
                  title: Row(
                    children: [
                      Text(
                        first.cattleName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EFE3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cid,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.lightText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Doses: $formattedTotal | Latest: ${first.vaccineName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.lightText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    const Divider(color: Color(0xFFF3EFE3), height: 1),
                    const SizedBox(height: 8),
                    // List of all vaccination details for this cattle
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (context, i) => const Divider(color: Color(0xFFF3EFE3), height: 16),
                      itemBuilder: (context, i) {
                        final v = list[i];
                        final formattedDate = DateFormat('dd/MM/yyyy').format(v.vaccinationDate);
                        final formattedReminder = DateFormat('dd/MM/yyyy').format(v.nextReminderDate);
                        
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.vaccineName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.darkText,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        'Date: $formattedDate',
                                        style: const TextStyle(fontSize: 10, color: AppTheme.lightText),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Next reminder: $formattedReminder',
                                        style: const TextStyle(fontSize: 10, color: AppTheme.lightText),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: v.status.toLowerCase() == 'completed'
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                v.status,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: v.status.toLowerCase() == 'completed'
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFE65100),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Action button to open full report pop-up dialog
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Open the dynamic pop-up report screen as a translucent route overlay
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (context, _, __) => VaccinationReportScreen(
                                cattleId: cid,
                                cattleName: first.cattleName,
                              ),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics_outlined, size: 14, color: AppTheme.primaryTeal),
                        label: const Text(
                          'View Full Report Dialog',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryTeal),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
