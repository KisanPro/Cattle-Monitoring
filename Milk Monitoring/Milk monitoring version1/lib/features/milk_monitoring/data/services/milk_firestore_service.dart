import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/milk_repository.dart';
import '../models/milk_record_model.dart';
import '../models/milk_analytics_model.dart';

class MilkFirestoreService implements MilkRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String farmerId;

  MilkFirestoreService({required this.farmerId});

  @override
  Future<void> addMilkRecord(MilkRecordModel record) async {
    await _firestore
        .collection('farmers')
        .doc(farmerId)
        .collection('milk_records')
        .add(record.toMap());
  }

  @override
  Stream<List<MilkRecordModel>> getMilkRecords() {
    return _firestore
        .collection('farmers')
        .doc(farmerId)
        .collection('milk_records')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return MilkRecordModel.fromMap(doc.data(), docId: doc.id);
            }).toList());
  }

  @override
  Future<MilkAnalyticsModel> getMilkAnalytics() async {
    final doc = await _firestore
        .collection('farmers')
        .doc(farmerId)
        .collection('milk_analytics')
        .doc('summary')
        .get();
    
    if (doc.exists && doc.data() != null) {
      return MilkAnalyticsModel.fromMap(doc.data()!);
    }
    return MilkAnalyticsModel.empty();
  }

  @override
  Future<void> updateMilkAnalytics(MilkAnalyticsModel analytics) async {
    await _firestore
        .collection('farmers')
        .doc(farmerId)
        .collection('milk_analytics')
        .doc('summary')
        .set(analytics.toMap());
  }
}
