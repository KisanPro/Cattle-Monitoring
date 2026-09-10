class CattleProfile {
  final String cattleId;
  final String name;
  final String breed;
  final int ageYears;
  final String gender;
  final String tagNumber;
  final double currentWeightKg;
  final double dailyMilkLiters;
  final String vaccineStatus;
  final String lactationStage;
  final String colorMarkings;
  final String riskLevel;
  final double healthScore;
  final DateTime registeredDate;

  CattleProfile({
    required this.cattleId,
    required this.name,
    required this.breed,
    required this.ageYears,
    this.gender = 'Female',
    required this.tagNumber,
    required this.currentWeightKg,
    required this.dailyMilkLiters,
    required this.vaccineStatus,
    this.lactationStage = 'Mid-Lactation',
    this.colorMarkings = 'Black & White',
    this.riskLevel = 'NORMAL',
    this.healthScore = 90.0,
    DateTime? registeredDate,
  }) : registeredDate = registeredDate ?? DateTime.now();

  CattleProfile copyWith({
    String? cattleId,
    String? name,
    String? breed,
    int? ageYears,
    String? gender,
    String? tagNumber,
    double? currentWeightKg,
    double? dailyMilkLiters,
    String? vaccineStatus,
    String? lactationStage,
    String? colorMarkings,
    String? riskLevel,
    double? healthScore,
    DateTime? registeredDate,
  }) {
    return CattleProfile(
      cattleId: cattleId ?? this.cattleId,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      ageYears: ageYears ?? this.ageYears,
      gender: gender ?? this.gender,
      tagNumber: tagNumber ?? this.tagNumber,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      dailyMilkLiters: dailyMilkLiters ?? this.dailyMilkLiters,
      vaccineStatus: vaccineStatus ?? this.vaccineStatus,
      lactationStage: lactationStage ?? this.lactationStage,
      colorMarkings: colorMarkings ?? this.colorMarkings,
      riskLevel: riskLevel ?? this.riskLevel,
      healthScore: healthScore ?? this.healthScore,
      registeredDate: registeredDate ?? this.registeredDate,
    );
  }
}
