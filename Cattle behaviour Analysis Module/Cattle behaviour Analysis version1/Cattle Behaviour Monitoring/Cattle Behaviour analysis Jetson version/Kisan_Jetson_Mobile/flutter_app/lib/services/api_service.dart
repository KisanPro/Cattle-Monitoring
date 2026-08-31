import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/alert.dart';
import '../models/telemetry.dart';

class ApiService {
  static final http.Client _client = http.Client();

  static Future<FarmTelemetry?> fetchTelemetry() async {
    try {
      final response = await _client.get(Uri.parse('${AppConfig.ec2ServerUrl}/api/status'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return FarmTelemetry.fromJson(data);
      }
    } catch (e) {
      print('Error fetching telemetry: $e');
    }
    return null;
  }

  static Future<List<FarmAlert>> fetchAlerts() async {
    try {
      final response = await _client.get(Uri.parse('${AppConfig.ec2ServerUrl}/api/alerts'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => FarmAlert.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching alerts: $e');
    }
    return [];
  }

  static Future<bool> updateMasterSheet(List<String> ids) async {
    try {
      final response = await _client.post(
        Uri.parse('${AppConfig.ec2ServerUrl}/api/master_sheet'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': ids}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating master sheet: $e');
    }
    return false;
  }
}
