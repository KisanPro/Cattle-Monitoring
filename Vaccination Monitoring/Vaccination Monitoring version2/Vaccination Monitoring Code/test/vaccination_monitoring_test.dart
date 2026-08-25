import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vaccination_monitoring/features/vaccination_monitoring/data/models/vaccination_model.dart';
import 'package:vaccination_monitoring/features/vaccination_monitoring/data/models/reminder_model.dart';
import 'package:vaccination_monitoring/features/vaccination_monitoring/data/repositories/vaccination_repository.dart';
import 'package:vaccination_monitoring/features/vaccination_monitoring/presentation/providers/vaccination_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KisanPro Models serialization', () {
    test('VaccinationModel serialization and deserialization', () {
      final now = DateTime(2026, 6, 5);
      final reminder = now.add(const Duration(days: 30));

      final vac = VaccinationModel(
        id: 'test_vac_1',
        cattleId: 'KP-204',
        cattleName: 'Lakshmi',
        vaccineName: 'FMD Vaccine',
        vaccinationDate: now,
        nextReminderDate: reminder,
        status: 'Completed',
      );

      final map = vac.toMap();

      expect(map['cattleId'], 'KP-204');
      expect(map['cattleName'], 'Lakshmi');
      expect(map['vaccineName'], 'FMD Vaccine');
      expect(map['status'], 'Completed');
      expect(map['vaccinationDate'], isA<Timestamp>());
      expect(map['nextReminderDate'], isA<Timestamp>());

      // Deserialization check
      final parsed = VaccinationModel.fromMap(map, 'test_vac_1');
      expect(parsed.id, 'test_vac_1');
      expect(parsed.cattleId, 'KP-204');
      expect(parsed.cattleName, 'Lakshmi');
      expect(parsed.vaccineName, 'FMD Vaccine');
      expect(parsed.status, 'Completed');
      expect(parsed.vaccinationDate.year, 2026);
      expect(parsed.nextReminderDate.day, 5); // 5th July
    });

    test('ReminderModel serialization and deserialization', () {
      final now = DateTime(2026, 6, 12);
      final reminder = ReminderModel(
        id: 'test_rem_1',
        vaccineName: 'FMD Booster',
        reminderDate: now,
        description: 'Give booster to Lakshmi',
        notificationSent: false,
        status: 'Pending',
      );

      final map = reminder.toMap();

      expect(map['vaccineName'], 'FMD Booster');
      expect(map['description'], 'Give booster to Lakshmi');
      expect(map['notificationSent'], false);
      expect(map['status'], 'Pending');
      expect(map['reminderDate'], isA<Timestamp>());

      final parsed = ReminderModel.fromMap(map, 'test_rem_1');
      expect(parsed.id, 'test_rem_1');
      expect(parsed.vaccineName, 'FMD Booster');
      expect(parsed.description, 'Give booster to Lakshmi');
      expect(parsed.notificationSent, false);
      expect(parsed.status, 'Pending');
      expect(parsed.reminderDate.month, 6);
    });
  });

  group('KisanPro Repository Integration & Calculations', () {
    test('Provider registers streams and calculates stats', () async {
      // Initialize repository pointing to local mock streams
      final repo = VaccinationRepository(farmerId: 'test_farmer');
      repo.useFirestore = false; // Force Mock Database mode

      final provider = VaccinationProvider(repository: repo);

      // Verify that provider starts loading or retrieves mock data
      expect(provider.isLoading, isTrue);

      // Wait briefly for stream dispatch
      await Future.delayed(const Duration(milliseconds: 200));

      expect(provider.isLoading, isFalse);
      expect(provider.vaccinations.length, greaterThan(0));
      expect(provider.reminders.length, greaterThan(0));

      // Check stats: Total mock records loaded
      expect(provider.totalVaccinationsCount, 12); // 12 mock logs initial
      expect(provider.pendingRemindersCount, 5);   // 5 mock reminders initial

      // Verify vaccine frequency counts mapping
      final counts = provider.vaccineCounts;
      expect(counts.containsKey('FMD Vaccine'), isTrue);
      expect(counts.containsKey('Brucellosis Vaccine'), isTrue);
      expect(counts['FMD Vaccine'], 4); // FMD appears 4 times

      // Verify compliance rate: 11 completed out of 11 (0 overdue)
      expect(provider.complianceRate, 100.0);
    });

    test('Provider adds a new record and updates next reminder', () async {
      final repo = VaccinationRepository(farmerId: 'test_farmer');
      repo.useFirestore = false; // Mock Database mode
      final provider = VaccinationProvider(repository: repo);

      await Future.delayed(const Duration(milliseconds: 200));

      final int initialCount = provider.totalVaccinationsCount;
      final int initialReminders = provider.reminders.length;

      // Add record via provider
      await provider.addVaccinationEntry(
        cattleId: 'KP-999',
        cattleName: 'Surabhi',
        vaccineName: 'Anthrax Vaccine',
        vaccinationDate: DateTime(2026, 6, 1),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // Verify lists grew
      expect(provider.totalVaccinationsCount, initialCount + 1);
      expect(provider.reminders.length, initialReminders + 1);

      // Verify latest log details
      final latest = provider.vaccinations.firstWhere((v) => v.cattleId == 'KP-999');
      expect(latest.cattleName, 'Surabhi');
      expect(latest.vaccineName, 'Anthrax Vaccine');
      expect(latest.nextReminderDate, DateTime(2026, 6, 1).add(const Duration(days: 365)));

      // Verify compliance rates recalculated
      expect(provider.complianceRate, 100.0);
    });
  });
}
