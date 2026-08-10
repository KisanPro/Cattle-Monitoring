import 'package:cloud_firestore/cloud_firestore.dart';

class MilkRecordModel {
  final String? id;
  final String cattleId;
  final String cattleName;
  final String milkTime; // "Morning" or "Evening"
  final double quantity;
  final double fat; // Milk Fat percentage (e.g., 4.5%)
  final double snf; // Solids-Not-Fat percentage (e.g., 8.5%)
  final DateTime timestamp;

  MilkRecordModel({
    this.id,
    required this.cattleId,
    required this.cattleName,
    required this.milkTime,
    required this.quantity,
    required this.fat,
    required this.snf,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'cattleId': cattleId,
      'cattleName': cattleName,
      'milkTime': milkTime,
      'quantity': quantity,
      'fat': fat,
      'snf': snf,
      'timestamp': Timestamp.fromDate(timestamp),
      'date': timestamp.toIso8601String().substring(0, 10),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory MilkRecordModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parsedTime;
    final ts = map['timestamp'];
    if (ts is Timestamp) {
      parsedTime = ts.toDate();
    } else if (ts is String) {
      parsedTime = DateTime.parse(ts);
    } else {
      parsedTime = DateTime.now();
    }

    return MilkRecordModel(
      id: docId,
      cattleId: map['cattleId'] ?? '',
      cattleName: map['cattleName'] ?? '',
      milkTime: map['milkTime'] ?? 'Morning',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 4.2, // Default average fat
      snf: (map['snf'] as num?)?.toDouble() ?? 8.5, // Default average SNF
      timestamp: parsedTime,
    );
  }

  MilkRecordModel copyWith({
    String? id,
    String? cattleId,
    String? cattleName,
    String? milkTime,
    double? quantity,
    double? fat,
    double? snf,
    DateTime? timestamp,
  }) {
    return MilkRecordModel(
      id: id ?? this.id,
      cattleId: cattleId ?? this.cattleId,
      cattleName: cattleName ?? this.cattleName,
      milkTime: milkTime ?? this.milkTime,
      quantity: quantity ?? this.quantity,
      fat: fat ?? this.fat,
      snf: snf ?? this.snf,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
