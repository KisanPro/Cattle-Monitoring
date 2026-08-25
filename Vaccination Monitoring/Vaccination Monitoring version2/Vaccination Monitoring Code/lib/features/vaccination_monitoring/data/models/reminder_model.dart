import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String? id;
  final String vaccineName;
  final DateTime reminderDate;
  final String description;
  final bool notificationSent;
  final String status;

  ReminderModel({
    this.id,
    required this.vaccineName,
    required this.reminderDate,
    required this.description,
    this.notificationSent = false,
    this.status = 'Pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'vaccineName': vaccineName,
      'reminderDate': Timestamp.fromDate(reminderDate),
      'description': description,
      'notificationSent': notificationSent,
      'status': status,
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) {
        return date.toDate();
      } else if (date is String) {
        return DateTime.parse(date);
      } else {
        return DateTime.now();
      }
    }

    return ReminderModel(
      id: documentId,
      vaccineName: map['vaccineName'] ?? '',
      reminderDate: parseDate(map['reminderDate']),
      description: map['description'] ?? '',
      notificationSent: map['notificationSent'] ?? false,
      status: map['status'] ?? 'Pending',
    );
  }

  ReminderModel copyWith({
    String? id,
    String? vaccineName,
    DateTime? reminderDate,
    String? description,
    bool? notificationSent,
    String? status,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      vaccineName: vaccineName ?? this.vaccineName,
      reminderDate: reminderDate ?? this.reminderDate,
      description: description ?? this.description,
      notificationSent: notificationSent ?? this.notificationSent,
      status: status ?? this.status,
    );
  }
}
