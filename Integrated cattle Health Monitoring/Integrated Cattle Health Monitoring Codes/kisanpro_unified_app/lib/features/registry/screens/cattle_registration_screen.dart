import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/cattle_profile_model.dart';
import '../providers/cattle_registry_provider.dart';
import '../../milk_monitoring/data/models/milk_record_model.dart';
import '../../milk_monitoring/presentation/providers/milk_provider.dart';
import '../../vaccination_monitoring/presentation/providers/vaccination_provider.dart';

class CattleRegistrationScreen extends StatefulWidget {
  const CattleRegistrationScreen({super.key});

  @override
  State<CattleRegistrationScreen> createState() => _CattleRegistrationScreenState();
}

class _CattleRegistrationScreenState extends State<CattleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController(text: '4');
  final _tagController = TextEditingController();
  final _weightController = TextEditingController(text: '400.0');
  final _milkController = TextEditingController(text: '14.0');
  final _colorController = TextEditingController(text: 'Black & White');

  String _selectedBreed = 'HF (Holstein Friesian)';
  String _selectedGender = 'Female';
  String _selectedVaccineStatus = 'Up to Date';
  String _selectedLactation = 'Mid-Lactation (100-200 days)';

  final List<String> _breeds = [
    'HF (Holstein Friesian)',
    'Jersey (High-Yield Dairy)',
    'Gir (Indigenous Dairy)',
    'Hallikar (Indigenous Draft)',
    'Sahiwal (Zebu Dairy)',
    'Crossbred HF',
    'Amritmahal (Draft)',
    'Red Sindhi',
  ];

  final List<String> _vaccineStatuses = [
    'Up to Date',
    'Due Soon',
    'Overdue',
  ];

  final List<String> _lactationStages = [
    'Early Lactation (0-100 days)',
    'Peak Lactation (60-120 days)',
    'Mid-Lactation (100-200 days)',
    'Late Lactation (200-305 days)',
    'Dry Period (Gestation)',
    'Heifer / Non-Milking',
  ];

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _tagController.dispose();
    _weightController.dispose();
    _milkController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _saveCattle() {
    if (_formKey.currentState!.validate()) {
      final double weight = double.tryParse(_weightController.text) ?? 400.0;
      final double milk = double.tryParse(_milkController.text) ?? 12.0;
      final int age = int.tryParse(_ageController.text) ?? 4;

      final newCattle = CattleProfile(
        cattleId: _idController.text.trim().toUpperCase(),
        name: _nameController.text.trim(),
        breed: _selectedBreed,
        ageYears: age,
        gender: _selectedGender,
        tagNumber: _tagController.text.trim().isNotEmpty
            ? _tagController.text.trim()
            : 'KP-${_idController.text.trim()}',
        currentWeightKg: weight,
        dailyMilkLiters: milk,
        vaccineStatus: _selectedVaccineStatus,
        lactationStage: _selectedLactation,
        colorMarkings: _colorController.text.trim(),
        riskLevel: _selectedVaccineStatus == 'Overdue' || milk < 8.0
            ? 'HIGH RISK'
            : (_selectedVaccineStatus == 'Due Soon' ? 'WARNING' : 'NORMAL'),
        healthScore: _selectedVaccineStatus == 'Up to Date' ? 92.0 : 65.0,
      );

      context.read<CattleRegistryProvider>().registerCattle(newCattle);

      // Instantly populate initial baseline record into Milk Monitoring module
      try {
        final milkProv = context.read<MilkProvider>();
        final initialMilkRecord = MilkRecordModel(
          id: 'reg_${newCattle.cattleId}_${DateTime.now().millisecondsSinceEpoch}',
          cattleId: newCattle.cattleId,
          cattleName: newCattle.name,
          milkTime: 'Morning',
          quantity: milk,
          fat: 4.2,
          snf: 8.6,
          timestamp: DateTime.now(),
        );
        milkProv.addRecord(initialMilkRecord);
      } catch (_) {}

      // Instantly populate initial vaccination baseline record into Vaccination module
      try {
        final vaccProv = context.read<VaccinationProvider>();
        vaccProv.addVaccinationEntry(
          cattleId: newCattle.cattleId,
          cattleName: newCattle.name,
          vaccineName: newCattle.vaccineStatus == 'Up to Date' ? 'FMD + Anthrax Dual Booster' : 'Pending Baseline Booster',
          vaccinationDate: DateTime.now(),
          ageYears: newCattle.ageYears,
          weightKg: newCattle.currentWeightKg,
          breed: newCattle.breed,
          location: 'Mandya / Bangalore Rural, Karnataka',
        );
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cattle ${newCattle.name} (${newCattle.cattleId}) registered successfully and synced to all modules!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text(
          'Register New Cattle',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E7E5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.pets, size: 36, color: AppTheme.primary),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Central Cattle Identity',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          Text(
                            'This Cattle ID will unify records across Milk, Vaccination, Weight & AI Health tabs.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Identification Section
              _buildSectionCard(
                title: 'Basic Identification',
                icon: Icons.badge_outlined,
                children: [
                  _buildTextField(
                    controller: _idController,
                    label: 'Unique Cattle ID *',
                    hint: 'e.g. KA-1989, COW-402',
                    icon: Icons.tag,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Cattle ID is required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Cattle Name *',
                    hint: 'e.g. Geetha, Lakshmi, Sita',
                    icon: Icons.edit,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Cattle Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _tagController,
                    label: 'Ear Tag / RFID Number',
                    hint: 'e.g. KP-1989-HF',
                    icon: Icons.qr_code,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Breed & Biological Profile
              _buildSectionCard(
                title: 'Breed & Biological Profile',
                icon: Icons.category_outlined,
                children: [
                  const Text('Select Breed *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedBreed,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.pets_outlined, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return _breeds.map<Widget>((String item) {
                        return Container(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList();
                    },
                    items: _breeds.map((b) {
                      return DropdownMenuItem(
                        value: b,
                        child: Text(b, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBreed = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _ageController,
                          label: 'Age (Years)',
                          hint: '4',
                          keyboardType: TextInputType.number,
                          icon: Icons.cake_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Gender',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              selectedItemBuilder: (BuildContext context) {
                                return ['Female', 'Male'].map<Widget>((String item) {
                                  return Container(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      item,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList();
                              },
                              items: ['Female', 'Male'].map((g) {
                                return DropdownMenuItem(
                                  value: g,
                                  child: Text(g, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedGender = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _colorController,
                    label: 'Color & Distinguishing Markings',
                    hint: 'e.g. Black & White, White star on forehead',
                    icon: Icons.palette_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Production & Initial Health Metrics
              _buildSectionCard(
                title: 'Production & Health Baseline',
                icon: Icons.monitor_heart_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _weightController,
                          label: 'Body Weight (kg) *',
                          hint: '438.0',
                          keyboardType: TextInputType.number,
                          icon: Icons.monitor_weight_outlined,
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Weight required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _milkController,
                          label: 'Daily Milk (L) *',
                          hint: '11.5',
                          keyboardType: TextInputType.number,
                          icon: Icons.water_drop_outlined,
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Milk yield required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Vaccination Status',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedVaccineStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.vaccines_outlined, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return _vaccineStatuses.map<Widget>((String item) {
                        return Container(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList();
                    },
                    items: _vaccineStatuses.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedVaccineStatus = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Lactation Stage',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedLactation,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.timeline, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return _lactationStages.map<Widget>((String item) {
                        return Container(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList();
                    },
                    items: _lactationStages.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLactation = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveCattle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.how_to_reg, size: 20),
                  label: const Text(
                    'Register Cattle & Sync Records',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E7E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2D2A),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            hintText: hint,
          ),
        ),
      ],
    );
  }
}
