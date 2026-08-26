import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/member_list_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const KisanFaceRegisterApp());
}

class KisanFaceRegisterApp extends StatelessWidget {
  const KisanFaceRegisterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kisan FaceRegister Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        primaryColor: const Color(0xFF004D40),
        fontFamily: 'Inter',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF004D40),
          primary: const Color(0xFF004D40),
          background: const Color(0xFFF8F9FA),
        ),
      ),
      home: const MainWrapper(),
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({Key? key}) : super(key: key);

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  final TextEditingController _awsKeyController = TextEditingController();
  final TextEditingController _awsSecretController = TextEditingController();
  final TextEditingController _awsBucketController = TextEditingController();
  final TextEditingController _awsRegionController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _farmController = TextEditingController();

  bool _isConfigured = false;
  final GlobalKey<MemberListScreenState> _memberListKey = GlobalKey<MemberListScreenState>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final awsKey = prefs.getString("aws_access_key_id") ?? "";
    final awsSecret = prefs.getString("aws_secret_access_key") ?? "";
    final awsBucket = prefs.getString("aws_s3_bucket") ?? "";
    final awsRegion = prefs.getString("aws_default_region") ?? "us-east-1";
    final mobile = prefs.getString("mobile_number") ?? "";
    final farm = prefs.getString("farm_name") ?? "";

    _awsKeyController.text = awsKey;
    _awsSecretController.text = awsSecret;
    _awsBucketController.text = awsBucket;
    _awsRegionController.text = awsRegion;
    _mobileController.text = mobile;
    _farmController.text = farm;

    if (mobile.isNotEmpty && farm.isNotEmpty && awsKey.isNotEmpty && awsSecret.isNotEmpty && awsBucket.isNotEmpty) {
      setState(() {
        _isConfigured = true;
      });
      await ApiService.initS3();
    } else {
      // Automatically trigger settings popup on first launch
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSettingsDialog(isFirstLaunch: true);
      });
    }
  }

  Future<void> _saveSettings() async {
    final awsKey = _awsKeyController.text.trim();
    final awsSecret = _awsSecretController.text.trim();
    final awsBucket = _awsBucketController.text.trim();
    final awsRegion = _awsRegionController.text.trim();
    final mobile = _mobileController.text.trim();
    final farm = _farmController.text.trim();

    if (awsKey.isEmpty || awsSecret.isEmpty || awsBucket.isEmpty || awsRegion.isEmpty || mobile.isEmpty || farm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required!")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("aws_access_key_id", awsKey);
    await prefs.setString("aws_secret_access_key", awsSecret);
    await prefs.setString("aws_s3_bucket", awsBucket);
    await prefs.setString("aws_default_region", awsRegion);
    await prefs.setString("mobile_number", mobile);
    await prefs.setString("farm_name", farm);

    await ApiService.initS3();

    if (mounted) {
      setState(() {
        _isConfigured = true;
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("AWS S3 settings saved successfully!")),
      );
      _memberListKey.currentState?.reloadSettings();
    }
  }

  void _showSettingsDialog({bool isFirstLaunch = false}) {
    showDialog(
      context: context,
      barrierDismissible: !isFirstLaunch, // Force first-time users to complete setup
      builder: (context) => WillPopScope(
        onWillPop: () async => !isFirstLaunch,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          title: Row(
            children: [
              const Icon(Icons.cloud_sync, color: Color(0xFF004D40)),
              const SizedBox(width: 8),
              Text(
                isFirstLaunch ? "AWS Cloud Setup" : "Cloud Settings", 
                style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Configure direct S3 cloud credentials for your farm. This app connects directly to your AWS S3 bucket to register and download member profiles.",
                  style: TextStyle(color: Colors.black54, fontSize: 11),
                ),
                const SizedBox(height: 16),
                
                // AWS Access Key ID
                TextField(
                  controller: _awsKeyController,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "AWS Access Key ID",
                    labelStyle: const TextStyle(color: Color(0xFF004D40), fontSize: 12),
                    hintText: "Enter AWS Access Key",
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // AWS Secret Access Key
                TextField(
                  controller: _awsSecretController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "AWS Secret Access Key",
                    labelStyle: const TextStyle(color: Color(0xFF004D40), fontSize: 12),
                    hintText: "Enter AWS Secret Key",
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // AWS S3 Bucket Name
                TextField(
                  controller: _awsBucketController,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "AWS S3 Bucket Name",
                    labelStyle: const TextStyle(color: Color(0xFF004D40), fontSize: 12),
                    hintText: "e.g. kisan-face-bucket",
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // AWS Region
                TextField(
                  controller: _awsRegionController,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "AWS Region",
                    labelStyle: const TextStyle(color: Color(0xFF004D40), fontSize: 12),
                    hintText: "e.g. us-east-1",
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // Farmer Mobile Number
                TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "Farmer Mobile Number",
                    labelStyle: const TextStyle(color: Color(0xFF004D40), fontSize: 12),
                    hintText: "e.g. 9876543210",
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // Farm Name
                TextField(
                  controller: _farmController,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "Farm Name",
                    labelStyle: const TextStyle(color: Color(0xFF004D40), fontSize: 12),
                    hintText: "e.g. Samruddhi_Farm",
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!isFirstLaunch)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.black38)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
              onPressed: _saveSettings,
              child: const Text("Save & Connect", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MemberListScreen(
      key: _memberListKey,
      onOpenSettings: () => _showSettingsDialog(isFirstLaunch: false),
    );
  }
}
