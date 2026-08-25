import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cattle_model.dart';
import '../models/alert_model.dart';
import '../models/geofence_model.dart';
import '../services/api_service.dart';

class CattleProvider with ChangeNotifier {
  List<CattleModel> _cattleList = [
    CattleModel(
      cowId: 'KA_1989',
      name: 'Ganga',
      breed: 'Gir (A2 Milk)',
      ageYears: 3.5,
      lactationStage: 'Peak Lactation',
      hardwareImei: 'IMEI-8088327803-01',
      latestBehavior: 'Standing',
      behaviorId: 1,
      batteryLevel: 72,
      batteryStatus: 'NORMAL',
      totalSteps: 38,
      latitude: 13.286750,
      longitude: 77.595116,
      speed: 0.5,
      altitude: 980.7,
      satellites: 8,
      gpsStatus: 'OK',
      lastUpdated: 'Just now',
    ),
    CattleModel(
      cowId: 'KA_1990',
      name: 'Lakshmi',
      breed: 'Jersey Cross',
      ageYears: 4.0,
      lactationStage: 'Mid Lactation',
      hardwareImei: 'IMEI-8088327803-02',
      latestBehavior: 'Grazing',
      behaviorId: 7,
      batteryLevel: 85,
      batteryStatus: 'FULL',
      totalSteps: 420,
      latitude: 13.308692,
      longitude: 77.527069,
      speed: 0.8,
      altitude: 920.0,
      satellites: 9,
      gpsStatus: 'OK',
      lastUpdated: 'Just now',
    ),
    CattleModel(
      cowId: 'KA_1991',
      name: 'Gauri',
      breed: 'Pure Gir Breed',
      ageYears: 2.8,
      lactationStage: 'Early Lactation',
      hardwareImei: 'IMEI-8088327803-03',
      latestBehavior: 'Lying',
      behaviorId: 4,
      batteryLevel: 90,
      batteryStatus: 'FULL',
      totalSteps: 120,
      latitude: 13.309100,
      longitude: 77.528100,
      speed: 0.0,
      altitude: 918.0,
      satellites: 8,
      gpsStatus: 'OK',
      lastUpdated: 'Just now',
    ),
  ];

  CattleModel? _selectedCow;
  List<AlertModel> _alertsList = [];
  GeofenceModel _geofence = GeofenceModel(
    centerLat: 13.308692,
    centerLon: 77.527069,
    radiusKm: 2.0,
  );

  bool _isLoading = false;
  bool _isConnected = false;
  DateTime? _lastSyncTime;
  Timer? _pollingTimer;

  // Simulator / Manual override state
  int? _simulatedBehaviorId;

  // 21-Day Baseline Calibration state
  int _baselineDay = 1;
  double _baselineProgress = 0.05;

  // Fertility & AI Countdown
  Duration _aiCountdown = const Duration(hours: 11, minutes: 41, seconds: 13);
  Timer? _countdownTimer;
  int _heatIntensityScore = 6;

  List<CattleModel> get cattleList => _cattleList;
  CattleModel get selectedCow => _selectedCow ?? _cattleList.first;
  List<AlertModel> get alertsList => _alertsList;
  GeofenceModel get geofence => _geofence;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get activeBehaviorId => _simulatedBehaviorId ?? selectedCow.behaviorId;
  int get baselineDay => _baselineDay;
  double get baselineProgress => _baselineProgress;
  Duration get aiCountdown => _aiCountdown;
  int get heatIntensityScore => _heatIntensityScore;

  int get unacknowledgedAlertsCount =>
      _alertsList.where((a) => !a.acknowledged).length;

  CattleProvider() {
    _selectedCow = _cattleList.first;
    startAutoPolling();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_aiCountdown.inSeconds > 0) {
        _aiCountdown = _aiCountdown - const Duration(seconds: 1);
        notifyListeners();
      }
    });
  }

  void startAutoPolling() {
    refreshData();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      refreshData(silent: true);
    });
  }

  void stopAutoPolling() {
    _pollingTimer?.cancel();
  }

  void setSimulatedBehavior(int behaviorId) {
    _simulatedBehaviorId = behaviorId;
    notifyListeners();
  }

  void clearSimulatedBehavior() {
    _simulatedBehaviorId = null;
    notifyListeners();
  }

  void recalibrateBaseline() {
    _baselineDay = 1;
    _baselineProgress = 0.05;
    notifyListeners();
  }

  void updateGeofenceRadius(double newRadiusKm) {
    _geofence = GeofenceModel(
      centerLat: _geofence.centerLat,
      centerLon: _geofence.centerLon,
      radiusKm: newRadiusKm,
    );
    notifyListeners();
    ApiService.updateGeofence(_geofence.centerLat, _geofence.centerLon, newRadiusKm);
  }

  void setCustomPastureCenter(double lat, double lon) {
    _geofence = GeofenceModel(
      centerLat: lat,
      centerLon: lon,
      radiusKm: _geofence.radiusKm,
    );
    notifyListeners();
    ApiService.updateGeofence(lat, lon, _geofence.radiusKm);
  }

  Future<bool> updateGeofenceFull(double lat, double lon, double radiusKm) async {
    _geofence = GeofenceModel(
      centerLat: lat,
      centerLon: lon,
      radiusKm: radiusKm,
    );
    notifyListeners();
    return await ApiService.updateGeofence(lat, lon, radiusKm);
  }

  Future<void> refreshData({bool silent = false}) async {
    if (!silent && _cattleList.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        ApiService.fetchCattle(),
        ApiService.fetchAlerts(),
        ApiService.fetchGeofence(),
      ]);

      final fetchedCattle = results[0] as List<CattleModel>;
      final fetchedAlerts = results[1] as List<AlertModel>;
      final fetchedGeofence = results[2] as GeofenceModel?;

      if (fetchedCattle.isNotEmpty) {
        _cattleList = fetchedCattle;
        _isConnected = true;
        _lastSyncTime = DateTime.now();

        if (_selectedCow != null) {
          final matched = _cattleList.firstWhere(
            (c) => c.cowId == _selectedCow!.cowId,
            orElse: () => _cattleList.first,
          );
          _selectedCow = matched;
        } else {
          _selectedCow = _cattleList.first;
        }
      }

      if (fetchedAlerts.isNotEmpty) {
        _alertsList = fetchedAlerts;
      }
      if (fetchedGeofence != null) {
        _geofence = fetchedGeofence;
      }
    } catch (e) {
      // Keep existing data on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCow(CattleModel cow) {
    _selectedCow = cow;
    _simulatedBehaviorId = null;
    notifyListeners();
  }

  Future<void> acknowledgeAlert(int alertId) async {
    final success = await ApiService.acknowledgeAlert(alertId);
    if (success) {
      _alertsList = _alertsList.map((a) {
        if (a.id == alertId) {
          return AlertModel(
            id: a.id,
            cowId: a.cowId,
            alertType: a.alertType,
            severity: a.severity,
            message: a.message,
            timestamp: a.timestamp,
            acknowledged: true,
          );
        }
        return a;
      }).toList();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
