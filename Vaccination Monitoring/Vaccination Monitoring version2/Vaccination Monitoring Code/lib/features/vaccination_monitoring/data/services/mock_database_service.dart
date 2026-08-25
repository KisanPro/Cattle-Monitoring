import 'dart:async';
import '../models/vaccination_model.dart';
import '../models/reminder_model.dart';

class MockDatabaseService {
  static final MockDatabaseService _instance = MockDatabaseService._internal();
  factory MockDatabaseService() => _instance;
  MockDatabaseService._internal() {
    _initMockData();
  }

  final List<VaccinationModel> _vaccinations = [];
  final List<ReminderModel> _reminders = [];

  final _vaccinationsController = StreamController<List<VaccinationModel>>.broadcast();
  final _remindersController = StreamController<List<ReminderModel>>.broadcast();

  Stream<List<VaccinationModel>> get vaccinationsStream async* {
    yield List.unmodifiable(_vaccinations);
    yield* _vaccinationsController.stream;
  }

  Stream<List<ReminderModel>> get remindersStream async* {
    yield List.unmodifiable(_reminders);
    yield* _remindersController.stream;
  }

  void _initMockData() {
    // 8 historical records for Lakshmi (KP-204) to match Image 2
    _vaccinations.addAll([
      VaccinationModel(
        id: 'lakshmi_vac_1',
        cattleId: 'KP-204',
        cattleName: 'Lakshmi',
        vaccineName: 'FMD Vaccine',
        vaccinationDate: DateTime(2026, 5, 14), // Matches latest dose in Image 2
        nextReminderDate: DateTime(2026, 6, 20), // Next booster
        status: 'Completed',
        isStarred: true,
        weightKg: 410.0,
        ageYears: 5,
        breed: 'Gir',
        location: 'Gujarat',
      ),
      VaccinationModel(
        id: 'lakshmi_vac_2',
        cattleId: 'KP-204',
        cattleName: 'Lakshmi',
        vaccineName: 'Anthrax Vaccine',
        vaccinationDate: DateTime(2025, 12, 12),
        nextReminderDate: DateTime(2026, 5, 14),
        status: 'Completed',
        weightKg: 405.0,
        ageYears: 4,
        breed: 'Gir',
        location: 'Gujarat',
      ),
      VaccinationModel(
        id: 'lakshmi_vac_3',
        cattleId: 'KP-204',
        cattleName: 'Lakshmi',
        vaccineName: 'HS Vaccine',
        vaccinationDate: DateTime(2025, 6, 15),
        nextReminderDate: DateTime(2025, 12, 12),
        status: 'Completed',
        weightKg: 395.0,
        ageYears: 4,
        breed: 'Gir',
        location: 'Gujarat',
      ),
      VaccinationModel(
        id: 'lakshmi_vac_4',
        cattleId: 'KP-204',
        cattleName: 'Lakshmi',
        vaccineName: 'Brucellosis Vaccine',
        vaccinationDate: DateTime(2025, 1, 10),
        nextReminderDate: DateTime(2025, 6, 15),
        status: 'Completed',
        weightKg: 390.0,
        ageYears: 4,
        breed: 'Gir',
        location: 'Gujarat',
      ),
      VaccinationModel(
        id: 'lakshmi_vac_5',
        cattleId: 'KP-204',
        cattleName: 'Lakshmi',
        vaccineName: 'FMD Vaccine',
        vaccinationDate: DateTime(2024, 6, 12), // The card shown in Image 1
        nextReminderDate: DateTime(2025, 1, 10),
        status: 'Completed',
        weightKg: 375.0,
        ageYears: 3,
        breed: 'Gir',
        location: 'Gujarat',
      ),
      VaccinationModel(
        id: 'lakshmi_vac_6',
        cattleId: 'KP-204',
        cattleName: 'Lakshmi',
        vaccineName: 'Anthrax Vaccine',
        vaccinationDate: DateTime(2023, 12, 12),
        nextReminderDate: DateTime(2024, 6, 12),
        status: 'Completed',
        weightKg: 360.0,
        ageYears: 2,
        breed: 'Gir',
        location: 'Gujarat',
      ),
      VaccinationModel(
        id: 'lakshmi_vac_7',
        cattleId: 'KP-204',
        cattleName: 'Lakshmi',
        vaccineName: 'HS Vaccine',
        vaccinationDate: DateTime(2023, 6, 15),
        nextReminderDate: DateTime(2023, 12, 12),
        status: 'Completed',
        weightKg: 340.0,
        ageYears: 2,
        breed: 'Gir',
        location: 'Gujarat',
      ),
      VaccinationModel(
        id: 'lakshmi_vac_8',
        cattleId: 'KP-204',
        cattleName: 'Lakshmi',
        vaccineName: 'Brucellosis Vaccine',
        vaccinationDate: DateTime(2023, 1, 10),
        nextReminderDate: DateTime(2023, 6, 15),
        status: 'Completed',
        weightKg: 320.0,
        ageYears: 2,
        breed: 'Gir',
        location: 'Gujarat',
      ),

      // Other cattle to populate the grid
      VaccinationModel(
        id: 'nandi_vac_1',
        cattleId: 'KP-188',
        cattleName: 'Nandi',
        vaccineName: 'Brucellosis',
        vaccinationDate: DateTime(2024, 5, 15),
        nextReminderDate: DateTime(2025, 5, 15),
        status: 'Completed',
        weightKg: 450.0,
        ageYears: 6,
        breed: 'Ongole',
        location: 'Andhra Pradesh',
      ),
      VaccinationModel(
        id: 'surabhi_vac_1',
        cattleId: 'KP-312',
        cattleName: 'Surabhi',
        vaccineName: 'FMD Vaccine',
        vaccinationDate: DateTime(2024, 5, 10),
        nextReminderDate: DateTime(2025, 5, 10),
        status: 'Completed',
        weightKg: 390.0,
        ageYears: 3,
        breed: 'Sahiwal',
        location: 'Punjab',
      ),
      VaccinationModel(
        id: 'gauri_vac_1',
        cattleId: 'KP-095',
        cattleName: 'Gauri',
        vaccineName: 'Anthrax',
        vaccinationDate: DateTime(2024, 5, 2),
        nextReminderDate: DateTime(2025, 5, 2),
        status: 'Completed',
        weightKg: 420.0,
        ageYears: 5,
        breed: 'Tharparkar',
        location: 'Rajasthan',
      ),
      VaccinationModel(
        id: 'geetha_vac_1',
        cattleId: 'KA-1989',
        cattleName: 'Geetha',
        vaccineName: 'FMD Vaccine',
        vaccinationDate: DateTime(2026, 5, 8),
        nextReminderDate: DateTime(2026, 6, 8),
        status: 'Pending',
        weightKg: 380.0,
        ageYears: 4,
        breed: 'Hallikar',
        location: 'Karnataka',
      ),
    ]);

    // Pre-populate alerts
    _reminders.addAll([
      ReminderModel(
        id: 'mock_rem_1',
        vaccineName: 'FMD Vaccine Boost',
        reminderDate: DateTime(2026, 6, 20),
        description: 'Next booster dose for Lakshmi (KP-204)',
        notificationSent: false,
        status: 'Pending',
      ),
      ReminderModel(
        id: 'mock_rem_2',
        vaccineName: 'Brucellosis Boost',
        reminderDate: DateTime(2025, 5, 15),
        description: 'Scheduled booster for Nandi (KP-188)',
        notificationSent: false,
        status: 'Pending',
      ),
      ReminderModel(
        id: 'mock_rem_3',
        vaccineName: 'FMD Vaccine Boost',
        reminderDate: DateTime(2025, 5, 10),
        description: 'Scheduled booster for Surabhi (KP-312)',
        notificationSent: false,
        status: 'Pending',
      ),
      ReminderModel(
        id: 'mock_rem_4',
        vaccineName: 'Anthrax Boost',
        reminderDate: DateTime(2025, 5, 2),
        description: 'Scheduled booster for Gauri (KP-095)',
        notificationSent: false,
        status: 'Pending',
      ),
      ReminderModel(
        id: 'geetha_rem_1',
        vaccineName: 'FMD Vaccine Boost',
        reminderDate: DateTime(2026, 6, 8),
        description: 'Scheduled booster for Geetha (KA-1989)',
        notificationSent: false,
        status: 'Pending',
      ),
    ]);

    _notifyAll();
  }

  void _notifyAll() {
    _vaccinationsController.add(List.unmodifiable(_vaccinations));
    _remindersController.add(List.unmodifiable(_reminders));
  }

  Future<void> addVaccination(VaccinationModel vaccination) async {
    final record = vaccination.id == null
        ? vaccination.copyWith(id: 'mock_vac_${DateTime.now().millisecondsSinceEpoch}')
        : vaccination;
    _vaccinations.add(record);
    _notifyAll();
  }

  Future<void> addReminder(ReminderModel reminder) async {
    final record = reminder.id == null
        ? reminder.copyWith(id: 'mock_rem_${DateTime.now().millisecondsSinceEpoch}')
        : reminder;
    _reminders.add(record);
    _notifyAll();
  }

  Future<void> updateReminderStatus(String reminderId, String status) async {
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index != -1) {
      _reminders[index] = _reminders[index].copyWith(status: status);
      _notifyAll();
    }
  }

  List<VaccinationModel> get currentVaccinations => List.unmodifiable(_vaccinations);
  List<ReminderModel> get currentReminders => List.unmodifiable(_reminders);

  void dispose() {
    _vaccinationsController.close();
    _remindersController.close();
  }
}
