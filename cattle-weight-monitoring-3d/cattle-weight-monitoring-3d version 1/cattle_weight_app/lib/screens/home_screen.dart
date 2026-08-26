import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'result_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'alerts_screen.dart';
import 'validation_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  // Selected mode: '2' or '4' images
  String _uploadMode = '2'; 

  // Image files
  File? _sideImage;
  File? _backImage;
  File? _frontImage;
  File? _rightImage;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cowIdController = TextEditingController();
  final TextEditingController _cowNameController = TextEditingController();
  final TextEditingController _calfMonthsController = TextEditingController();
  final TextEditingController _customBreedController = TextEditingController();

  // Advanced overrides controllers
  final TextEditingController _oblController = TextEditingController();
  final TextEditingController _whController = TextEditingController();
  final TextEditingController _hgController = TextEditingController();
  final TextEditingController _hlController = TextEditingController();

  // Selected values
  String _selectedSection = 'Dairy Cattle';
  String _selectedBreed = 'Gir';
  bool _isImperial = false; // false = metric (cm/kg), true = imperial (inches/lbs)
  bool _isAdvancedExpanded = false;
  
  List<Map<String, dynamic>> _historyList = [];
  int _alertCount = 0;

  // Connection status
  bool _isServerConnected = false;
  String _serverStatusMessage = 'Checking connection...';
  String? _username;

  final List<String> _sections = ['Dairy Cattle', 'Beef Cattle', 'Calf', 'Buffalo / Draft'];
  final List<String> _breeds = ['Gir', 'HF', 'Jersey', 'Sahiwal', 'Ongole', 'HalliKar', 'Deoni', 'Bargur', 'Kankrej', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _checkServerStatus();
    _loadHistoryAndAlerts();
  }

  Future<void> _loadUsername() async {
    final username = await _apiService.getUsername();
    setState(() {
      _username = username;
    });
  }


  Future<void> _checkServerStatus() async {
    final status = await _apiService.checkStatus();
    setState(() {
      _isServerConnected = status['ready'] ?? false;
      _serverStatusMessage = _isServerConnected ? 'Server connected' : 'Server disconnected';
    });
  }

  Future<void> _loadHistoryAndAlerts() async {
    try {
      final list = await _apiService.getHistory();
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var r in list) {
        final cowId = r['cow_id'] ?? '';
        if (cowId.isNotEmpty) {
          grouped.putIfAbsent(cowId, () => []).add(r);
        }
      }

      int count = 0;
      grouped.forEach((cowId, cowList) {
        cowList.sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));
        final int n = cowList.length;
        if (n >= 3) {
          int decCount = 1;
          for (int i = n - 1; i > 0; i--) {
            final double curr = (cowList[i]['weight_kg'] as num).toDouble();
            final double prev = (cowList[i - 1]['weight_kg'] as num).toDouble();
            if (curr < prev) {
              decCount++;
            } else {
              break;
            }
          }

          int incCount = 1;
          for (int i = n - 1; i > 0; i--) {
            final double curr = (cowList[i]['weight_kg'] as num).toDouble();
            final double prev = (cowList[i - 1]['weight_kg'] as num).toDouble();
            if (curr > prev) {
              incCount++;
            } else {
              break;
            }
          }

          if (decCount >= 3) {
            final double wOld = (cowList[n - decCount]['weight_kg'] as num).toDouble();
            final double wNew = (cowList[n - 1]['weight_kg'] as num).toDouble();
            final double diff = wOld - wNew;
            final double pct = wOld > 0 ? (diff / wOld) * 100 : 0.0;
            if (pct >= 8.0) count++;
          } else if (incCount >= 3) {
            final double wOld = (cowList[n - incCount]['weight_kg'] as num).toDouble();
            final double wNew = (cowList[n - 1]['weight_kg'] as num).toDouble();
            final double diff = wNew - wOld;
            final double pct = wOld > 0 ? (diff / wOld) * 100 : 0.0;
            if (pct >= 10.0) count++;
          }
        }
      });

      setState(() {
        _historyList = list.map((item) => Map<String, dynamic>.from(item)).toList();
        _alertCount = count + 2; // +2 for mock test alerts
      });
    } catch (e) {
      // Fail silently for background loading
    }
  }

  Future<void> _pickImage(String position, ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          if (position == 'side') _sideImage = File(pickedFile.path);
          if (position == 'back') _backImage = File(pickedFile.path);
          if (position == 'front') _frontImage = File(pickedFile.path);
          if (position == 'right') _rightImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  void _showImagePickerOptions(String position) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7E8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF006D60)),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(position, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF006D60)),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(position, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsDialog() async {
    final currentUrl = await _apiService.getBaseUrl();
    final controller = TextEditingController(text: currentUrl);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAF7E8),
          title: const Text('Server Configuration', style: TextStyle(color: Color(0xFF006D60), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the Flask backend base URL:',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://192.168.x.x:5000',
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF006D60), width: 2),
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006D60),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await _apiService.setBaseUrl(controller.text);
                Navigator.pop(context);
                _checkServerStatus();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _submitForm() async {
    // 1. Validation
    if (!_formKey.currentState!.validate()) return;
    
    if (_sideImage == null || _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both Side and Back images.')),
      );
      return;
    }

    if (_uploadMode == '4' && (_frontImage == null || _rightImage == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all 4 required images.')),
      );
      return;
    }

    // 2. Show beautiful processing overlay with StateSetter
    String statusMessage = 'Submitting images to server...';
    String queuePositionText = '';
    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: const Color(0xFFFAF7E8),
            content: StatefulBuilder(
              builder: (context, setState) {
                dialogSetState = setState;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF006D60)),
                    const SizedBox(height: 20),
                    Text(
                      statusMessage,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                      textAlign: TextAlign.center,
                    ),
                    if (queuePositionText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        queuePositionText,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Running background AI models. Multiple farmers can queue requests safely.',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    // 3. Prepare metric conversions for backend
    double? calfMonths = _selectedSection == 'Calf' ? double.tryParse(_calfMonthsController.text) : null;
    double? obl = double.tryParse(_oblController.text);
    double? wh = double.tryParse(_whController.text);
    double? hg = double.tryParse(_hgController.text);
    double? hl = double.tryParse(_hlController.text);

    // If unit is imperial, convert inches to cm before sending to backend
    double conversion = 2.54;
    if (_isImperial) {
      if (obl != null) obl = obl * conversion;
      if (wh != null) wh = wh * conversion;
      if (hg != null) hg = hg * conversion;
      if (hl != null) hl = hl * conversion;
    }

    try {
      String breedToSend = _selectedBreed;
      if (_selectedBreed == 'Other') {
        final customBreed = _customBreedController.text.trim();
        if (customBreed.isNotEmpty) {
          breedToSend = 'Other: $customBreed';
        }
      }

      // Step A: Enqueue the task
      final enqueueResult = await _apiService.predictCattleWeight(
        sideImage: _sideImage!,
        backImage: _backImage!,
        frontImage: _uploadMode == '4' ? _frontImage : null,
        rightImage: _uploadMode == '4' ? _rightImage : null,
        cowId: _cowIdController.text.trim(),
        cowName: _cowNameController.text.trim(),
        section: _selectedSection,
        breed: breedToSend,
        calfMonths: calfMonths,
        knownOBL: obl,
        knownWH: wh,
        knownHG: hg,
        knownHL: hl,
      );

      final taskId = enqueueResult['task_id'];
      if (taskId == null) {
        throw Exception('Failed to get task ID from server.');
      }

      // Step B: Poll task status
      Map<String, dynamic>? finalResult;
      bool isFinished = false;

      while (!isFinished) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        final statusInfo = await _apiService.getTaskStatus(taskId);
        final status = statusInfo['status'];
        final position = statusInfo['position'] ?? 0;

        if (status == 'completed') {
          finalResult = statusInfo['result'];
          isFinished = true;
        } else if (status == 'failed') {
          throw Exception(statusInfo['error'] ?? 'Task execution failed on server.');
        } else {
          // Update dialog state
          if (dialogSetState != null) {
            dialogSetState!(() {
              if (status == 'queued') {
                statusMessage = 'Waiting in queue...';
                queuePositionText = 'Your Position: $position';
              } else if (status == 'processing') {
                statusMessage = 'Generating 3D Model & Weight...';
                queuePositionText = 'Running AI models';
              } else {
                statusMessage = 'Status: $status';
                queuePositionText = '';
              }
            });
          }
        }
      }

      // Close processing overlay
      if (!mounted) return;
      Navigator.pop(context);

      // Route to ResultScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            result: finalResult!,
            isImperial: _isImperial,
            sideImage: _sideImage,
            backImage: _backImage,
          ),
        ),
      ).then((_) => _loadHistoryAndAlerts());
    } catch (e) {
      // Close processing overlay
      if (mounted) {
        Navigator.pop(context);
      }

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFAF7E8),
            title: const Text('Estimation Failed', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: Text(e.toString().replaceAll('Exception:', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Color(0xFF006D60))),
              )
            ],
          );
        },
      );
    }
  }

  void _submitManualForm() async {
    // 1. Validation
    if (_cowIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Cattle ID.')),
      );
      return;
    }

    final oblText = _oblController.text.trim();
    final whText = _whController.text.trim();
    final hgText = _hgController.text.trim();
    final hlText = _hlController.text.trim();

    if (oblText.isEmpty || whText.isEmpty || hgText.isEmpty || hlText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all four physical measurements (Body Length, Withers Height, Heart Girth, and Hip Length) for manual estimation.')),
      );
      return;
    }

    double? obl = double.tryParse(oblText);
    double? wh = double.tryParse(whText);
    double? hg = double.tryParse(hgText);
    double? hl = double.tryParse(hlText);

    if (obl == null || wh == null || hg == null || hl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid numeric values entered in measurements.')),
      );
      return;
    }

    // 2. Show beautiful processing overlay
    String statusMessage = 'Calculating weight...';
    String queuePositionText = '';
    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: const Color(0xFFFAF7E8),
            content: StatefulBuilder(
              builder: (context, setState) {
                dialogSetState = setState;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF006D60)),
                    const SizedBox(height: 20),
                    Text(
                      statusMessage,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                      textAlign: TextAlign.center,
                    ),
                    if (queuePositionText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        queuePositionText,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Running background AI models. Multiple farmers can queue requests safely.',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    // 3. Prepare metric conversions for backend
    double? calfMonths = _selectedSection == 'Calf' ? double.tryParse(_calfMonthsController.text) : null;

    double conversion = 2.54;
    if (_isImperial) {
      obl = obl * conversion;
      wh = wh * conversion;
      hg = hg * conversion;
      hl = hl * conversion;
    }

    try {
      String breedToSend = _selectedBreed;
      if (_selectedBreed == 'Other') {
        final customBreed = _customBreedController.text.trim();
        if (customBreed.isNotEmpty) {
          breedToSend = 'Other: $customBreed';
        }
      }

      // Step A: Enqueue the task
      final enqueueResult = await _apiService.predictCattleWeight(
        sideImage: null,
        backImage: null,
        frontImage: null,
        rightImage: null,
        cowId: _cowIdController.text.trim(),
        cowName: _cowNameController.text.trim(),
        section: _selectedSection,
        breed: breedToSend,
        calfMonths: calfMonths,
        knownOBL: obl,
        knownWH: wh,
        knownHG: hg,
        knownHL: hl,
      );

      final taskId = enqueueResult['task_id'];
      if (taskId == null) {
        throw Exception('Failed to get task ID from server.');
      }

      // Step B: Poll task status
      Map<String, dynamic>? finalResult;
      bool isFinished = false;

      while (!isFinished) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        final statusInfo = await _apiService.getTaskStatus(taskId);
        final status = statusInfo['status'];
        final position = statusInfo['position'] ?? 0;

        if (status == 'completed') {
          finalResult = statusInfo['result'];
          isFinished = true;
        } else if (status == 'failed') {
          throw Exception(statusInfo['error'] ?? 'Task execution failed on server.');
        } else {
          if (dialogSetState != null) {
            dialogSetState!(() {
              if (status == 'queued') {
                statusMessage = 'Waiting in queue...';
                queuePositionText = 'Your Position: $position';
              } else if (status == 'processing') {
                statusMessage = 'Calculating weight...';
                queuePositionText = 'Running AI models';
              } else {
                statusMessage = 'Status: $status';
                queuePositionText = '';
              }
            });
          }
        }
      }

      // Close processing overlay
      if (!mounted) return;
      Navigator.pop(context);

      // Route to ResultScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            result: finalResult!,
            isImperial: _isImperial,
            sideImage: null,
            backImage: null,
          ),
        ),
      ).then((_) => _loadHistoryAndAlerts());
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFAF7E8),
            title: const Text('Estimation Failed', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: Text(e.toString().replaceAll('Exception:', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Color(0xFF006D60))),
              )
            ],
          );
        },
      );
    }
  }

  void _clearImage(String position) {
    setState(() {
      if (position == 'side') _sideImage = null;
      if (position == 'back') _backImage = null;
      if (position == 'front') _frontImage = null;
      if (position == 'right') _rightImage = null;
    });
  }

  Widget _buildImageSelector({
    required String title,
    required File? imageFile,
    required String position,
  }) {
    return Expanded(
      child: Container(
        height: 120,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEBEAD8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: imageFile != null ? const Color(0xFF006D60) : Colors.black12,
            width: imageFile != null ? 2 : 1,
          ),
        ),
        child: imageFile != null
            ? Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => _showImagePickerOptions(position),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(imageFile, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _clearImage(position),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : GestureDetector(
                onTap: () => _showImagePickerOptions(position),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/guide_${position == "side" ? "left" : position}.png',
                          fit: BoxFit.cover,
                          color: Colors.white.withOpacity(0.35),
                          colorBlendMode: BlendMode.modulate,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo, color: Color(0xFF006D60), size: 28),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006D60),
                              shadows: [
                                Shadow(
                                  blurRadius: 4.0,
                                  color: Colors.white70,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006D60),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kisan Pro Cattle Weight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (_username != null)
              Text('Farmer: $_username', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AlertsScreen(historyList: _historyList)),
                  );
                },
              ),
              if (_alertCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_alertCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.verified_outlined),
            tooltip: 'Validation',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ValidationScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              ).then((_) => _loadHistoryAndAlerts()); // reload alerts when returning from history
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _apiService.logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Server Status Badge ──
              GestureDetector(
                onTap: _checkServerStatus,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isServerConnected ? const Color(0xFFE2F0D9) : const Color(0xFFFCE4D6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 6,
                        backgroundColor: _isServerConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _serverStatusMessage,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isServerConnected ? Colors.green[800] : Colors.red[800],
                          ),
                        ),
                      ),
                      const Icon(Icons.refresh, size: 16, color: Colors.black38),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── CARD 1: Identify Cattle ──
              Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Identify Cattle',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _cowNameController,
                        decoration: const InputDecoration(
                          labelText: 'Cattle Name (Optional)',
                          hintText: 'e.g. Lakshmi (Letters only)',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF006D60), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _cowIdController,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'Cattle ID (Required) *',
                          hintText: 'e.g. KP204 (Alphanumeric only)',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF006D60), width: 2)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Cattle ID is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedSection,
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          border: OutlineInputBorder(),
                        ),
                        items: _sections.map((sec) => DropdownMenuItem(value: sec, child: Text(sec))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSection = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedBreed,
                        decoration: const InputDecoration(
                          labelText: 'Breed *',
                          border: OutlineInputBorder(),
                        ),
                        items: _breeds.map((br) => DropdownMenuItem(value: br, child: Text(br))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedBreed = val);
                        },
                      ),

                      if (_selectedBreed == 'Other') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _customBreedController,
                          decoration: const InputDecoration(
                            labelText: 'Requested Breed Name *',
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF006D60), width: 2)),
                          ),
                          validator: (value) {
                            if (_selectedBreed == 'Other') {
                              if (value == null || value.trim().isEmpty) {
                                  return 'Please specify the breed name';
                              }
                            }
                            return null;
                          },
                        ),
                      ],

                      if (_selectedSection == 'Calf') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _calfMonthsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Calf Age (1-12 months) *',
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF006D60), width: 2)),
                          ),
                          validator: (value) {
                            if (_selectedSection == 'Calf') {
                              if (value == null || value.trim().isEmpty) {
                                return 'Calf Age is required';
                              }
                              final age = int.tryParse(value);
                              if (age == null || age < 1 || age > 12) {
                                return 'Calf Age must be between 1 and 12';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── CARD 2: Advanced Calibration (Optional) ──
              Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  initiallyExpanded: _isAdvancedExpanded,
                  iconColor: const Color(0xFF006D60),
                  collapsedIconColor: const Color(0xFF006D60),
                  title: const Text(
                    'Advanced Calibration (Optional)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                  ),
                  onExpansionChanged: (val) => setState(() => _isAdvancedExpanded = val),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2x2 Grid of Fields with light brown/tan background
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7E8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _oblController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Body Len (${_isImperial ? "in" : "cm"})',
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: const Color(0xFFEBEAD8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _whController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Withers Ht (${_isImperial ? "in" : "cm"})',
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: const Color(0xFFEBEAD8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _hgController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Heart Girth (${_isImperial ? "in" : "cm"})',
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: const Color(0xFFEBEAD8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _hlController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Hip Length (${_isImperial ? "in" : "cm"})',
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: const Color(0xFFEBEAD8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006D60),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              onPressed: _submitManualForm,
                              icon: const Icon(Icons.calculate_outlined),
                              label: const Text(
                                'CALCULATE WEIGHT FROM MEASUREMENTS',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Manual Measurement Reference Guide
                          const Divider(),
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(Icons.edit_note, color: Color(0xFF006D60)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Manual Measurement Reference Guide',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/measurement_guide.png',
                                height: 200,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'How to Measure:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF006D60)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '•  1. Body Length (OBL): Measure diagonally along the side of the cow from the point of the shoulder to the pin bone.\n'
                            '•  2. Withers Height (WH): Measure vertically from the ground to the highest point of the shoulder (withers).\n'
                            '•  3. Heart Girth (HG): Measure the chest circumference directly behind the front legs.\n'
                            '•  4. Hip Length (HL): Measure horizontally along the hip from the hook bone to the pin bone.',
                            style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── CARD 3: Upload Cattle Images ──
              Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upload Cattle Images',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text('2-Image Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              selected: _uploadMode == '2',
                              selectedColor: const Color(0xFF006D60),
                              labelStyle: TextStyle(color: _uploadMode == '2' ? Colors.white : const Color(0xFF006D60)),
                              backgroundColor: const Color(0xFFEBEAD8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              onSelected: (val) {
                                if (val) setState(() => _uploadMode = '2');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text('4-Image Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              selected: _uploadMode == '4',
                              selectedColor: const Color(0xFF006D60),
                              labelStyle: TextStyle(color: _uploadMode == '4' ? Colors.white : const Color(0xFF006D60)),
                              backgroundColor: const Color(0xFFEBEAD8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              onSelected: (val) {
                                if (val) setState(() => _uploadMode = '4');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          _buildImageSelector(title: 'Left Image *', imageFile: _sideImage, position: 'side'),
                          _buildImageSelector(title: 'Back Image *', imageFile: _backImage, position: 'back'),
                        ],
                      ),
                      if (_uploadMode == '4') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildImageSelector(title: 'Front Image *', imageFile: _frontImage, position: 'front'),
                            _buildImageSelector(title: 'Right Image *', imageFile: _rightImage, position: 'right'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),



              // ── Submit Button ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006D60),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _submitForm,
                  child: const Text(
                    'ESTIMATE WEIGHT & 3D MODEL',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
