import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _defaultBaseUrl = 'http://35.153.224.84:5000';
  static const String _baseUrlKey = 'backend_base_url';
  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'logged_in_username';

  // Retrieve the configured base URL from SharedPreferences
  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  // Update and save the configured base URL
  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    String cleanedUrl = url.trim();
    if (cleanedUrl.endsWith('/')) {
      cleanedUrl = cleanedUrl.substring(0, cleanedUrl.length - 1);
    }
    await prefs.setString(_baseUrlKey, cleanedUrl);
  }

  // Token Management
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      try {
        bool ok = await login('farmer_basavaraj', 'Farmer@12345');
        if (!ok) {
          await register('farmer_basavaraj', 'Farmer@12345');
          await login('farmer_basavaraj', 'Farmer@12345');
        }
        token = prefs.getString(_tokenKey);
      } catch (_) {
        try {
          await register('farmer_basavaraj', 'Farmer@12345');
          await login('farmer_basavaraj', 'Farmer@12345');
          token = prefs.getString(_tokenKey);
        } catch (_) {}
      }
    }
    return token;
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey) ?? 'farmer_basavaraj';
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // JWT Registration
  Future<bool> register(String username, String password) async {
    final baseUrl = await getBaseUrl();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // JWT Login
  Future<bool> login(String username, String password) async {
    final baseUrl = await getBaseUrl();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        if (data['access_token'] != null) {
          await prefs.setString(_tokenKey, data['access_token']);
        }
        await prefs.setString(_userKey, data['username'] ?? username);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Ping the server to check connectivity
  Future<Map<String, dynamic>> checkStatus() async {
    final baseUrl = await getBaseUrl();
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/status')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        // Also trigger background token ensure
        getValidToken();
        return json.decode(response.body);
      }
      return {'ready': false, 'message': 'Status code: ${response.statusCode}'};
    } catch (e) {
      return {'ready': false, 'message': e.toString()};
    }
  }

  // Enqueue a weight estimation task (returns task_id)
  Future<Map<String, dynamic>> predictCattleWeight({
    File? sideImage,
    File? backImage,
    File? frontImage,
    File? rightImage,
    required String cowId,
    required String cowName,
    required String section,
    required String breed,
    double? calfMonths,
    double? knownOBL,
    double? knownWH,
    double? knownHG,
    double? knownHL,
  }) async {
    final baseUrl = await getBaseUrl();
    final token = await getValidToken();
    
    final uri = Uri.parse('$baseUrl/api/predict');
    final request = http.MultipartRequest('POST', uri);

    // Add JWT authorization header
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Add images if provided
    if (sideImage != null) {
      request.files.add(await http.MultipartFile.fromPath('side_image', sideImage.path));
    }
    if (backImage != null) {
      request.files.add(await http.MultipartFile.fromPath('back_image', backImage.path));
    }

    // Add optional images
    if (frontImage != null) {
      request.files.add(await http.MultipartFile.fromPath('front_image', frontImage.path));
    }
    if (rightImage != null) {
      request.files.add(await http.MultipartFile.fromPath('right_image', rightImage.path));
    }

    // Add required form fields
    request.fields['cow_id'] = cowId;
    request.fields['cow_name'] = cowName;
    request.fields['section'] = section;
    request.fields['breed'] = breed;

    // Add optional form fields
    if (calfMonths != null) {
      request.fields['calf_months'] = calfMonths.toString();
    }
    if (knownOBL != null) {
      request.fields['known_obl_cm'] = knownOBL.toString();
    }
    if (knownWH != null) {
      request.fields['known_wh_cm'] = knownWH.toString();
    }
    if (knownHG != null) {
      request.fields['known_hg_cm'] = knownHG.toString();
    }
    if (knownHL != null) {
      request.fields['known_hl_cm'] = knownHL.toString();
    }

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 202 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Prediction queuing failed (Code ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Network or server error: $e');
    }
  }

  // Poll the status of an enqueued task with automatic retries for transient socket errors
  Future<Map<String, dynamic>> getTaskStatus(String taskId) async {
    final baseUrl = await getBaseUrl();
    final token = await getValidToken();
    
    Object? lastError;
    for (int attempt = 0; attempt < 4; attempt++) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        };
        
        final response = await http.get(
          Uri.parse('$baseUrl/api/task-status/$taskId'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          
          // If task is completed, prepend the base URL to glb_url
          if (data['status'] == 'completed' && data['result'] != null) {
            final result = data['result'] as Map<String, dynamic>;
            if (result['glb_url'] != null && result['glb_url'].toString().startsWith('/')) {
              result['glb_url'] = '$baseUrl${result['glb_url']}';
            }
          }
          return data;
        }
        throw Exception('Failed to fetch task status (Code ${response.statusCode})');
      } catch (e) {
        lastError = e;
        if (attempt < 3) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }
    throw Exception('Task status check failed: $lastError');
  }

  // Fetch the latest estimation history from the backend
  Future<List<dynamic>> getHistory() async {
    final baseUrl = await getBaseUrl();
    final token = await getValidToken();
    
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/api/history'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        for (var item in list) {
          if (item['glb_url'] != null && item['glb_url'].toString().startsWith('/')) {
            item['glb_url'] = '$baseUrl${item['glb_url']}';
          }
        }
        return list;
      }
      throw Exception('Failed to fetch history (Code ${response.statusCode})');
    } catch (e) {
      throw Exception('History retrieval failed: $e');
    }
  }

  // Fetch validation demo cases from the backend
  Future<List<dynamic>> getValidationDemos() async {
    final baseUrl = await getBaseUrl();
    final token = await getValidToken();
    
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/api/validation_demos'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> cases = data['cases'] ?? [];
        return cases;
      }
      throw Exception('Failed to fetch validation cases (Code ${response.statusCode})');
    } catch (e) {
      throw Exception('Validation cases retrieval failed: $e');
    }
  }

  // Delete a cattle record from the database
  Future<bool> deleteCattle(String cowId) async {
    final baseUrl = await getBaseUrl();
    final token = await getValidToken();
    
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/delete'),
        headers: headers,
        body: json.encode({'cow_id': cowId}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Clear all database records
  Future<bool> clearDatabase() async {
    final baseUrl = await getBaseUrl();
    final token = await getValidToken();
    
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/clear'),
        headers: headers,
        body: json.encode({'cow_id': 'all'}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
