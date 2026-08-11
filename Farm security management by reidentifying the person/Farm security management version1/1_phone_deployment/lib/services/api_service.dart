import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:minio/minio.dart';

class ApiService {
  static Minio? _minio;
  static String? _bucket;
  
  // Updates settings placeholder (kept for compatibility)
  static void setServerIp(String ip) {}

  // Initializes the direct AWS S3 client using saved credentials
  static Future<void> initS3() async {
    if (_minio != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessKey = prefs.getString("aws_access_key_id") ?? "";
      final secretKey = prefs.getString("aws_secret_access_key") ?? "";
      _bucket = prefs.getString("aws_s3_bucket") ?? "";
      final region = prefs.getString("aws_default_region") ?? "us-east-1";

      if (accessKey.isNotEmpty && secretKey.isNotEmpty && _bucket!.isNotEmpty) {
        _minio = Minio(
          endPoint: 's3.amazonaws.com',
          accessKey: accessKey,
          secretKey: secretKey,
          region: region,
        );
        print("[S3 Client] Initialized successfully for bucket $_bucket");
      } else {
        _minio = null;
        print("[S3 Client] S3 Credentials not fully configured in settings.");
      }
    } catch (e) {
      print("[S3 Client] Initialization error: $e");
    }
  }

  // Fetch Registered Members for a specific farm directly from AWS S3
  static Future<List<Map<String, dynamic>>> fetchRegisteredMembers(String farmId) async {
    await initS3();
    if (_minio == null || _bucket == null) return [];
    
    try {
      final s3Key = "embeddings/$farmId/member_roles.json";
      final stream = await _minio!.getObject(_bucket!, s3Key);
      
      final bytesList = await stream.toList();
      final bytes = bytesList.expand((b) => b).toList();
      final content = utf8.decode(bytes);
      
      final Map<String, dynamic> rolesMap = json.decode(content);
      
      List<Map<String, dynamic>> members = [];
      for (final name in rolesMap.keys) {
        final role = rolesMap[name];
        final profileUrl = await getMemberProfileUrl(farmId, name);
        members.add({
          "name": name.replaceAll("_", " "),
          "raw_name": name,
          "role": role,
          "status": "Authorized",
          "profile_url": profileUrl
        });
      }
      return members;
    } catch (e) {
      print("No roles file found on S3 for this farm yet: $e");
    }
    return [];
  }

  // Generate a temporary pre-signed S3 URL for a member's profile image
  static Future<String> getMemberProfileUrl(String farmId, String memberName) async {
    await initS3();
    if (_minio == null || _bucket == null) return "";
    try {
      final s3Key = "dataset/$farmId/${memberName.replaceAll(' ', '_')}/profile.jpg";
      return await _minio!.presignedGetObject(_bucket!, s3Key, expires: 86400); // 24 hours expiration
    } catch (e) {
      print("Error getting presigned profile URL: $e");
    }
    return "";
  }

  // Upload Dataset Video and Profile photo directly to AWS S3 in one transaction
  static Future<Map<String, dynamic>> uploadS3Video({
    required String farmId,
    required String memberName,
    required List<int> videoBytes,
    required List<int> profileBytes,
  }) async {
    await initS3();
    if (_minio == null || _bucket == null) {
      return {"status": "error", "message": "AWS S3 Client is not initialized."};
    }
    try {
      final sanitizedName = memberName.trim().replaceAll(" ", "_");
      
      // 1. Upload profile image
      final profileKey = "dataset/$farmId/$sanitizedName/profile.jpg";
      await _minio!.putObject(
        _bucket!,
        profileKey,
        Stream.value(Uint8List.fromList(profileBytes)),
        size: profileBytes.length,
        metadata: {"content-type": "image/jpeg"}
      );
      
      // 2. Upload dataset video file
      final videoKey = "dataset/$farmId/$sanitizedName/video.mp4";
      await _minio!.putObject(
        _bucket!,
        videoKey,
        Stream.value(Uint8List.fromList(videoBytes)),
        size: videoBytes.length,
        metadata: {"content-type": "video/mp4"}
      );
      
      return {"status": "success"};
    } catch (e) {
      print("AWS S3 Video upload error: $e");
      return {"status": "error", "message": "Failed to upload video to S3: $e"};
    }
  }

  // Delete Member from S3 roles list
  static Future<bool> deleteMember(String rawName, String farmId) async {
    await initS3();
    if (_minio == null || _bucket == null) return false;

    try {
      final s3Key = "embeddings/$farmId/member_roles.json";
      Map<String, dynamic> rolesMap = {};
      
      try {
        final stream = await _minio!.getObject(_bucket!, s3Key);
        final bytesList = await stream.toList();
        final bytes = bytesList.expand((b) => b).toList();
        rolesMap = json.decode(utf8.decode(bytes));
      } catch (_) {}

      final sanitizedName = rawName.trim().replaceAll(" ", "_");
      if (rolesMap.containsKey(sanitizedName)) {
        rolesMap.remove(sanitizedName);
        final content = json.encode(rolesMap);
        final bytes = utf8.encode(content);
        
        await _minio!.putObject(
          _bucket!,
          s3Key,
          Stream.value(Uint8List.fromList(bytes)),
          size: bytes.length,
          metadata: {"content-type": "application/json"}
        );
        print("[S3 Client] Successfully deleted member $sanitizedName from roles.");
        return true;
      }
    } catch (e) {
      print("Error deleting member from S3: $e");
    }
    return false;
  }

  // Start Scan Session (Registers the new member name inside S3 roles list immediately)
  static Future<Map<String, dynamic>> startScanSession(
      String name, String role, String mobileNumber, String farmName) async {
    await initS3();
    if (_minio == null || _bucket == null) {
      return {"status": "error", "message": "AWS S3 Credentials are not configured!"};
    }
    
    final farmId = "farm_${mobileNumber}_${farmName.replaceAll(' ', '_')}";
    final s3Key = "embeddings/$farmId/member_roles.json";
    
    try {
      Map<String, dynamic> rolesMap = {};
      try {
        final stream = await _minio!.getObject(_bucket!, s3Key);
        final bytesList = await stream.toList();
        final bytes = bytesList.expand((b) => b).toList();
        rolesMap = json.decode(utf8.decode(bytes));
      } catch (_) {}

      rolesMap[name.trim().replaceAll(" ", "_")] = role;
      final content = json.encode(rolesMap);
      final bytes = utf8.encode(content);
      
      await _minio!.putObject(
        _bucket!,
        s3Key,
        Stream.value(Uint8List.fromList(bytes)),
        size: bytes.length,
        metadata: {"content-type": "application/json"}
      );
      
      return {"status": "success", "message": "Ready to upload frames to S3."};
    } catch (e) {
      return {"status": "error", "message": "Failed to configure member roles in S3: $e"};
    }
  }

  // Upload Frame directly into AWS S3
  static Future<Map<String, dynamic>> uploadS3Frame({
    required String farmId,
    required String memberName,
    required int frameIndex,
    required List<int> imageBytes,
  }) async {
    await initS3();
    if (_minio == null || _bucket == null) {
      return {"status": "error", "message": "AWS S3 Client is not initialized."};
    }
    try {
      final s3Key = "dataset/$farmId/$memberName/frame_$frameIndex.jpg";
      await _minio!.putObject(
        _bucket!,
        s3Key,
        Stream.value(Uint8List.fromList(imageBytes)),
        size: imageBytes.length,
        metadata: {"content-type": "image/jpeg"}
      );
      return {"status": "success", "count": frameIndex};
    } catch (e) {
      print("AWS S3 Direct Upload error: $e");
      return {"status": "error", "message": "Failed to upload to S3: $e"};
    }
  }

  // Set Capturing State (No-op in pure cloud S3 mode)
  static Future<bool> setCapturingState(bool capturing) async {
    return true;
  }

  // Fetch Scan Session Status (No-op in pure cloud S3 mode)
  static Future<Map<String, dynamic>> fetchScanStatus() async {
    return {};
  }

  // Registers a Jetson device (No-op in pure cloud S3 mode)
  static Future<Map<String, dynamic>> registerJetson({
    required String mobileNumber,
    required String farmName,
    required String jetsonIp,
    required String jetsonPort,
  }) async {
    return {"status": "success", "message": "Jetson registered."};
  }
}
