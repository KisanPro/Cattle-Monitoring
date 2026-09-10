import 'package:flutter/material.dart';
import '../models/cattle_profile_model.dart';
import '../../weight_monitoring/services/api_service.dart';

class CattleRegistryProvider extends ChangeNotifier {
  CattleRegistryProvider() {
    autoSyncTelemetry();
  }

  Future<void> autoSyncTelemetry() async {
    try {
      final apiService = ApiService();
      final history = await apiService.getHistory();
      for (var item in history) {
        final cowId = (item['cow_id'] ?? '').toString();
        final num? wVal = item['weight_kg'] ?? item['predicted_weight_kg'];
        if (cowId.isNotEmpty && wVal != null && wVal > 0) {
          updateCattleTelemetry(cattleId: cowId, weight: wVal.toDouble());
        }
      }
    } catch (_) {}
  }

  // Pre-registered 5 sample cattle representing diverse breeds and statuses
  final List<CattleProfile> _cattles = [
    CattleProfile(
      cattleId: 'KA-1989',
      name: 'Geetha',
      breed: 'HF (Holstein Friesian)',
      ageYears: 4,
      gender: 'Female',
      tagNumber: 'KP-1989-HF',
      currentWeightKg: 389.6,
      dailyMilkLiters: 11.5,
      vaccineStatus: 'Due Soon',
      lactationStage: 'Late Lactation',
      colorMarkings: 'Black & White Patches',
      riskLevel: 'HIGH RISK',
      healthScore: 48.0,
      registeredDate: DateTime(2026, 1, 15),
    ),
    CattleProfile(
      cattleId: 'KA-1021',
      name: 'Lakshmi',
      breed: 'Gir (Indigenous Dairy)',
      ageYears: 5,
      gender: 'Female',
      tagNumber: 'KP-1021-GR',
      currentWeightKg: 380.0,
      dailyMilkLiters: 14.0,
      vaccineStatus: 'Up to Date',
      lactationStage: 'Peak Lactation',
      colorMarkings: 'Reddish Brown & White',
      riskLevel: 'NORMAL',
      healthScore: 92.0,
      registeredDate: DateTime(2026, 2, 10),
    ),
    CattleProfile(
      cattleId: 'KA-3045',
      name: 'Ganga',
      breed: 'Hallikar (Indigenous Draft)',
      ageYears: 3,
      gender: 'Female',
      tagNumber: 'KP-3045-HL',
      currentWeightKg: 360.0,
      dailyMilkLiters: 8.5,
      vaccineStatus: 'Due Soon',
      lactationStage: 'Early Lactation',
      colorMarkings: 'Grey & White',
      riskLevel: 'WARNING',
      healthScore: 72.0,
      registeredDate: DateTime(2026, 3, 5),
    ),
    CattleProfile(
      cattleId: 'KA-5512',
      name: 'Gauri',
      breed: 'Jersey (High-Yield Dairy)',
      ageYears: 4,
      gender: 'Female',
      tagNumber: 'KP-5512-JS',
      currentWeightKg: 410.0,
      dailyMilkLiters: 18.2,
      vaccineStatus: 'Up to Date',
      lactationStage: 'Peak Lactation',
      colorMarkings: 'Fawn / Light Brown',
      riskLevel: 'NORMAL',
      healthScore: 95.0,
      registeredDate: DateTime(2026, 4, 1),
    ),
    CattleProfile(
      cattleId: 'KA-7789',
      name: 'Kamadhenu',
      breed: 'Sahiwal (Zebu Dairy)',
      ageYears: 6,
      gender: 'Female',
      tagNumber: 'KP-7789-SW',
      currentWeightKg: 395.0,
      dailyMilkLiters: 12.0,
      vaccineStatus: 'Up to Date',
      lactationStage: 'Mid-Lactation',
      colorMarkings: 'Reddish Dun',
      riskLevel: 'NORMAL',
      healthScore: 88.0,
      registeredDate: DateTime(2026, 4, 20),
    ),
    CattleProfile(
      cattleId: 'AP-5040',
      name: 'Surabhi',
      breed: 'Punganur (Indigenous Tirupati Dwarf)',
      ageYears: 3,
      gender: 'Female',
      tagNumber: 'AP-5040-PNG',
      currentWeightKg: 215.0,
      dailyMilkLiters: 5.5,
      vaccineStatus: 'Due Soon',
      lactationStage: 'Peak Lactation',
      colorMarkings: 'White & Light Brown',
      riskLevel: 'WARNING',
      healthScore: 78.0,
      registeredDate: DateTime(2026, 5, 10),
    ),
  ];

  String _selectedCattleId = 'KA-1989';

  List<CattleProfile> get cattles => _cattles;
  String get selectedCattleId => _selectedCattleId;

  CattleProfile get selectedCattle {
    return _cattles.firstWhere(
      (c) => c.cattleId == _selectedCattleId,
      orElse: () => _cattles.first,
    );
  }

  /// Strict check to verify if a cattle ID or name belongs to this farmer's registered herd
  bool isCattleRegistered(String? cattleId, [String? cattleName]) {
    if ((cattleId == null || cattleId.trim().isEmpty) && (cattleName == null || cattleName.trim().isEmpty)) {
      return false;
    }
    final targetId = cattleId?.trim().toLowerCase() ?? '';
    final targetName = cattleName?.trim().toLowerCase() ?? '';

    return _cattles.any((c) {
      final cId = c.cattleId.trim().toLowerCase();
      final cName = c.name.trim().toLowerCase();
      return (targetId.isNotEmpty && (cId == targetId || cId.contains(targetId) || targetId.contains(cId))) ||
             (targetName.isNotEmpty && (cName == targetName || cName.contains(targetName) || targetName.contains(cName)));
    });
  }

  void selectCattle(String cattleId) {
    if (_cattles.any((c) => c.cattleId == cattleId)) {
      _selectedCattleId = cattleId;
      notifyListeners();
    }
  }

  void registerCattle(CattleProfile profile) {
    // Check if ID already exists, update or insert
    final idx = _cattles.indexWhere((c) => c.cattleId == profile.cattleId);
    if (idx >= 0) {
      _cattles[idx] = profile;
    } else {
      _cattles.insert(0, profile);
    }
    _selectedCattleId = profile.cattleId;
    notifyListeners();
  }

  void updateCattleTelemetry({
    required String cattleId,
    double? weight,
    double? milk,
    String? vaccineStatus,
    double? healthScore,
    String? riskLevel,
  }) {
    final idx = _cattles.indexWhere((c) => c.cattleId.trim().toLowerCase() == cattleId.trim().toLowerCase());
    if (idx >= 0) {
      final old = _cattles[idx];
      _cattles[idx] = old.copyWith(
        currentWeightKg: weight ?? old.currentWeightKg,
        dailyMilkLiters: milk ?? old.dailyMilkLiters,
        vaccineStatus: vaccineStatus ?? old.vaccineStatus,
        healthScore: healthScore ?? old.healthScore,
        riskLevel: riskLevel ?? old.riskLevel,
      );
      notifyListeners();
    }
  }

  void deleteCattle(String cattleId) {
    _cattles.removeWhere((c) => c.cattleId == cattleId);
    if (_selectedCattleId == cattleId && _cattles.isNotEmpty) {
      _selectedCattleId = _cattles.first.cattleId;
    }
    notifyListeners();
  }
}
