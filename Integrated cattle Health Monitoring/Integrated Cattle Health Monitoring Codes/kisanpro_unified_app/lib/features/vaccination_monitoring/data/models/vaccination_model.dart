class VaccinationModel {
  final String? id;
  final String cattleId;
  final String cattleName;
  final String vaccineName;
  final DateTime vaccinationDate;
  final DateTime nextReminderDate;
  final String status;
  final bool isStarred;
  final double? weightKg;
  final int? ageYears;
  final String? breed;
  final String? location;

  VaccinationModel({
    this.id,
    required this.cattleId,
    required this.cattleName,
    required this.vaccineName,
    required this.vaccinationDate,
    required this.nextReminderDate,
    required this.status,
    this.isStarred = false,
    this.weightKg,
    this.ageYears,
    this.breed,
    this.location,
  });

  Map<String, dynamic> toMap() {
    return {
      'cattleId': cattleId,
      'cattleName': cattleName,
      'vaccineName': vaccineName,
      'vaccinationDate': vaccinationDate.toIso8601String(),
      'nextReminderDate': nextReminderDate.toIso8601String(),
      'status': status,
      'isStarred': isStarred,
      'weightKg': weightKg,
      'ageYears': ageYears,
      'breed': breed,
      'location': location,
    };
  }

  factory VaccinationModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic date) {
      if (date is DateTime) {
        return date;
      } else if (date is String) {
        return DateTime.tryParse(date) ?? DateTime.now();
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
      weightKg: map['weightKg'] != null ? (map['weightKg'] as num).toDouble() : null,
      ageYears: map['ageYears'] as int?,
      breed: map['breed'] as String?,
      location: map['location'] as String?,
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
    double? weightKg,
    int? ageYears,
    String? breed,
    String? location,
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
      weightKg: weightKg ?? this.weightKg,
      ageYears: ageYears ?? this.ageYears,
      breed: breed ?? this.breed,
      location: location ?? this.location,
    );
  }
}
