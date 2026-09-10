import 'package:flutter/material.dart';

class FarmerAuthProvider extends ChangeNotifier {
  bool _isLoggedIn = true; // default logged in for seamless demo, but allows sign in/out
  String _farmerPhone = '8088032780';
  String _farmerName = 'Shri Basavaraj';
  String _farmId = '8088032780_Samruddhi_Farm';
  String _farmName = 'Samruddhi Dairy & Livestock Farm';
  String _location = 'Mandya / Bangalore Rural, Karnataka';

  bool get isLoggedIn => _isLoggedIn;
  String get farmerPhone => _farmerPhone;
  String get farmerName => _farmerName;
  String get farmId => _farmId;
  String get farmName => _farmName;
  String get location => _location;

  void login({
    required String phone,
    required String farmerName,
    required String farmId,
    required String farmName,
    String? location,
  }) {
    _farmerPhone = phone;
    _farmerName = farmerName;
    _farmId = farmId;
    _farmName = farmName;
    if (location != null) _location = location;
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}
