import 'dart:async';
import '../models/vaccination_model.dart';
import '../models/reminder_model.dart';
import '../services/aws_api_service.dart';
import '../services/mock_database_service.dart';

class VaccinationRepository {
  final String farmerId;
  late final AwsApiService _awsApiService;
  late final MockDatabaseService _mockDatabaseService;
  bool _useAws = true;

  VaccinationRepository({required this.farmerId}) {
    _mockDatabaseService = MockDatabaseService();
    _awsApiService = AwsApiService(
      farmerId: farmerId,
      baseUrl: 'https://sdq2lyv15a.execute-api.us-east-1.amazonaws.com/v1',
    );
  }

  // Allow manual override for testing purposes
  set useAws(bool value) {
    _useAws = value;
  }

  bool get isUsingAws => _useAws;

  // Backward compatibility for legacy Firebase properties
  set useFirestore(bool value) {
    _useAws = value;
  }

  bool get isUsingFirestore => _useAws;

  Future<void> addVaccination(VaccinationModel vaccination) async {
    if (_useAws) {
      try {
        await _awsApiService.addVaccination(vaccination);
      } catch (e) {
        print("Error saving to AWS: $e. Falling back to Mock DB.");
        await _mockDatabaseService.addVaccination(vaccination);
      }
    } else {
      await _mockDatabaseService.addVaccination(vaccination);
    }
  }

  Stream<List<VaccinationModel>> getVaccinationsStream() {
    final controller = StreamController<List<VaccinationModel>>();
    StreamSubscription? awsSub;
    StreamSubscription? mockSub;

    void useMockFallback() {
      mockSub?.cancel();
      mockSub = _mockDatabaseService.vaccinationsStream.listen(
        (mockData) {
          if (!controller.isClosed) controller.add(mockData);
        },
        onError: (mockErr) {
          if (!controller.isClosed) controller.addError(mockErr);
        },
      );
    }

    if (!_useAws) {
      return _mockDatabaseService.vaccinationsStream;
    }

    awsSub = _awsApiService.getVaccinationsStream().listen(
      (data) {
        if (data.isNotEmpty) {
          if (!controller.isClosed) controller.add(data);
        } else {
          useMockFallback();
        }
      },
      onError: (err) {
        useMockFallback();
      },
    );

    controller.onCancel = () {
      awsSub?.cancel();
      mockSub?.cancel();
    };

    return controller.stream;
  }

  Future<void> addReminder(ReminderModel reminder) async {
    if (_useAws) {
      try {
        await _awsApiService.addReminder(reminder);
      } catch (e) {
        print("Error saving reminder to AWS: $e. Falling back to Mock DB.");
        await _mockDatabaseService.addReminder(reminder);
      }
    } else {
      await _mockDatabaseService.addReminder(reminder);
    }
  }

  Stream<List<ReminderModel>> getRemindersStream() {
    final controller = StreamController<List<ReminderModel>>();
    StreamSubscription? awsSub;
    StreamSubscription? mockSub;

    void useMockFallback() {
      mockSub?.cancel();
      mockSub = _mockDatabaseService.remindersStream.listen(
        (mockData) {
          if (!controller.isClosed) controller.add(mockData);
        },
        onError: (mockErr) {
          if (!controller.isClosed) controller.addError(mockErr);
        },
      );
    }

    if (!_useAws) {
      return _mockDatabaseService.remindersStream;
    }

    awsSub = _awsApiService.getRemindersStream().listen(
      (data) {
        if (data.isNotEmpty) {
          if (!controller.isClosed) controller.add(data);
        } else {
          useMockFallback();
        }
      },
      onError: (err) {
        useMockFallback();
      },
    );

    controller.onCancel = () {
      awsSub?.cancel();
      mockSub?.cancel();
    };

    return controller.stream;
  }

  Future<void> updateReminderStatus(String reminderId, String status) async {
    if (_useAws && !reminderId.startsWith('mock_')) {
      try {
        await _awsApiService.updateReminderStatus(reminderId, status);
      } catch (e) {
        print("Error updating reminder in AWS: $e. Updating in Mock DB.");
        await _mockDatabaseService.updateReminderStatus(reminderId, status);
      }
    } else {
      await _mockDatabaseService.updateReminderStatus(reminderId, status);
    }
  }
}
