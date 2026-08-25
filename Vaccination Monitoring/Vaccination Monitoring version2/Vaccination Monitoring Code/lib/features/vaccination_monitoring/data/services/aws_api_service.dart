import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vaccination_model.dart';
import '../models/reminder_model.dart';

class AwsApiService {
  final String farmerId;
  final String baseUrl;
  final http.Client _client = http.Client();

  // Streams to emulate Firestore realtime updates
  final _vaccinationsController = StreamController<List<VaccinationModel>>.broadcast();
  final _remindersController = StreamController<List<ReminderModel>>.broadcast();

  // Internal cache to store fetched data
  List<VaccinationModel> _cachedVaccinations = [];
  List<ReminderModel> _cachedReminders = [];

  AwsApiService({
    required this.farmerId,
    this.baseUrl = 'https://sdq2lyv15a.execute-api.us-east-1.amazonaws.com/v1',
  });

  // Expose Streams
  Stream<List<VaccinationModel>> getVaccinationsStream() {
    // Trigger initial fetch when listened to
    _fetchVaccinations();
    return _vaccinationsController.stream;
  }

  Stream<List<ReminderModel>> getRemindersStream() {
    // Trigger initial fetch when listened to
    _fetchReminders();
    return _remindersController.stream;
  }

  // Fetch all vaccination records from AWS
  Future<void> _fetchVaccinations() async {
    try {
      final url = Uri.parse('$baseUrl/farmers/$farmerId/vaccinations');
      final response = await _client.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        _cachedVaccinations = jsonList.map((item) {
          final map = item as Map<String, dynamic>;
          final docId = map['id'] ?? map['documentId'] ?? '';
          return VaccinationModel.fromMap(map, docId);
        }).toList();

        // Sort descending by vaccination date
        _cachedVaccinations.sort((a, b) => b.vaccinationDate.compareTo(a.vaccinationDate));
        _vaccinationsController.add(List.unmodifiable(_cachedVaccinations));
      } else {
        throw Exception('Failed to load vaccinations from AWS. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('AWS Api Service error fetching vaccinations: $e');
      _vaccinationsController.addError(e);
    }
  }

  // Fetch all reminders from AWS
  Future<void> _fetchReminders() async {
    try {
      final url = Uri.parse('$baseUrl/farmers/$farmerId/reminders');
      final response = await _client.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        _cachedReminders = jsonList.map((item) {
          final map = item as Map<String, dynamic>;
          final docId = map['id'] ?? map['documentId'] ?? '';
          return ReminderModel.fromMap(map, docId);
        }).toList();

        // Sort ascending by reminder date
        _cachedReminders.sort((a, b) => a.reminderDate.compareTo(b.reminderDate));
        _remindersController.add(List.unmodifiable(_cachedReminders));
      } else {
        throw Exception('Failed to load reminders from AWS. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('AWS Api Service error fetching reminders: $e');
      _remindersController.addError(e);
    }
  }

  // Force trigger sync check
  Future<void> forceRefresh() async {
    await Future.wait([_fetchVaccinations(), _fetchReminders()]);
  }

  // Add vaccination record
  Future<void> addVaccination(VaccinationModel vaccination) async {
    final url = Uri.parse('$baseUrl/farmers/$farmerId/vaccinations');
    
    // Map dates to ISO strings for JSON standard formatting
    final payload = vaccination.toMap();
    payload['vaccinationDate'] = vaccination.vaccinationDate.toIso8601String();
    payload['nextReminderDate'] = vaccination.nextReminderDate.toIso8601String();

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Vaccination successfully recorded to AWS.');
      // Refresh local stream so the user sees changes immediately
      await _fetchVaccinations();
    } else {
      throw Exception('Failed to save vaccination to AWS. Status: ${response.statusCode}');
    }
  }

  // Add reminder record
  Future<void> addReminder(ReminderModel reminder) async {
    final url = Uri.parse('$baseUrl/farmers/$farmerId/reminders');
    
    final payload = reminder.toMap();
    payload['reminderDate'] = reminder.reminderDate.toIso8601String();

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Reminder successfully recorded to AWS.');
      await _fetchReminders();
    } else {
      throw Exception('Failed to save reminder to AWS. Status: ${response.statusCode}');
    }
  }

  // Update reminder status
  Future<void> updateReminderStatus(String reminderId, String status) async {
    final url = Uri.parse('$baseUrl/farmers/$farmerId/reminders/$reminderId');
    
    final response = await _client.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': status}),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200 || response.statusCode == 204) {
      print('Reminder status updated successfully to AWS.');
      await _fetchReminders();
    } else {
      throw Exception('Failed to update reminder status to AWS. Status: ${response.statusCode}');
    }
  }

  void dispose() {
    _vaccinationsController.close();
    _remindersController.close();
  }
}
