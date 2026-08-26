import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/milk_repository.dart';
import '../models/milk_record_model.dart';
import '../models/milk_analytics_model.dart';

class PostgresMilkService implements MilkRepository {
  /// Live Clean AWS EC2 Backend Base URL
  final String baseUrl;
  final String farmId;

  final StreamController<List<MilkRecordModel>> _streamController =
      StreamController<List<MilkRecordModel>>.broadcast();
  Timer? _pollingTimer;
  List<MilkRecordModel> _cachedRecords = [];

  PostgresMilkService({
    this.baseUrl = 'http://100.31.238.245:8082',
    this.farmId = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
  }) {
    _startPolling();
  }

  void _startPolling() {
    _fetchRecords();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchRecords();
    });
  }

  Future<void> _fetchRecords() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl/milk-production/?farm_id=$farmId');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 4));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final List<dynamic> data = jsonDecode(body);
        final records = data.map((json) {
          final cid = json['cattle_id']?.toString() ?? 'COW-101';
          final cname = json['cattle_name']?.toString() ??
              (cid.length >= 4 ? 'Cattle-${cid.substring(0, 4)}' : cid);

          return MilkRecordModel(
            id: json['record_id']?.toString(),
            cattleId: cid,
            cattleName: cname,
            milkTime: (json['milking_time'] as String?)?.toLowerCase() == 'evening'
                ? 'Evening'
                : 'Morning',
            quantity: (json['quantity_liters'] as num?)?.toDouble() ?? 0.0,
            fat: (json['fat_percentage'] as num?)?.toDouble() ?? 4.0,
            snf: (json['snf_percentage'] as num?)?.toDouble() ?? 8.5,
            timestamp: json['recorded_at'] != null
                ? DateTime.parse(json['recorded_at']).toLocal()
                : DateTime.now(),
          );
        }).toList();

        _cachedRecords = records;
        if (!_streamController.isClosed) {
          _streamController.add(records);
        }
      }
    } catch (e) {
      debugPrint('Error fetching AWS PostgreSQL records: $e');
    } finally {
      client.close();
    }
  }

  @override
  Future<void> addMilkRecord(MilkRecordModel record) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl/milk-production/');
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 5));
      request.headers.set('content-type', 'application/json');

      final payload = {
        'cattle_id': record.cattleId.isNotEmpty ? record.cattleId : 'COW-101',
        'cattle_name': record.cattleName.isNotEmpty ? record.cattleName : 'Gauri',
        'farm_id': farmId,
        'quantity_liters': record.quantity,
        'quality_grade': 'Grade A',
        'fat_percentage': record.fat,
        'snf_percentage': record.snf,
        'milking_time': record.milkTime.toLowerCase(),
      };

      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      if (response.statusCode != 200 && response.statusCode != 201) {
        final body = await response.transform(utf8.decoder).join();
        throw Exception('Failed to insert record: $body');
      }

      // Refresh immediately after adding
      await _fetchRecords();
    } finally {
      client.close();
    }
  }

  @override
  Stream<List<MilkRecordModel>> getMilkRecords() async* {
    if (_cachedRecords.isNotEmpty) {
      yield _cachedRecords;
    }
    yield* _streamController.stream;
  }

  @override
  Future<MilkAnalyticsModel> getMilkAnalytics() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl/milk-production/analytics/?farm_id=$farmId');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 4));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        return MilkAnalyticsModel(
          dailyTotal: (data['daily_total'] as num?)?.toDouble() ?? 0.0,
          morningMilk: (data['morning_total'] as num?)?.toDouble() ?? 0.0,
          eveningMilk: (data['evening_total'] as num?)?.toDouble() ?? 0.0,
          bestDay: 'Wednesday',
          avgDaily: (data['daily_total'] as num?)?.toDouble() ?? 0.0,
          weeklyTotal: ((data['daily_total'] as num?)?.toDouble() ?? 0.0) * 7,
          monthlyTotal: ((data['daily_total'] as num?)?.toDouble() ?? 0.0) * 30,
        );
      }
    } catch (e) {
      debugPrint('Error fetching AWS PostgreSQL analytics: $e');
    } finally {
      client.close();
    }

    return MilkAnalyticsModel.empty();
  }

  @override
  Future<void> updateMilkAnalytics(MilkAnalyticsModel analytics) async {}

  void dispose() {
    _pollingTimer?.cancel();
    _streamController.close();
  }
}
