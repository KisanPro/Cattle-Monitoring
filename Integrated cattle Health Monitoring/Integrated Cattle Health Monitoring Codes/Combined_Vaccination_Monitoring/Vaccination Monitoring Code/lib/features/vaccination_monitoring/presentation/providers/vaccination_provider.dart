import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/vaccination_model.dart';
import '../../data/models/reminder_model.dart';
import '../../data/repositories/vaccination_repository.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/ai_prediction_service.dart';

class VaccinationProvider extends ChangeNotifier {
  final VaccinationRepository repository;
  final NotificationService _notificationService = NotificationService();

  List<VaccinationModel> _vaccinations = [];
  List<ReminderModel> _reminders = [];
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription<List<VaccinationModel>>? _vaccinationsSubscription;
  StreamSubscription<List<ReminderModel>>? _remindersSubscription;

  // Analytics variables
  int _totalVaccinationsCount = 0;
  int _completedRemindersCount = 0;
  int _pendingRemindersCount = 0;
  double _complianceRate = 100.0;
  double _reminderCompletionRate = 100.0;
  Map<String, int> _vaccineCounts = {};

  VaccinationProvider({required this.repository}) {
    _initProvider();
  }

  List<VaccinationModel> get vaccinations => _vaccinations;
  List<ReminderModel> get reminders => _reminders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Analytics Getters
  int get totalVaccinationsCount => _totalVaccinationsCount;
  int get completedRemindersCount => _completedRemindersCount;
  int get pendingRemindersCount => _pendingRemindersCount;
  double get complianceRate => _complianceRate;
  double get reminderCompletionRate => _reminderCompletionRate;
  Map<String, int> get vaccineCounts => _vaccineCounts;

  Future<void> _initProvider() async {
    _isLoading = true;
    notifyListeners();

    await _notificationService.initialize();

    // Setup Stream Listeners
    _vaccinationsSubscription = repository.getVaccinationsStream().listen(
      (data) {
        _vaccinations = data;
        _calculateAnalytics();
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    _remindersSubscription = repository.getRemindersStream().listen(
      (data) {
        _reminders = data;
        _calculateAnalytics();
        notifyListeners();
      },
      onError: (error) {
        print("Reminders Stream error in provider: $error");
      },
    );
  }

  void _calculateAnalytics() {
    _totalVaccinationsCount = _vaccinations.length;

    // Vaccine Type Counts
    final Map<String, int> counts = {};
    int completedCount = 0;
    int overdueCount = 0;

    for (var vac in _vaccinations) {
      final name = vac.vaccineName.trim();
      counts[name] = (counts[name] ?? 0) + 1;

      if (vac.status.toLowerCase() == 'completed') {
        completedCount++;
      } else if (vac.status.toLowerCase() == 'overdue') {
        overdueCount++;
      }
    }
    _vaccineCounts = counts;

    // Compliance Rate = completed / (completed + overdue)
    final totalAssessable = completedCount + overdueCount;
    _complianceRate = totalAssessable > 0 ? (completedCount / totalAssessable) * 100.0 : 100.0;

    // Reminder Counts
    _completedRemindersCount = _reminders.where((r) => r.status.toLowerCase() == 'completed').length;
    _pendingRemindersCount = _reminders.where((r) => r.status.toLowerCase() == 'pending').length;

    final totalReminders = _completedRemindersCount + _pendingRemindersCount;
    _reminderCompletionRate = totalReminders > 0 ? (_completedRemindersCount / totalReminders) * 100.0 : 100.0;
  }

  // Add a new vaccination entry
  Future<void> addVaccinationEntry({
    required String cattleId,
    required String cattleName,
    required String vaccineName,
    required DateTime vaccinationDate,
    double? weightKg,
    int? ageYears,
    String? breed,
    String? location,
  }) async {
    // 1. Calculate next reminder date based on vaccine type (veterinary standards)
    Duration boosterInterval = const Duration(days: 30); // Default FMD/short booster
    final nameLower = vaccineName.toLowerCase();
    if (nameLower.contains('anthrax') || nameLower.contains('brucellosis')) {
      boosterInterval = const Duration(days: 365); // 1 Year booster
    } else if (nameLower.contains('hs') || nameLower.contains('hemorrhagic')) {
      boosterInterval = const Duration(days: 180); // 6 Months booster
    }

    final DateTime nextReminderDate = vaccinationDate.add(boosterInterval);

    final vaccination = VaccinationModel(
      cattleId: cattleId,
      cattleName: cattleName,
      vaccineName: vaccineName,
      vaccinationDate: vaccinationDate,
      nextReminderDate: nextReminderDate,
      status: 'Completed',
      weightKg: weightKg,
      ageYears: ageYears,
      breed: breed,
      location: location,
    );

    // 2. Save Vaccination Record
    await repository.addVaccination(vaccination);

    // 3. Create Corresponding Reminder Document
    final reminder = ReminderModel(
      vaccineName: '$vaccineName Boost',
      reminderDate: nextReminderDate,
      description: 'Scheduled booster dose for $cattleName ($cattleId)',
      status: 'Pending',
    );

    await repository.addReminder(reminder);

    // 4. Schedule local notification
    final notificationId = cattleId.hashCode + vaccineName.hashCode;
    await _notificationService.scheduleNotification(
      id: notificationId,
      title: 'Upcoming Vaccination for $cattleName',
      body: 'Booster dose of $vaccineName is due on ${nextReminderDate.toString().substring(0, 10)}',
      scheduledDate: nextReminderDate.subtract(const Duration(days: 1)), // Alert 1 day before
    );
  }

  // Get dynamic AI suggestions for a single cattle
  List<DiseaseRisk> getAiPredictionsForCattle({
    required String name,
    required String cattleId,
    required int ageYears,
    required double weightKg,
    required String breed,
    required String location,
  }) {
    return AiPredictionService.getPredictions(
      name: name,
      cattleId: cattleId,
      ageYears: ageYears,
      weightKg: weightKg,
      breed: breed,
      location: location,
    );
  }

  // Compile active AI disease/vaccine alerts for all loaded herd records
  List<Map<String, dynamic>> getActiveAiAlerts() {
    final List<Map<String, dynamic>> alerts = [];
    final Map<String, VaccinationModel> latestRecords = {};

    for (var v in _vaccinations) {
      final key = v.cattleId;
      final existing = latestRecords[key];
      if (existing == null || v.vaccinationDate.isAfter(existing.vaccinationDate)) {
        latestRecords[key] = v;
      }
    }

    latestRecords.forEach((cattleId, v) {
      final risks = AiPredictionService.getPredictions(
        name: v.cattleName,
        cattleId: v.cattleId,
        ageYears: v.ageYears ?? 3,
        weightKg: v.weightKg ?? 400.0,
        breed: v.breed ?? 'Unknown',
        location: v.location ?? 'Karnataka',
      );
      for (var risk in risks) {
        alerts.add({
          'cattleId': v.cattleId,
          'cattleName': v.cattleName,
          'disease': risk.diseaseName,
          'riskLevel': risk.riskLevel,
          'reason': risk.triggerReason,
          'vaccine': risk.recommendedVaccine,
          'symptoms': risk.symptoms,
          'prevention': risk.preventionTips,
          'clinicalDetails': risk.clinicalDetails,
          'dateDetected': v.vaccinationDate,
        });
      }
    });

    return alerts;
  }

  // Add custom vaccination reminder
  Future<void> addCustomReminder({
    required String vaccineName,
    required DateTime reminderDate,
    required String description,
  }) async {
    final reminder = ReminderModel(
      vaccineName: vaccineName,
      reminderDate: reminderDate,
      description: description,
      status: 'Pending',
    );

    await repository.addReminder(reminder);

    final notificationId = vaccineName.hashCode + reminderDate.hashCode;
    await _notificationService.scheduleNotification(
      id: notificationId,
      title: 'Vaccination Alert: $vaccineName',
      body: description,
      scheduledDate: reminderDate,
    );
  }

  // Complete a reminder
  Future<void> completeReminder(String reminderId) async {
    await repository.updateReminderStatus(reminderId, 'Completed');
  }

  // Re-verify overdue records based on dates
  void checkOverdueRecords() {
    bool updated = false;
    final now = DateTime.now();
    for (int i = 0; i < _vaccinations.length; i++) {
      final vac = _vaccinations[i];
      if (vac.status.toLowerCase() == 'completed' && vac.nextReminderDate.isBefore(now)) {
        // Trigger alert for overdue
        _notificationService.scheduleNotification(
          id: vac.cattleId.hashCode + 999,
          title: 'Vaccination Overdue',
          body: 'Vaccination overdue for ${vac.cattleName} (ID: ${vac.cattleId})',
          scheduledDate: now.add(const Duration(seconds: 5)),
        );
        updated = true;
      }
    }
    if (updated) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _vaccinationsSubscription?.cancel();
    _remindersSubscription?.cancel();
    super.dispose();
  }
}
