import 'package:cloud_firestore/cloud_firestore.dart';

class VaccinationModel {
  final String? id;
  final String cattleId;
  final String cattleName;
  final String vaccineName;
  final DateTime vaccinationDate;
  final DateTime nextReminderDate;
  final String status;
  final bool isStarred;

  VaccinationModel({
    this.id,
    required this.cattleId,
    required this.cattleName,
    required this.vaccineName,
    required this.vaccinationDate,
    required this.nextReminderDate,
    required this.status,
    this.isStarred = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'cattleId': cattleId,
      'cattleName': cattleName,
      'vaccineName': vaccineName,
      'vaccinationDate': Timestamp.fromDate(vaccinationDate),
      'nextReminderDate': Timestamp.fromDate(nextReminderDate),
      'status': status,
      'isStarred': isStarred,
    };
  }

  factory VaccinationModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) {
        return date.toDate();
      } else if (date is String) {
        return DateTime.parse(date);
      } else {
        return DateTime.now();
      }
    }

    return VaccinationModel(
      id: documentId,
      cattleId: map['cattleId'] ?? '',
      cattleName: map['cattleName'] ?? '',
      vaccineName: map['vaccineName'] ?? '',
      vaccinationDate: parseDate(map['vaccinationDate']),
      nextReminderDate: parseDate(map['nextReminderDate']),
      status: map['status'] ?? 'Completed',
      isStarred: map['isStarred'] ?? false,
    );
  }

  VaccinationModel copyWith({
    String? id,
    String? cattleId,
    String? cattleName,
    String? vaccineName,
    DateTime? vaccinationDate,
    DateTime? nextReminderDate,
    String? status,
    bool? isStarred,
  }) {
    return VaccinationModel(
      id: id ?? this.id,
      cattleId: cattleId ?? this.cattleId,
      cattleName: cattleName ?? this.cattleName,
      vaccineName: vaccineName ?? this.vaccineName,
      vaccinationDate: vaccinationDate ?? this.vaccinationDate,
      nextReminderDate: nextReminderDate ?? this.nextReminderDate,
      status: status ?? this.status,
      isStarred: isStarred ?? this.isStarred,
    );
  }
}
