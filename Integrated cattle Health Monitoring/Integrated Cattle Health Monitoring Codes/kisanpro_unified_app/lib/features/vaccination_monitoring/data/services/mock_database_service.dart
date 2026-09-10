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
    _vaccinations.addAll([
      // 1. Geetha (KA-1989) - HF
      VaccinationModel(
        id: 'geetha_vac_1',
        cattleId: 'KA-1989',
        cattleName: 'Geetha',
        vaccineName: 'FMD Vaccine Booster',
        vaccinationDate: DateTime(2026, 8, 10),
        nextReminderDate: DateTime(2026, 9, 20),
        status: 'Pending',
        isStarred: true,
        weightKg: 438.0,
        ageYears: 4,
        breed: 'HF (Holstein Friesian)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),
      VaccinationModel(
        id: 'geetha_vac_2',
        cattleId: 'KA-1989',
        cattleName: 'Geetha',
        vaccineName: 'Anthrax Spore Vaccine',
        vaccinationDate: DateTime(2026, 2, 15),
        nextReminderDate: DateTime(2026, 8, 10),
        status: 'Completed',
        weightKg: 430.0,
        ageYears: 4,
        breed: 'HF (Holstein Friesian)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),
      VaccinationModel(
        id: 'geetha_vac_3',
        cattleId: 'KA-1989',
        cattleName: 'Geetha',
        vaccineName: 'HS (Hemorrhagic Septicemia)',
        vaccinationDate: DateTime(2025, 8, 20),
        nextReminderDate: DateTime(2026, 2, 15),
        status: 'Completed',
        weightKg: 415.0,
        ageYears: 3,
        breed: 'HF (Holstein Friesian)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),

      // 2. Lakshmi (KA-1021) - Gir
      VaccinationModel(
        id: 'lakshmi_vac_1',
        cattleId: 'KA-1021',
        cattleName: 'Lakshmi',
        vaccineName: 'FMD Vaccine Dose 2',
        vaccinationDate: DateTime(2026, 7, 18),
        nextReminderDate: DateTime(2027, 1, 18),
        status: 'Completed',
        isStarred: true,
        weightKg: 380.0,
        ageYears: 5,
        breed: 'Gir (Indigenous Dairy)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),
      VaccinationModel(
        id: 'lakshmi_vac_2',
        cattleId: 'KA-1021',
        cattleName: 'Lakshmi',
        vaccineName: 'Brucellosis S19',
        vaccinationDate: DateTime(2026, 1, 10),
        nextReminderDate: DateTime(2026, 7, 18),
        status: 'Completed',
        weightKg: 375.0,
        ageYears: 5,
        breed: 'Gir (Indigenous Dairy)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),
      VaccinationModel(
        id: 'lakshmi_vac_3',
        cattleId: 'KA-1021',
        cattleName: 'Lakshmi',
        vaccineName: 'Black Quarter (BQ)',
        vaccinationDate: DateTime(2025, 7, 5),
        nextReminderDate: DateTime(2026, 1, 10),
        status: 'Completed',
        weightKg: 360.0,
        ageYears: 4,
        breed: 'Gir (Indigenous Dairy)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),

      // 3. Ganga (KA-3045) - Hallikar
      VaccinationModel(
        id: 'ganga_vac_1',
        cattleId: 'KA-3045',
        cattleName: 'Ganga',
        vaccineName: 'Theileriosis Vaccine',
        vaccinationDate: DateTime(2026, 8, 28),
        nextReminderDate: DateTime(2026, 9, 28),
        status: 'Completed',
        isStarred: true,
        weightKg: 360.0,
        ageYears: 3,
        breed: 'Hallikar (Indigenous Draft)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),
      VaccinationModel(
        id: 'ganga_vac_2',
        cattleId: 'KA-3045',
        cattleName: 'Ganga',
        vaccineName: 'FMD Trivalent Booster',
        vaccinationDate: DateTime(2026, 3, 12),
        nextReminderDate: DateTime(2026, 8, 28),
        status: 'Completed',
        weightKg: 350.0,
        ageYears: 3,
        breed: 'Hallikar (Indigenous Draft)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),

      // 4. Gauri (KA-5512) - Jersey
      VaccinationModel(
        id: 'gauri_vac_1',
        cattleId: 'KA-5512',
        cattleName: 'Gauri',
        vaccineName: 'Anthrax + HS Combination',
        vaccinationDate: DateTime(2026, 7, 30),
        nextReminderDate: DateTime(2027, 1, 30),
        status: 'Completed',
        isStarred: true,
        weightKg: 410.0,
        ageYears: 4,
        breed: 'Jersey (High-Yield Dairy)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),
      VaccinationModel(
        id: 'gauri_vac_2',
        cattleId: 'KA-5512',
        cattleName: 'Gauri',
        vaccineName: 'FMD Regular Vaccine',
        vaccinationDate: DateTime(2026, 1, 22),
        nextReminderDate: DateTime(2026, 7, 30),
        status: 'Completed',
        weightKg: 400.0,
        ageYears: 4,
        breed: 'Jersey (High-Yield Dairy)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),

      // 5. Kamadhenu (KA-7789) - Sahiwal
      VaccinationModel(
        id: 'kamadhenu_vac_1',
        cattleId: 'KA-7789',
        cattleName: 'Kamadhenu',
        vaccineName: 'Bovine Viral Diarrhea (BVD)',
        vaccinationDate: DateTime(2026, 8, 5),
        nextReminderDate: DateTime(2027, 2, 5),
        status: 'Completed',
        isStarred: true,
        weightKg: 395.0,
        ageYears: 6,
        breed: 'Sahiwal (Zebu Dairy)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),
      VaccinationModel(
        id: 'kamadhenu_vac_2',
        cattleId: 'KA-7789',
        cattleName: 'Kamadhenu',
        vaccineName: 'FMD + BQ Booster',
        vaccinationDate: DateTime(2026, 2, 10),
        nextReminderDate: DateTime(2026, 8, 5),
        status: 'Completed',
        weightKg: 388.0,
        ageYears: 6,
        breed: 'Sahiwal (Zebu Dairy)',
        location: 'Mandya / Bangalore Rural, Karnataka',
      ),

      // 6. Surabhi (AP-5040) - Punganur
      VaccinationModel(
        id: 'surabhi_vac_1',
        cattleId: 'AP-5040',
        cattleName: 'Surabhi',
        vaccineName: 'NADCP Trivalent FMD Booster',
        vaccinationDate: DateTime(2026, 8, 15),
        nextReminderDate: DateTime(2026, 9, 25),
        status: 'Pending',
        isStarred: true,
        weightKg: 215.0,
        ageYears: 3,
        breed: 'Punganur (Indigenous Tirupati Dwarf)',
        location: 'Tirupati / Chittoor, Andhra Pradesh',
      ),
      VaccinationModel(
        id: 'surabhi_vac_2',
        cattleId: 'AP-5040',
        cattleName: 'Surabhi',
        vaccineName: 'Anthrax Spore Vaccine (Sterne Strain)',
        vaccinationDate: DateTime(2026, 3, 10),
        nextReminderDate: DateTime(2026, 8, 15),
        status: 'Completed',
        weightKg: 210.0,
        ageYears: 3,
        breed: 'Punganur (Indigenous Tirupati Dwarf)',
        location: 'Tirupati / Chittoor, Andhra Pradesh',
      ),
    ]);

    // Pre-populate alerts & booster schedules matching the registered cattle
    _reminders.addAll([
      ReminderModel(
        id: 'rem_geetha_1',
        vaccineName: 'FMD Vaccine Booster',
        reminderDate: DateTime(2026, 9, 20),
        description: 'Scheduled semi-annual booster for Geetha (KA-1989)',
        notificationSent: false,
        status: 'Pending',
      ),
      ReminderModel(
        id: 'rem_surabhi_1',
        vaccineName: 'NADCP Trivalent FMD Booster',
        reminderDate: DateTime(2026, 9, 25),
        description: 'Scheduled booster for Surabhi (AP-5040)',
        notificationSent: false,
        status: 'Pending',
      ),
      ReminderModel(
        id: 'rem_ganga_1',
        vaccineName: 'Theileriosis Booster Dose',
        reminderDate: DateTime(2026, 9, 28),
        description: 'Follow-up dose for Ganga (KA-3045)',
        notificationSent: false,
        status: 'Pending',
      ),
      ReminderModel(
        id: 'rem_lakshmi_1',
        vaccineName: 'FMD Trivalent Booster',
        reminderDate: DateTime(2027, 1, 18),
        description: 'Annual booster for Lakshmi (KA-1021)',
        notificationSent: false,
        status: 'Pending',
      ),
      ReminderModel(
        id: 'rem_gauri_1',
        vaccineName: 'Anthrax + HS Combo Booster',
        reminderDate: DateTime(2027, 1, 30),
        description: 'Scheduled booster for Gauri (KA-5512)',
        notificationSent: false,
        status: 'Pending',
      ),
      ReminderModel(
        id: 'rem_kamadhenu_1',
        vaccineName: 'BVD Annual Booster',
        reminderDate: DateTime(2027, 2, 5),
        description: 'Regular booster for Kamadhenu (KA-7789)',
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
