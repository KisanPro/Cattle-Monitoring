import 'dart:async';
import '../../domain/repositories/milk_repository.dart';
import '../models/milk_record_model.dart';
import '../models/milk_analytics_model.dart';

class MockMilkService implements MilkRepository {
  static final List<MilkRecordModel> _records = [];
  static bool _initialized = false;
  final StreamController<List<MilkRecordModel>> _controller = StreamController<List<MilkRecordModel>>.broadcast();
  MilkAnalyticsModel _analytics = MilkAnalyticsModel.empty();

  MockMilkService() {
    if (!_initialized) {
      _initMockData();
      _initialized = true;
    }
    _recalculateAnalytics();
  }

  static void syncFromCloud(List<MilkRecordModel> cloudRecords) {
    if (cloudRecords.isEmpty) return;
    for (final cr in cloudRecords) {
      final existingIndex = _records.indexWhere((r) =>
          (r.id != null && cr.id != null && r.id == cr.id) ||
          (r.cattleId == cr.cattleId &&
              r.milkTime.toLowerCase() == cr.milkTime.toLowerCase() &&
              r.timestamp.day == cr.timestamp.day &&
              r.timestamp.month == cr.timestamp.month &&
              r.timestamp.year == cr.timestamp.year));
      if (existingIndex >= 0) {
        _records[existingIndex] = cr;
      } else {
        _records.insert(0, cr);
      }
    }
  }

  static void addSharedRecord(MilkRecordModel record) {
    final existingIndex = _records.indexWhere((r) =>
        (r.id != null && record.id != null && r.id == record.id) ||
        (r.cattleId == record.cattleId &&
            r.milkTime.toLowerCase() == record.milkTime.toLowerCase() &&
            r.timestamp.day == record.timestamp.day &&
            r.timestamp.month == record.timestamp.month &&
            r.timestamp.year == record.timestamp.year));
    if (existingIndex >= 0) {
      _records[existingIndex] = record;
    } else {
      _records.insert(0, record);
    }
  }

  void _initMockData() {
    final now = DateTime.now();
    final cattle = [
      {'id': 'KP-201', 'name': 'Lakshmi'},
      {'id': 'KP-202', 'name': 'Ganga'},
      {'id': 'KP-203', 'name': 'Gowri'},
      {'id': 'KP-204', 'name': 'Saraswati'},
    ];

    // Generate last 10 days of data
    for (int i = 9; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      for (final cow in cattle) {
        final hashStr = cow['name']!;
        
        // Morning Milk
        _records.add(MilkRecordModel(
          id: 'mock_m_${i}_${cow['id']}',
          cattleId: cow['id']!,
          cattleName: cow['name']!,
          milkTime: 'Morning',
          quantity: 8.0 + (i % 3) + (hashStr.length % 3) * 1.5,
          fat: 4.0 + (i % 2) * 0.4 + (hashStr.length % 2) * 0.5,
          snf: 8.3 + (i % 3) * 0.1 + (hashStr.length % 3) * 0.1,
          timestamp: DateTime(date.year, date.month, date.day, 6, 30),
        ));

        // Evening Milk
        _records.add(MilkRecordModel(
          id: 'mock_e_${i}_${cow['id']}',
          cattleId: cow['id']!,
          cattleName: cow['name']!,
          milkTime: 'Evening',
          quantity: 6.5 + (i % 2) + (hashStr.length % 2) * 1.2,
          fat: 4.2 + (i % 3) * 0.3 + (hashStr.length % 2) * 0.4,
          snf: 8.4 + (i % 2) * 0.1 + (hashStr.length % 3) * 0.1,
          timestamp: DateTime(date.year, date.month, date.day, 18, 0),
        ));
      }
    }
    _recalculateAnalytics();
  }

  void _recalculateAnalytics() {
    if (_records.isEmpty) {
      _analytics = MilkAnalyticsModel.empty();
      return;
    }

    double total = _records.fold(0.0, (sum, r) => sum + r.quantity);
    
    // Group by date to find daily totals
    final dailyTotals = <String, double>{};
    double morningTotal = 0.0;
    double eveningTotal = 0.0;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    for (final r in _records) {
      final local = r.timestamp.isUtc ? r.timestamp.toLocal() : r.timestamp;
      final dateStr = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      dailyTotals[dateStr] = (dailyTotals[dateStr] ?? 0.0) + r.quantity;

      if (dateStr == todayStr) {
        if (r.milkTime.toLowerCase() == 'morning') {
          morningTotal += r.quantity;
        } else if (r.milkTime.toLowerCase() == 'evening') {
          eveningTotal += r.quantity;
        }
      }
    }

    final uniqueDates = dailyTotals.keys.toList();
    double avg = uniqueDates.isEmpty ? 0.0 : total / uniqueDates.length;

    // Find best day of week
    String bestDay = 'Monday';
    double maxDaily = 0.0;
    
    final weekdays = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    String bestDate = '';
    dailyTotals.forEach((date, qty) {
      if (qty > maxDaily) {
        maxDaily = qty;
        bestDate = date;
      }
    });

    if (bestDate.isNotEmpty) {
      final dt = DateTime.parse(bestDate);
      bestDay = weekdays[dt.weekday];
    }

    // Weekly total (last 7 days)
    double weeklyTotal = _records
        .where((r) => r.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .fold(0.0, (sum, r) => sum + r.quantity);

    // Monthly total (last 30 days)
    double monthlyTotal = _records
        .where((r) => r.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 30))))
        .fold(0.0, (sum, r) => sum + r.quantity);

    _analytics = MilkAnalyticsModel(
      dailyTotal: dailyTotals[todayStr] ?? 0.0,
      morningMilk: morningTotal > 0 ? morningTotal : 24.5,
      eveningMilk: eveningTotal > 0 ? eveningTotal : 20.2,
      bestDay: bestDay,
      avgDaily: double.parse(avg.toStringAsFixed(1)),
      weeklyTotal: weeklyTotal,
      monthlyTotal: monthlyTotal,
    );
  }

  @override
  Future<void> addMilkRecord(MilkRecordModel record) async {
    final newRecord = record.id == null || record.id!.isEmpty
        ? record.copyWith(id: 'mock_${DateTime.now().millisecondsSinceEpoch}')
        : record;
    addSharedRecord(newRecord);
    _recalculateAnalytics();
    _controller.add(List.from(_records));
  }

  @override
  Stream<List<MilkRecordModel>> getMilkRecords() async* {
    yield List.from(_records);
    yield* _controller.stream;
  }

  @override
  Future<MilkAnalyticsModel> getMilkAnalytics() async {
    _recalculateAnalytics();
    return _analytics;
  }

  @override
  Future<void> updateMilkAnalytics(MilkAnalyticsModel analytics) async {
    _analytics = analytics;
  }
}
