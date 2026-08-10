import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/repositories/milk_repository.dart';
import '../../data/models/milk_record_model.dart';
import '../../data/models/milk_analytics_model.dart';
import '../../data/services/milk_firestore_service.dart';
import '../../data/services/mock_milk_service.dart';

class MilkProvider extends ChangeNotifier {
  late MilkRepository _repository;
  bool _isMockMode = true; // Defaults to Mock Mode so the app runs out-of-the-box
  bool _isLoading = false;
  
  List<MilkRecordModel> _records = [];
  MilkAnalyticsModel _analytics = MilkAnalyticsModel.empty();
  
  // Streams
  StreamSubscription<List<MilkRecordModel>>? _streamSubscription;
  
  // Filters
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  // Advanced Enterprise Properties
  double _baseMilkPrice = 52.0;
  bool _useQualityPricing = true;
  final double _bmcTankCapacity = 500.0;
  double _bmcTankVolume = 0.0;
  double _bmcTankTemperature = 3.8;
  final List<String> _bmcDispatchedLogs = [];

  // Getters
  bool get isMockMode => _isMockMode;
  bool get isLoading => _isLoading;
  List<MilkRecordModel> get records => _records;
  MilkAnalyticsModel get analytics => _analytics;
  String get searchQuery => _searchQuery;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  double get baseMilkPrice => _baseMilkPrice;
  bool get useQualityPricing => _useQualityPricing;
  double get bmcTankCapacity => _bmcTankCapacity;
  double get bmcTankVolume => _bmcTankVolume;
  double get bmcTankTemperature => _bmcTankTemperature;
  List<String> get bmcDispatchedLogs => _bmcDispatchedLogs;

  set baseMilkPrice(double val) {
    _baseMilkPrice = val;
    notifyListeners();
  }

  set useQualityPricing(bool val) {
    _useQualityPricing = val;
    notifyListeners();
  }

  // Quality Pricing rate calculator
  double calculateRate(double fat, double snf) {
    if (!_useQualityPricing) return _baseMilkPrice;
    // Standard fat/snf pricing formula
    const double baseFat = 4.0;
    const double baseSnf = 8.5;
    double rate = _baseMilkPrice * ((fat * 0.6 / baseFat) + (snf * 0.4 / baseSnf));
    return double.parse(rate.toStringAsFixed(2));
  }

  // Dispatch BMC Tank
  void dispatchBmcTank() {
    final todayRecs = todayEntries;
    final double volumeToDispatch = _bmcTankVolume > 0 ? _bmcTankVolume : todayRecs.fold(0.0, (s, r) => s + r.quantity);
    if (volumeToDispatch == 0.0) return;

    final String timeStr = DateFormat('h:mm a, dd MMM').format(DateTime.now());
    _bmcDispatchedLogs.insert(
      0, 
      "Dispatched ${volumeToDispatch.toStringAsFixed(1)}L to Dairy Coop at $timeStr (Avg Fat: $bmcAvgFat%, SNF: $bmcAvgSnf%)"
    );
    _bmcTankVolume = 0.0;
    notifyListeners();
  }


  // Milk Quality Getters
  double get avgFat {
    if (_records.isEmpty) return 0.0;
    double sum = _records.fold(0.0, (s, r) => s + r.fat);
    return double.parse((sum / _records.length).toStringAsFixed(2));
  }

  double get avgSnf {
    if (_records.isEmpty) return 0.0;
    double sum = _records.fold(0.0, (s, r) => s + r.snf);
    return double.parse((sum / _records.length).toStringAsFixed(2));
  }

  List<MilkRecordModel> get todayEntries {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return _records.where((r) => r.timestamp.toIso8601String().substring(0, 10) == todayStr).toList();
  }

  double get bmcAvgFat {
    final todayRecs = todayEntries;
    if (todayRecs.isEmpty) return 4.2;
    double totalFatQty = todayRecs.fold(0.0, (s, r) => s + (r.fat * r.quantity));
    double totalQty = todayRecs.fold(0.0, (s, r) => s + r.quantity);
    return totalQty > 0 ? double.parse((totalFatQty / totalQty).toStringAsFixed(2)) : 4.2;
  }

  double get bmcAvgSnf {
    final todayRecs = todayEntries;
    if (todayRecs.isEmpty) return 8.5;
    double totalSnfQty = todayRecs.fold(0.0, (s, r) => s + (r.snf * r.quantity));
    double totalQty = todayRecs.fold(0.0, (s, r) => s + r.quantity);
    return totalQty > 0 ? double.parse((totalSnfQty / totalQty).toStringAsFixed(2)) : 8.5;
  }

  List<MilkRecordModel> get filteredRecords {
    return _records.where((record) {
      // Search match
      final matchesSearch = record.cattleName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          record.cattleId.toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Date range match
      bool matchesDate = true;
      if (_startDate != null) {
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final recDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        matchesDate = recDate.isAtSameMomentAs(start) || recDate.isAfter(start);
      }
      if (matchesDate && _endDate != null) {
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        matchesDate = record.timestamp.isBefore(end);
      }

      return matchesSearch && matchesDate;
    }).toList();
  }

  MilkProvider() {
    _initializeRepository();
  }

  void _initializeRepository() {
    if (_isMockMode) {
      _repository = MockMilkService();
    } else {
      _repository = MilkFirestoreService(farmerId: 'farmer_kisan_pro_default');
    }
    _listenToMilkRecords();
    _fetchAnalytics();
  }

  void toggleMockMode() {
    _isMockMode = !_isMockMode;
    _streamSubscription?.cancel();
    _records.clear();
    _analytics = MilkAnalyticsModel.empty();
    notifyListeners();
    _initializeRepository();
  }

  void _listenToMilkRecords() {
    _isLoading = true;
    notifyListeners();
    
    _streamSubscription?.cancel();
    _streamSubscription = _repository.getMilkRecords().listen(
      (data) {
        _records = data;
        _isLoading = false;
        _recalculateLocalAnalytics();
        if (_bmcTankVolume == 0.0) {
          _bmcTankVolume = todayEntries.fold(0.0, (s, r) => s + r.quantity);
        }
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error listening to milk records: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _fetchAnalytics() async {
    try {
      final data = await _repository.getMilkAnalytics();
      _analytics = data;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
    }
  }

  void _recalculateLocalAnalytics() {
    if (_records.isEmpty) return;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    double dailyTotal = 0.0;
    double morningTotal = 0.0;
    double eveningTotal = 0.0;

    for (final r in _records) {
      final dateStr = r.timestamp.toIso8601String().substring(0, 10);
      if (dateStr == todayStr) {
        dailyTotal += r.quantity;
        if (r.milkTime == 'Morning') {
          morningTotal += r.quantity;
        } else if (r.milkTime == 'Evening') {
          eveningTotal += r.quantity;
        }
      }
    }

    // Average
    final dailyTotals = <String, double>{};
    for (final r in _records) {
      final dateStr = r.timestamp.toIso8601String().substring(0, 10);
      dailyTotals[dateStr] = (dailyTotals[dateStr] ?? 0.0) + r.quantity;
    }
    double totalSum = _records.fold(0.0, (sum, r) => sum + r.quantity);
    double avg = dailyTotals.isEmpty ? 0.0 : totalSum / dailyTotals.keys.length;

    // Find best day
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
      bestDay = weekdays[DateTime.parse(bestDate).weekday];
    }

    // Weekly/Monthly totals
    double weeklyTotal = _records
        .where((r) => r.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .fold(0.0, (sum, r) => sum + r.quantity);

    double monthlyTotal = _records
        .where((r) => r.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 30))))
        .fold(0.0, (sum, r) => sum + r.quantity);

    _analytics = MilkAnalyticsModel(
      dailyTotal: dailyTotal,
      morningMilk: morningTotal > 0 ? morningTotal : _analytics.morningMilk,
      eveningMilk: eveningTotal > 0 ? eveningTotal : _analytics.eveningMilk,
      bestDay: bestDay,
      avgDaily: double.parse(avg.toStringAsFixed(1)),
      weeklyTotal: weeklyTotal,
      monthlyTotal: monthlyTotal,
    );
  }

  Future<void> addRecord(MilkRecordModel record) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.addMilkRecord(record);
      _bmcTankVolume = (_bmcTankVolume + record.quantity).clamp(0.0, _bmcTankCapacity);
      _bmcTankTemperature = 3.5 + (DateTime.now().second % 10) * 0.08;
      await _fetchAnalytics();
    } catch (e) {
      debugPrint('Error adding record: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filter modifiers
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  // Group records by day and cow
  List<List<MilkRecordModel>> groupRecordsByCattleAndDay(List<MilkRecordModel> inputRecords) {
    final Map<String, List<MilkRecordModel>> grouped = {};
    for (final r in inputRecords) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.timestamp);
      final key = "${dateStr}_${r.cattleName.toLowerCase()}";
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(r);
    }
    // Sort grouped records by timestamp of the first item (descending order)
    final sortedGroups = grouped.values.toList()
      ..sort((a, b) => b.first.timestamp.compareTo(a.first.timestamp));
    return sortedGroups;
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
