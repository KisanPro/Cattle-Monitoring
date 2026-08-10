import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/vaccination_provider.dart';
import '../widgets/reminder_card.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({Key? key}) : super(key: key);

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final _reminderNameController = TextEditingController();
  final _reminderDescController = TextEditingController();
  DateTime _reminderDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reminderNameController.dispose();
    _reminderDescController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, StateSetter modalSetState) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reminderDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.warningColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      modalSetState(() {
        _reminderDate = picked;
      });
    }
  }

  void _showAddReminderSheet(BuildContext context, VaccinationProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Schedule Reminder',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _reminderNameController,
                        decoration: const InputDecoration(
                          labelText: 'Vaccine Name / Booster Title',
                          hintText: 'e.g. FMD Vaccine Boost',
                        ),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Please enter vaccine name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reminderDescController,
                        decoration: const InputDecoration(
                          labelText: 'Booster Description',
                          hintText: 'e.g. Follow-up dose for cattle Lakshmi',
                        ),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Please enter description' : null,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _selectDate(context, modalSetState),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F3F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Alert Notification Date',
                                    style: TextStyle(fontSize: 11, color: AppTheme.lightText),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _reminderDate.toString().substring(0, 10),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.darkText,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(Icons.calendar_today, color: AppTheme.warningColor, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              await provider.addCustomReminder(
                                vaccineName: _reminderNameController.text.trim(),
                                reminderDate: _reminderDate,
                                description: _reminderDescController.text.trim(),
                              );
                              _reminderNameController.clear();
                              _reminderDescController.clear();
                              _reminderDate = DateTime.now().add(const Duration(days: 7));
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Booster reminder scheduled successfully!'),
                                  backgroundColor: AppTheme.primaryGreen,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningColor,
                          ),
                          child: const Text('Set Vaccination Reminder'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VaccinationProvider>(context);
    final pendingReminders = provider.reminders.where((r) => r.status.toLowerCase() == 'pending').toList();
    final completedReminders = provider.reminders.where((r) => r.status.toLowerCase() == 'completed').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaccination Reminders'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.lightText,
          indicatorColor: AppTheme.primaryGreen,
          tabs: [
            Tab(text: 'Pending (${pendingReminders.length})'),
            Tab(text: 'Completed (${completedReminders.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRemindersList(pendingReminders, provider, true),
          _buildRemindersList(completedReminders, provider, false),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReminderSheet(context, provider),
        label: const Text('Schedule Reminder'),
        icon: const Icon(Icons.alarm_add),
        backgroundColor: AppTheme.warningColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildRemindersList(List<dynamic> list, VaccinationProvider provider, bool isPending) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isPending ? Icons.alarm_on : Icons.alarm_off,
                size: 64,
                color: AppTheme.lightText.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                isPending ? 'All caught up! No pending reminders.' : 'No completed reminders yet.',
                style: const TextStyle(fontSize: 16, color: AppTheme.lightText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final rem = list[index];
        return ReminderCard(
          reminder: rem,
          onComplete: isPending
              ? () {
                  provider.completeReminder(rem.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${rem.vaccineName} marked as completed.'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                }
              : null,
        );
      },
    );
  }
}
