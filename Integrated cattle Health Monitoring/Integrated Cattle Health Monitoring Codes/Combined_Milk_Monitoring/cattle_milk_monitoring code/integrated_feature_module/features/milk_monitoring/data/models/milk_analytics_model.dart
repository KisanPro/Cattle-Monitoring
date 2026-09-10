class MilkAnalyticsModel {
  final double dailyTotal;
  final double morningMilk;
  final double eveningMilk;
  final String bestDay;
  final double avgDaily;
  final double weeklyTotal;
  final double monthlyTotal;

  MilkAnalyticsModel({
    required this.dailyTotal,
    required this.morningMilk,
    required this.eveningMilk,
    required this.bestDay,
    required this.avgDaily,
    required this.weeklyTotal,
    required this.monthlyTotal,
  });

  factory MilkAnalyticsModel.empty() {
    return MilkAnalyticsModel(
      dailyTotal: 0.0,
      morningMilk: 0.0,
      eveningMilk: 0.0,
      bestDay: 'N/A',
      avgDaily: 0.0,
      weeklyTotal: 0.0,
      monthlyTotal: 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailyTotal': dailyTotal,
      'morningMilk': morningMilk,
      'eveningMilk': eveningMilk,
      'bestDay': bestDay,
      'avgDaily': avgDaily,
      'weeklyTotal': weeklyTotal,
      'monthlyTotal': monthlyTotal,
    };
  }

  factory MilkAnalyticsModel.fromMap(Map<String, dynamic> map) {
    return MilkAnalyticsModel(
      dailyTotal: (map['dailyTotal'] as num?)?.toDouble() ?? 0.0,
      morningMilk: (map['morningMilk'] as num?)?.toDouble() ?? 0.0,
      eveningMilk: (map['eveningMilk'] as num?)?.toDouble() ?? 0.0,
      bestDay: map['bestDay'] ?? 'N/A',
      avgDaily: (map['avgDaily'] as num?)?.toDouble() ?? 0.0,
      weeklyTotal: (map['weeklyTotal'] as num?)?.toDouble() ?? 0.0,
      monthlyTotal: (map['monthlyTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
