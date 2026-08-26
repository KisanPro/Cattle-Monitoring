import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;

  final TextEditingController _nameController = TextEditingController();
  String _selectedRole = "Worker"; // Dropdown default matching web dropdown
  final List<String> _roles = ["Worker", "Manager", "Owner", "Veterinarian", "Visitor"];

  String _mobileNumber = "";
  String _farmName = "";

  bool _sessionActive = false;
  bool _isCapturing = false;
  bool _isZipping = false;
  int _progress = 0;
  int _frameCount = 0;
  int _localFrameIndex = 1;

  XFile? _profileFile;

  Timer? _statusTimer;
  Timer? _frameTimer;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _loadFarmSettings();
    _initializeCamera();
  }

  Future<void> _loadFarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mobileNumber = prefs.getString("mobile_number") ?? "";
      _farmName = prefs.getString("farm_name") ?? "";
    });
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        CameraDescription frontCam = _cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );

        _cameraController = CameraController(
          frontCam,
          ResolutionPreset.low,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print("Camera initialization failed: $e");
    }
  }

  Future<void> _startEnrollmentSession() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Member Name is required!")),
      );
      return;
    }
    if (_mobileNumber.isEmpty || _farmName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please configure your farm settings first!")),
      );
      return;
    }

    // Check if the member name already exists on this specific farm
    final farmId = "farm_${_mobileNumber}_${_farmName.replaceAll(' ', '_')}";
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Checking for duplicate member name..."), 
          duration: Duration(milliseconds: 800),
        ),
      );

      final existingMembers = await ApiService.fetchRegisteredMembers(farmId);
      final normalizedNewName = name.toLowerCase().replaceAll(" ", "_");
      final alreadyExists = existingMembers.any(
        (m) => (m['raw_name'] as String).toLowerCase() == normalizedNewName
      );

      if (alreadyExists) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text("Name Already Exists", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            content: Text("A member named '$name' is already registered in your farm folder. Please use a unique name or delete the existing member first.", style: const TextStyle(color: Colors.black54)),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      print("Check duplicate error: $e");
    }

    try {
      final res = await ApiService.startScanSession(name, _selectedRole, _mobileNumber, _farmName);
      if (res['status'] == 'success') {
        setState(() {
          _sessionActive = true;
          _progress = 0;
          _frameCount = 0;
          _localFrameIndex = 1;
          _profileFile = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? "Failed to initialize session.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection error: $e")),
      );
    }
  }

  Future<void> _startCapturingLoop() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final success = await ApiService.setCapturingState(true);
      if (success) {
        setState(() {
          _isCapturing = true;
          _frameCount = 0;
          _progress = 0;
          _profileFile = null;
        });

        // 1. Take a single picture for the profile photo (Fast, only 1 file written to disk)
        try {
          _profileFile = await _cameraController!.takePicture();
        } catch (e) {
          print("Error taking profile snapshot: $e");
        }

        // 2. Start Hardware-Accelerated Video Recording
        await _cameraController!.startVideoRecording();

        // 3. Simulated progress timer (ticking every 33ms to match 30 FPS for 1000 frames over 33s)
        _frameTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) async {
          if (!_isCapturing || _cameraController == null) {
            timer.cancel();
            return;
          }
          setState(() {
            _frameCount++;
            _progress = ((_frameCount / 1000.0) * 100).clamp(0, 100).toInt();
          });

          if (_frameCount >= 1000) {
            timer.cancel();
            _stopCapturingLoop();
          }
        });
      }
    } catch (e) {
      print("Error starting video capture: $e");
    }
  }

  void _stopCapturingLoop() async {
    _frameTimer?.cancel();
    setState(() {
      _isCapturing = false;
    });
    await ApiService.setCapturingState(false);

    if (_cameraController != null && _cameraController!.value.isRecordingVideo) {
      try {
        final videoFile = await _cameraController!.stopVideoRecording();
        _uploadVideoDataset(videoFile);
      } catch (e) {
        print("Error stopping video: $e");
      }
    }
  }

  Future<void> _uploadVideoDataset(XFile videoFile) async {
    setState(() {
      _isZipping = true;
    });

    try {
      // 1. Read video bytes
      final videoBytes = await videoFile.readAsBytes();
      
      // 2. Read profile photo bytes (or fallback if empty)
      List<int> profileBytes;
      if (_profileFile != null) {
        profileBytes = await _profileFile!.readAsBytes();
      } else {
        profileBytes = videoBytes.sublist(0, 1024); // dummy fallback
      }

      // 3. Upload directly to S3
      final farmId = "farm_${_mobileNumber}_${_farmName.replaceAll(' ', '_')}";
      final name = _nameController.text.trim().replaceAll(" ", "_");

      final res = await ApiService.uploadS3Video(
        farmId: farmId,
        memberName: name,
        videoBytes: videoBytes,
        profileBytes: profileBytes,
      );

      if (res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enrollment completed successfully!")),
        );
        
        // Clean up temporary local files to free device storage
        try {
          await File(videoFile.path).delete();
          if (_profileFile != null) {
            await File(_profileFile!.path).delete();
          }
        } catch (_) {}

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: ${res['message']}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading dataset: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isZipping = false;
          _sessionActive = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _frameTimer?.cancel();
    _cameraController?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Member Monitoring",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isZipping
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF004D40)),
                  const SizedBox(height: 20),
                  const Text(
                    "Compiling & uploading 1,000 face dataset...\nThis will complete in 15 seconds.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE9ECEF)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Modal Header Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Add Farm Member",
                                  style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Register authorized farm members for AI access monitoring",
                                  style: TextStyle(color: Colors.black54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black45, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Form or Scan viewport based on session status
                      if (!_sessionActive) ...[
                        // Read-only farm identification badge
                        Card(
                          color: const Color(0xFFE0F2F1),
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.agriculture, color: Color(0xFF004D40), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Farm: $_farmName ($_mobileNumber)",
                                    style: const TextStyle(color: Color(0xFF004D40), fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // MEMBER NAME
                        const Text(
                          "MEMBER NAME",
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Enter member name (e.g. Geetha)",
                            hintStyle: const TextStyle(color: Colors.black26),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // MEMBER ROLE
                        const Text(
                          "MEMBER ROLE",
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE9ECEF)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedRole,
                              style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black45),
                              isExpanded: true,
                              items: _roles.map((String role) {
                                return DropdownMenuItem<String>(
                                  value: role,
                                  child: Text(role),
                                );
                              }).toList(),
                              onChanged: (String? value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedRole = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // REGISTER MEMBER BUTTON
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004D40),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _startEnrollmentSession,
                          child: const Text(
                            "Register Member",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ] else ...[
                        // ROTATE YOUR HEAD BANNER
                        const Center(
                          child: Text(
                            "ROTATE YOUR HEAD",
                            style: TextStyle(color: Color(0xFF005F54), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Camera Preview Container
                        Center(
                          child: Container(
                            width: double.infinity,
                            height: 280,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE9ECEF)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _isCameraInitialized && _cameraController != null
                                  ? AspectRatio(
                                      aspectRatio: _cameraController!.value.aspectRatio,
                                      child: CameraPreview(_cameraController!),
                                    )
                                  : const Center(child: CircularProgressIndicator(color: Color(0xFF004D40))),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Progress Row Info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Scanning progress",
                              style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              "$_progress% ($_frameCount/1000)",
                              style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Linear Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _progress / 100.0,
                            backgroundColor: const Color(0xFFF1F3F5),
                            color: const Color(0xFF005F54),
                            minHeight: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            "Slowly rotate your head to capture all angles",
                            style: TextStyle(color: Colors.black45, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Start/Stop Scan button (Single-Tap toggle)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isCapturing ? const Color(0xFFD32F2F) : const Color(0xFF004D40),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isCapturing ? _stopCapturingLoop : _startCapturingLoop,
                          child: Center(
                            child: Text(
                              _isCapturing ? "Stop Scanning" : "Start Scanning",
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              _stopCapturingLoop();
                              setState(() {
                                _sessionActive = false;
                              });
                            },
                            child: const Text("Reset Details", style: TextStyle(color: Colors.black38, fontSize: 12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
