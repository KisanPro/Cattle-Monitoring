import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cattle_model.dart';
import '../models/alert_model.dart';
import '../models/geofence_model.dart';

class ApiService {
  // Default to the live AWS EC2 Cloud Server
  static String baseUrl = "http://15.206.32.94:5000";

  static void setBaseUrl(String newUrl) {
    if (newUrl.endsWith('/')) {
      baseUrl = newUrl.substring(0, newUrl.length - 1);
    } else {
      baseUrl = newUrl;
    }
  }

  // Fetch all active cattle with latest live telemetry
  static Future<List<CattleModel>> fetchCattle() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/v1/cows'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['cows'] is List) {
          return (data['cows'] as List)
              .map((c) => CattleModel.fromJson(c))
              .toList();
        }
      }
      return [];
    } catch (e) {
      // Return empty list on failure so UI displays offline indicator
      return [];
    }
  }

  // Fetch all active anomaly alerts
  static Future<List<AlertModel>> fetchAlerts() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/v1/alerts'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((a) => AlertModel.fromJson(a)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Acknowledge a critical alert
  static Future<bool> acknowledgeAlert(int alertId) async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/api/v1/alerts/$alertId/acknowledge'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Fetch geofence configuration
  static Future<GeofenceModel?> fetchGeofence() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/v1/geofence'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GeofenceModel.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update geofence configuration
  static Future<bool> updateGeofence(double lat, double lon, double radiusKm) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/geofence'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'center_latitude': lat,
          'center_longitude': lon,
          'radius_km': radiusKm,
        }),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
