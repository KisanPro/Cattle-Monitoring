import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/vaccination_model.dart';
import '../providers/vaccination_provider.dart';
import '../widgets/recent_log_tile.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../registry/providers/cattle_registry_provider.dart';
import 'vaccination_history_screen.dart';
import 'vaccination_report_screen.dart';
import 'ai_alerts_screen.dart';

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

  // New AI/Weight integration fields
  final _cattleAgeController = TextEditingController();
  final _cattleWeightController = TextEditingController();
  final _cattleBreedController = TextEditingController();
  final _farmerLocationController = TextEditingController();
  bool _isDetectingLocation = false;

  final _remNameController = TextEditingController();
  final _remDescController = TextEditingController();
  DateTime? _remDate;

  String? _lastCattleId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final currentCattle = context.watch<CattleRegistryProvider>().selectedCattle;
      if (_lastCattleId != currentCattle.cattleId) {
        _lastCattleId = currentCattle.cattleId;
        _cattleIdController.text = currentCattle.cattleId;
        _cattleNameController.text = currentCattle.name;
        _cattleBreedController.text = currentCattle.breed;
        _cattleAgeController.text = currentCattle.ageYears.toString();
        _cattleWeightController.text = currentCattle.currentWeightKg.toString();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cattleNameController.dispose();
    _cattleIdController.dispose();
    _vaccineNameController.dispose();
    _cattleAgeController.dispose();
    _cattleWeightController.dispose();
    _cattleBreedController.dispose();
    _farmerLocationController.dispose();
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
        final age = int.tryParse(_cattleAgeController.text.trim());
        final weight = double.tryParse(_cattleWeightController.text.trim());
        final breed = _cattleBreedController.text.trim();
        final location = _farmerLocationController.text.trim();

        await provider.addVaccinationEntry(
          cattleId: _cattleIdController.text.trim(),
          cattleName: _cattleNameController.text.trim(),
          vaccineName: _vaccineNameController.text.trim(),
          vaccinationDate: _vaccineDate!,
          ageYears: age,
          weightKg: weight,
          breed: breed,
          location: location,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vaccination logged successfully! AI predictions generated.'),
            backgroundColor: AppTheme.primaryTeal,
          ),
        );

        _cattleIdController.clear();
        _cattleNameController.clear();
        _vaccineNameController.clear();
        _cattleAgeController.clear();
        _cattleWeightController.clear();
        _cattleBreedController.clear();
        _farmerLocationController.clear();
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

  Future<void> _detectLocation() async {
    setState(() {
      _isDetectingLocation = true;
    });
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final region = data['region'] ?? '';
        if (region.isNotEmpty) {
          _farmerLocationController.text = region;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location auto-detected: $region'),
              backgroundColor: AppTheme.primaryTeal,
            ),
          );
        } else {
          throw Exception('Region empty');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not auto-detect location ($e). Please type manually.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    } finally {
      setState(() {
        _isDetectingLocation = false;
      });
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
    return Scaffold(
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Header & Quick Action Strip ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.vaccines, color: AppTheme.primaryTeal, size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Vaccine Schedule & Logs',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTeal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.analytics_outlined, color: AppTheme.primaryTeal, size: 20),
                          tooltip: 'Vaccination Report',
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
                        ),
                        IconButton(
                          icon: const Icon(Icons.auto_awesome, color: AppTheme.primaryTeal, size: 20),
                          tooltip: 'AI Health Alerts',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AiAlertsScreen()),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.history_outlined, color: AppTheme.primaryTeal, size: 20),
                          tooltip: 'All Logs',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const VaccinationHistoryScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Real-Time Geo-Epidemiological Outbreak Radar Banner ──
                  _buildLiveOutbreakBanner(),
                  const SizedBox(height: 14),

                  // Form 1: New Vaccine Entry Card
                  _buildNewVaccineEntryCard(provider),
                  const SizedBox(height: 16),

                  // Form 2: Vaccination Remainder(optional) Card
                  _buildVaccinationReminderCard(provider),
                  const SizedBox(height: 24),

                  // Alarms & Notifications Section
                  _buildAlarmsSection(provider),
                  const SizedBox(height: 24),

                  // AI Disease & Vaccination Predictor Section
                  _buildAiPredictionAlertsSection(provider),
                  const SizedBox(height: 24),

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
                      final registry = context.watch<CattleRegistryProvider>();
                      // Filter to show only the latest vaccination record for each unique registered cattle ID
                      final Map<String, VaccinationModel> latestCattleVacs = {};
                      for (var vac in provider.vaccinations) {
                        if (!registry.isCattleRegistered(vac.cattleId, vac.cattleName)) continue;
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

              // Cattle Quick Picker
              Consumer<CattleRegistryProvider>(
                builder: (context, registry, child) {
                  final cattles = registry.cattles;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Quick Select Registered Cattle'),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Select registered cattle...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          prefixIcon: Icon(Icons.pets_outlined, size: 20, color: AppTheme.accentTeal),
                        ),
                        selectedItemBuilder: (BuildContext context) {
                          return cattles.map<Widget>((c) {
                            return Text(
                              '${c.name} (${c.cattleId}) - ${c.breed}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 14),
                            );
                          }).toList();
                        },
                        items: cattles.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.cattleId,
                            child: Text(
                              '${c.name} (${c.cattleId}) - ${c.breed}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (selectedId) {
                          if (selectedId != null) {
                            final selected = cattles.firstWhere((c) => c.cattleId == selectedId);
                            setState(() {
                              _cattleIdController.text = selected.cattleId;
                              _cattleNameController.text = selected.name;
                              _cattleBreedController.text = selected.breed;
                              _cattleAgeController.text = selected.ageYears.toString();
                              _cattleWeightController.text = selected.currentWeightKg.toStringAsFixed(1);
                              _farmerLocationController.text = 'Mandya / Bangalore Rural, Karnataka';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),

              // Cattle ID field
              _buildFieldLabel('Cattle ID *'),
              Consumer<CattleRegistryProvider>(
                builder: (context, registry, child) {
                  return TextFormField(
                    controller: _cattleIdController,
                    decoration: const InputDecoration(hintText: 'e.g. KA-1989, COW-10'),
                    onChanged: (val) {
                      final match = registry.cattles.where(
                        (c) => c.cattleId.toUpperCase() == val.trim().toUpperCase()
                      ).firstOrNull;
                      if (match != null) {
                        _cattleNameController.text = match.name;
                        _cattleAgeController.text = match.ageYears.toString();
                        _cattleWeightController.text = match.currentWeightKg.toStringAsFixed(1);
                        _cattleBreedController.text = match.breed;
                        _farmerLocationController.text = 'Mandya / Bangalore Rural, Karnataka';
                      }
                    },
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter cattle ID' : null,
                  );
                },
              ),
              const SizedBox(height: 12),

              // Cattle Name field
              _buildFieldLabel('Cattle Name *'),
              Consumer<CattleRegistryProvider>(
                builder: (context, registry, child) {
                  return TextFormField(
                    controller: _cattleNameController,
                    decoration: const InputDecoration(hintText: 'e.g. Geetha, Lakshmi, Suma'),
                    onChanged: (val) {
                      final match = registry.cattles.where(
                        (c) => c.name.toLowerCase() == val.trim().toLowerCase()
                      ).firstOrNull;
                      if (match != null) {
                        _cattleIdController.text = match.cattleId;
                        _cattleAgeController.text = match.ageYears.toString();
                        _cattleWeightController.text = match.currentWeightKg.toStringAsFixed(1);
                        _cattleBreedController.text = match.breed;
                        _farmerLocationController.text = 'Mandya / Bangalore Rural, Karnataka';
                      }
                    },
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter cattle name' : null,
                  );
                },
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
              const SizedBox(height: 12),

              // Cattle Age field
              _buildFieldLabel('Cattle Age (Years)'),
              TextFormField(
                controller: _cattleAgeController,
                decoration: const InputDecoration(hintText: 'e.g. 4'),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter cattle age' : null,
              ),
              const SizedBox(height: 12),

              // Cattle Weight field
              _buildFieldLabel('Cattle Weight (kg)'),
              TextFormField(
                controller: _cattleWeightController,
                decoration: const InputDecoration(hintText: 'e.g. 380'),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter cattle weight' : null,
              ),
              const SizedBox(height: 12),

              // Breed field
              _buildFieldLabel('Cattle Breed'),
              TextFormField(
                controller: _cattleBreedController,
                decoration: const InputDecoration(hintText: 'e.g. Hallikar'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter breed' : null,
              ),
              const SizedBox(height: 12),

              // Location field
              _buildFieldLabel('Farmer Location / State'),
              TextFormField(
                controller: _farmerLocationController,
                decoration: InputDecoration(
                  hintText: 'e.g. Karnataka',
                  suffixIcon: _isDetectingLocation
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.my_location, color: AppTheme.accentTeal),
                          onPressed: _detectLocation,
                          tooltip: 'Auto-detect location',
                        ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter location' : null,
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
    final registry = context.watch<CattleRegistryProvider>();

    // Filter vaccinations with next reminders within 3 days (or overdue) for registered cattle
    final alertVacs = provider.vaccinations.where((v) {
      if (!registry.isCattleRegistered(v.cattleId, v.cattleName)) return false;
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
    final registry = context.watch<CattleRegistryProvider>();
    // Group all vaccinations by cattleId only for registered herd
    final Map<String, List<VaccinationModel>> groupedVacs = {};
    for (var vac in provider.vaccinations) {
      if (!registry.isCattleRegistered(vac.cattleId, vac.cattleName)) continue;
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

  Widget _buildAiPredictionAlertsSection(VaccinationProvider provider) {
    final registry = context.watch<CattleRegistryProvider>();
    final alerts = provider
        .getActiveAiAlerts()
        .where((a) => registry.isCattleRegistered(a['cattleId'], a['cattleName']))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: AppTheme.accentTeal, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'AI Disease & Vaccination Predictor',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your herd is healthy! No regional outbreaks or weight vulnerabilities estimated by AI.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: alerts.map((alert) {
              final isHigh = alert['riskLevel'] == 'High';
              final isMedium = alert['riskLevel'] == 'Medium';

              return Card(
                color: Colors.white,
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isHigh
                        ? Colors.red[300]!
                        : isMedium
                            ? Colors.orange[300]!
                            : Colors.blue[300]!,
                    width: 1.5,
                  ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.darkText,
                                ),
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
                              '${alert['riskLevel']} Risk',
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
                      const SizedBox(height: 10),
                      Text(
                        'Potential Disease: ${alert['disease']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert['reason'],
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
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
                                'Recommended action: ${alert['vaccine']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryTeal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            _showDiseaseDetailsDialog(context, alert);
                          },
                          icon: const Icon(Icons.help_outline, size: 14),
                          label: const Text('Disease Awareness Info', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.accentTeal,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
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

  // ── Real-Time Geo-Epidemiological Outbreak Radar Banner ──
  Widget _buildLiveOutbreakBanner() {
    final selectedCattle = context.watch<CattleRegistryProvider>().selectedCattle;
    final locText = _farmerLocationController.text.toLowerCase();
    final isAP = selectedCattle.cattleId.startsWith('AP') ||
        selectedCattle.breed.toLowerCase().contains('punganur') ||
        selectedCattle.breed.toLowerCase().contains('ongole') ||
        locText.contains('andhra') ||
        locText.contains('tirupati') ||
        locText.contains('chittoor') ||
        locText.contains('ap');

    final regionBadge = isAP ? 'LIVE RADAR • ANDHRA PRADESH' : 'LIVE RADAR • KARNATAKA';
    final feedSource = isAP ? 'NADCP / AP-AHVS & SVVU Feed' : 'NADCP / KAHVS Outbreak Feed';
    final title = isAP
        ? 'FMD & Anthrax Surveillance in Tirupati & Chittoor Belt'
        : 'FMD Outbreak Detected in Bengaluru & Mandya Belt';
    final description = isAP
        ? 'High transmission risk of FMD (Aphthovirus Serotype O) & soil Anthrax spore alert in Tirupati-Chittoor dairy corridor (< 25 km). Emergency Ring-Vaccination & 4% Sodium Carbonate footbath mandated by SVVU / AP Animal Husbandry.'
        : 'High-virulence Foot-and-Mouth Disease (Aphthovirus Serotype O/A) is actively spreading in your geographic radius (< 25 km). Emergency Ring-Vaccination & 4% Sodium Carbonate footbath mandated.';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF87171), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.radar, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        regionBadge,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feedSource,
                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.35),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.shield_outlined, size: 16),
                        label: const Text('View Containment Advisory', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: () => _showOutbreakAdvisoryModal(isAP),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        foregroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        setState(() {
                          _vaccineNameController.text = isAP ? 'NADCP Trivalent FMD Booster (SVVU Protocol)' : 'NADCP Trivalent FMD Booster';
                          _vaccineDate = DateTime.now();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isAP ? 'Pre-filled AP Tirupati FMD & Ring Vaccine details.' : 'Pre-filled FMD Ring Vaccination details in entry form below.'),
                            backgroundColor: const Color(0xFF006D60),
                          ),
                        );
                      },
                      child: const Text('Pre-fill FMD', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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

  void _showOutbreakAdvisoryModal(bool isAP) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7E8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.crisis_alert, color: Color(0xFFDC2626), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isAP ? 'AP Tirupati Disease Containment Advisory' : 'FMD Emergency Containment Advisory',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF991B1B)),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  isAP
                      ? 'Issued by: Andhra Pradesh Animal Husbandry & Veterinary Services (AP AH&VS) & Sri Venkateswara Veterinary University (SVVU, Tirupati) under NADCP.'
                      : 'Issued by: Karnataka Animal Husbandry & Veterinary Services (KAHVS) in coordination with NADCP (National Animal Disease Control Programme).',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '1. EMERGENCY RING VACCINATION:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                isAP
                    ? '• Immediately vaccinate all healthy cattle, buffaloes, and calves (> 3 months) within a 10 km radius using NADCP Trivalent Oil-Adjuvant Vaccine (Serotypes O, A, Asia-1).\n• For Rayalaseema pastures, verify Anthrax Sterne Strain Spore immunization.'
                    : '• Immediately vaccinate all healthy cattle, buffaloes, and calves (> 3 months) within a 10 km radius using NADCP Trivalent Oil-Adjuvant Vaccine (Serotypes O, A, Asia-1).\n• Ensure cold-chain storage at 2°C to 8°C.',
                style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
              ),
              const SizedBox(height: 12),
              const Text(
                '2. FARM BIOSECURITY LOCKDOWN:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                isAP
                    ? '• Install a 4% Sodium Carbonate (washing soda) or 0.5% Citric Acid footbath at barn gate.\n• Apply Deltamethrin 1.25% or Flumethrin pour-on to control Hyalomma tick vectors.\n• Restrict interstate cattle purchases from weekly shandies for 21 days.'
                    : '• Install a 4% Sodium Carbonate (washing soda) or 0.5% Citric Acid footbath at barn gate.\n• Restrict external visitors, cattle merchants, and inter-farm vehicle entry.\n• Quarantine newly introduced stock for minimum 21 days.',
                style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
              ),
              const SizedBox(height: 12),
              const Text(
                '3. SYMPTOM MONITORING & WOUND CARE:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              const Text(
                '• Watch for ropy stringy drool, tongue blisters, and working lameness.\n• Wash mouth lesions with 1% Potassium Permanganate (KMnO4) solution.\n• Apply Zinc Oxide + Coal Tar paste on hoof clefts to prevent secondary fly maggot strikes.',
                style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_in_talk, color: Color(0xFF059669), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAP
                            ? 'Dr. YSR Sanchara Pashu Aarogya Seva Helpline: 1962 (Toll-Free, 24x7 Ambulance & SVVU Tele-Vet)'
                            : 'Karnataka Veterinary Emergency Helpline: 1962 (Toll-Free, 24x7 Ambulance & Tele-Vet)',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF006D60), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
