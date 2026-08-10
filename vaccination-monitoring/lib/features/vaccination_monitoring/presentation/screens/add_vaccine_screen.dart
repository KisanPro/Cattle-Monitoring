import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/vaccination_provider.dart';

class AddVaccineScreen extends StatefulWidget {
  const AddVaccineScreen({Key? key}) : super(key: key);

  @override
  State<AddVaccineScreen> createState() => _AddVaccineScreenState();
}

class _AddVaccineScreenState extends State<AddVaccineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cattleIdController = TextEditingController();
  final _cattleNameController = TextEditingController();
  final _vaccineNameController = TextEditingController();
  DateTime _vaccineDate = DateTime.now();

  @override
  void dispose() {
    _cattleIdController.dispose();
    _cattleNameController.dispose();
    _vaccineNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _vaccineDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
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
        _vaccineDate = picked;
      });
    }
  }

  void _saveVaccination(VaccinationProvider provider) async {
    if (_formKey.currentState!.validate()) {
      try {
        await provider.addVaccinationEntry(
          cattleId: _cattleIdController.text.trim(),
          cattleName: _cattleNameController.text.trim(),
          vaccineName: _vaccineNameController.text.trim(),
          vaccinationDate: _vaccineDate,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vaccination saved to database successfully!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save record: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vaccine Entry'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record Livestock Vaccine',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Log vaccine details below. The system will auto-calculate booster reminders.',
                      style: TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Fields
              const Text(
                'Cattle Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.lightText),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cattleNameController,
                decoration: const InputDecoration(
                  labelText: 'Cattle Name',
                  hintText: 'e.g. Lakshmi',
                  prefixIcon: Icon(Icons.pets, color: AppTheme.lightText, size: 20),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter cattle name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cattleIdController,
                decoration: const InputDecoration(
                  labelText: 'Cattle ID',
                  hintText: 'e.g. KP-204',
                  prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.lightText, size: 20),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter cattle ID' : null,
              ),
              const SizedBox(height: 24),

              const Text(
                'Vaccination Info',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.lightText),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _vaccineNameController,
                decoration: const InputDecoration(
                  labelText: 'Vaccine Name',
                  hintText: 'e.g. FMD Vaccine',
                  prefixIcon: Icon(Icons.vaccines_outlined, color: AppTheme.lightText, size: 20),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter vaccine name' : null,
              ),
              const SizedBox(height: 16),
              
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F3F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.primaryGreen, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vaccination Administered Date',
                              style: TextStyle(fontSize: 11, color: AppTheme.lightText),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _vaccineDate.toString().substring(0, 10),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit, color: AppTheme.lightText, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              Consumer<VaccinationProvider>(
                builder: (context, provider, child) {
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _saveVaccination(provider),
                      child: const Text('Save Vaccine Entry'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


