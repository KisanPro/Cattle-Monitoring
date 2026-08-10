import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import '../models/vaccination_model.dart';
import '../models/reminder_model.dart';
import '../services/vaccination_firestore_service.dart';
import '../services/mock_database_service.dart';

class VaccinationRepository {
  final String farmerId;
  late final VaccinationFirestoreService _firestoreService;
  late final MockDatabaseService _mockDatabaseService;
  bool _useFirestore = false;

  VaccinationRepository({required this.farmerId}) {
    _mockDatabaseService = MockDatabaseService();
    _firestoreService = VaccinationFirestoreService(farmerId: farmerId);
    _checkFirebaseInitialization();
  }

  void _checkFirebaseInitialization() {
    try {
      if (Firebase.apps.isNotEmpty) {
        _useFirestore = true;
        print("KisanPro Vaccination Repo: Using Firestore datasource.");
      } else {
        _useFirestore = false;
        print("KisanPro Vaccination Repo: Firebase not initialized. Using Mock Database fallback.");
      }
    } catch (e) {
      _useFirestore = false;
      print("KisanPro Vaccination Repo: Firebase initialization check failed. Error: $e. Using Mock Database fallback.");
    }
  }

  // Allow manual override for testing purposes
  set useFirestore(bool value) {
    _useFirestore = value;
  }

  bool get isUsingFirestore => _useFirestore;

  Future<void> addVaccination(VaccinationModel vaccination) async {
    if (_useFirestore) {
      try {
        await _firestoreService.addVaccination(vaccination);
      } catch (e) {
        print("Error saving to Firestore: $e. Falling back to Mock DB.");
        await _mockDatabaseService.addVaccination(vaccination);
      }
    } else {
      await _mockDatabaseService.addVaccination(vaccination);
    }
  }

  Stream<List<VaccinationModel>> getVaccinationsStream() {
    if (_useFirestore) {
      return _firestoreService.getVaccinationsStream().handleError((err) {
        print("Firestore Stream Error: $err. Falling back to Mock DB Stream.");
        return _mockDatabaseService.vaccinationsStream;
      });
    } else {
      return _mockDatabaseService.vaccinationsStream;
    }
  }

  Future<void> addReminder(ReminderModel reminder) async {
    if (_useFirestore) {
      try {
        await _firestoreService.addReminder(reminder);
      } catch (e) {
        print("Error saving reminder to Firestore: $e. Falling back to Mock DB.");
        await _mockDatabaseService.addReminder(reminder);
      }
    } else {
      await _mockDatabaseService.addReminder(reminder);
    }
  }

  Stream<List<ReminderModel>> getRemindersStream() {
    if (_useFirestore) {
      return _firestoreService.getRemindersStream().handleError((err) {
        print("Firestore Reminders Stream Error: $err. Falling back to Mock DB.");
        return _mockDatabaseService.remindersStream;
      });
    } else {
      return _mockDatabaseService.remindersStream;
    }
  }

  Future<void> updateReminderStatus(String reminderId, String status) async {
    if (_useFirestore && !reminderId.startsWith('mock_')) {
      try {
        await _firestoreService.updateReminderStatus(reminderId, status);
      } catch (e) {
        print("Error updating reminder in Firestore: $e. Updating in Mock DB.");
        await _mockDatabaseService.updateReminderStatus(reminderId, status);
      }
    } else {
      await _mockDatabaseService.updateReminderStatus(reminderId, status);
    }
  }
}
