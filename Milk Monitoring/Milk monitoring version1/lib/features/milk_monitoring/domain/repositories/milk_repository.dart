import '../../data/models/milk_record_model.dart';
import '../../data/models/milk_analytics_model.dart';

abstract class MilkRepository {
  Future<void> addMilkRecord(MilkRecordModel record);
  Stream<List<MilkRecordModel>> getMilkRecords();
  Future<MilkAnalyticsModel> getMilkAnalytics();
  Future<void> updateMilkAnalytics(MilkAnalyticsModel analytics);
}
