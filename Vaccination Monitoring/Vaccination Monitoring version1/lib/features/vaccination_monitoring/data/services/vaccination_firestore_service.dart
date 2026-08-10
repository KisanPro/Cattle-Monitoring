import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vaccination_model.dart';
import '../models/reminder_model.dart';

class VaccinationFirestoreService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final String farmerId;

  VaccinationFirestoreService({required this.farmerId});

  // Reference paths
  CollectionReference get _vaccinationRecordsRef =>
      _firestore.collection('farmers').doc(farmerId).collection('vaccination_records');

  CollectionReference get _vaccinationRemindersRef =>
      _firestore.collection('farmers').doc(farmerId).collection('vaccination_reminders');

  // Add vaccination record
  Future<void> addVaccination(VaccinationModel vaccination) async {
    await _vaccinationRecordsRef.add(vaccination.toMap());
  }

  // Get real-time vaccination records stream
  Stream<List<VaccinationModel>> getVaccinationsStream() {
    return _vaccinationRecordsRef
        .orderBy('vaccinationDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return VaccinationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Add vaccination reminder
  Future<void> addReminder(ReminderModel reminder) async {
    await _vaccinationRemindersRef.add(reminder.toMap());
  }

  // Get real-time reminders stream
  Stream<List<ReminderModel>> getRemindersStream() {
    return _vaccinationRemindersRef
        .orderBy('reminderDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ReminderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Update reminder status
  Future<void> updateReminderStatus(String reminderId, String status) async {
    await _vaccinationRemindersRef.doc(reminderId).update({'status': status});
  }
}
