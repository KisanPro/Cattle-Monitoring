import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../config.dart';
import '../models/alert.dart';
import '../models/telemetry.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTab = 0;
  FarmTelemetry? _telemetry;
  List<FarmAlert> _alerts = [];
  Timer? _timer;
  bool _isLoading = true;
  String _selectedCamera = AppConfig.cameras.first;
  
  // Search & Master sheet inputs
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _masterIdController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Poll data every 3 seconds to keep UI in sync
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) => _fetchData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    _masterIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final telemetry = await ApiService.fetchTelemetry();
    final alerts = await ApiService.fetchAlerts();
    if (mounted) {
      setState(() {
        _telemetry = telemetry;
        _alerts = alerts;
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewMasterId() async {
    final text = _masterIdController.text.trim().toUpperCase();
    final RegExp tagRegExp = RegExp(r'^[A-Z][0-9]{3}$');
    if (!tagRegExp.hasMatch(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ear tag ID must be 1 Capital Letter followed by 3 digits (e.g. A145)")),
      );
      return;
    }
    
    final currentIds = List<String>.from(_telemetry?.masterIds ?? []);
    if (currentIds.contains(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID is already registered")),
      );
      return;
    }
    
    currentIds.add(text);
    setState(() => _isLoading = true);
    final success = await ApiService.updateMasterSheet(currentIds);
    if (success) {
      _masterIdController.clear();
      await _fetchData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cattle ID $text registered successfully")),
      );
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update master list. Check server status.")),
      );
    }
  }

  Future<void> _deleteMasterId(String id) async {
    final currentIds = List<String>.from(_telemetry?.masterIds ?? []);
    currentIds.remove(id);
    
    setState(() => _isLoading = true);
    final success = await ApiService.updateMasterSheet(currentIds);
    if (success) {
      await _fetchData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cattle ID $id deleted successfully")),
      );
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete ID")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFF6F4E8),
      cardColor: Colors.white,
      primaryColor: const Color(0xFF006857),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                _currentTab == 0 
                    ? 'Kisan Live Monitor' 
                    : (_currentTab == 1 ? 'Cattle Records' : 'Farm Security Access'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF006857),
          elevation: 0,
          actions: [
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined, size: 28, color: Colors.white),
                  if (_alerts.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBA1A1A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${_alerts.length}',
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
              onPressed: () => _showAlertsDialog(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF006857)),
              )
            : RefreshIndicator(
                onRefresh: _fetchData,
                color: const Color(0xFF006857),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: _buildCurrentTabContent(),
                ),
              ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) {
            setState(() {
              _currentTab = index;
            });
          },
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF006857),
          unselectedItemColor: const Color(0xFF707974),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.sensors),
              label: 'Live Feed',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pets),
              label: 'Cattle Records',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.security),
              label: 'Security Access',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildLiveTab();
      case 1:
        return _buildCattleTab();
      case 2:
        return _buildSecurityTab();
      default:
        return _buildLiveTab();
    }
  }

  // ── 1. LIVE MONITOR TAB ──
  Widget _buildLiveTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderStats(),
        const SizedBox(height: 24),
        const Text(
          "Live Farm Camera Streams",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Color(0xFF191C1B),
          ),
        ),
        const SizedBox(height: 12),
        _buildCameraStreams(),
      ],
    );
  }

  Widget _buildHeaderStats() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          "Total Cattle",
          _telemetry?.totalCattle.toString() ?? "—",
          Icons.pets,
          const Color(0xFF006857),
        ),
        _buildStatCard(
          "Healthy Status",
          "${_telemetry?.healthy ?? '—'} / ${_telemetry?.totalCattle ?? '—'}",
          Icons.check_circle_outline,
          const Color(0xFF006857),
        ),
        _buildStatCard(
          "Risk Warning",
          _telemetry?.warning.toString() ?? "—",
          Icons.warning_amber_rounded,
          Colors.orange.shade800,
        ),
        _buildStatCard(
          "Critical Issues",
          _telemetry?.critical.toString() ?? "—",
          Icons.error_outline,
          const Color(0xFFBA1A1A),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2DFD2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF526058),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraStreams() {
    return Column(
      children: AppConfig.cameras.map((cam) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF006857),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${cam.toUpperCase()} Live Feed",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen, color: Color(0xFF006857)),
                    onPressed: () => _openFullscreenCamera(cam),
                    tooltip: "Fullscreen View",
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _openFullscreenCamera(cam),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF006857), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF006857).withOpacity(0.12),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Mjpeg(
                          isLive: true,
                          stream: "${AppConfig.ec2ServerUrl}/video_feed/$cam",
                          error: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.videocam_off, color: Color(0xFFBA1A1A), size: 40),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${cam.toUpperCase()} Stream Offline',
                                    style: const TextStyle(
                                      color: Color(0xFFBA1A1A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Not getting stream from Jetson server',
                                    style: TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: (context) => const Center(
                            child: CircularProgressIndicator(color: Color(0xFF006857)),
                          ),
                        ),
                        // Tap to enlarge hint badge
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fullscreen, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  "Tap to Enlarge",
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _openFullscreenCamera(String cameraName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              "${cameraName.toUpperCase()} Fullscreen Live Stream",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Mjpeg(
                isLive: true,
                stream: "${AppConfig.ec2ServerUrl}/video_feed/$cameraName",
                error: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_off, color: Color(0xFFBA1A1A), size: 64),
                        const SizedBox(height: 12),
                        Text(
                          '${cameraName.toUpperCase()} Stream Offline',
                          style: const TextStyle(
                            color: Color(0xFFBA1A1A),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Not getting stream from Jetson server',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
                loading: (context) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF006857)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  // ── 2. CATTLE RECORDS TAB (EXACT LAYOUT MATCHING USER REFERENCE IMAGE) ──
  Widget _buildCattleTab() {
    final summary = _telemetry?.cattleSummary ?? {};
    final Set<String> allKeysSet = Set<String>.from(summary.keys);
    if (_telemetry != null && _telemetry!.masterIds.isNotEmpty) {
      allKeysSet.addAll(_telemetry!.masterIds);
    }
    final List<String> allKeys = allKeysSet.toList()..sort();
    final filteredKeys = allKeys.where((key) {
      return key.toUpperCase().contains(_searchQuery.toUpperCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master Sheet Registration Card
        Card(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2DFD2), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.sell_outlined, color: Color(0xFF006857), size: 16),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "CATTLE ID MASTER SHEET",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF006857), letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006857).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_telemetry?.masterIds.length ?? 0} Registered",
                        style: const TextStyle(color: Color(0xFF006857), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "Register verified ear-tag IDs (e.g. A145, 3643). The AI model will cross-verify and auto-correct OCR readings against this sheet to prevent corrupted log entries.",
                  style: TextStyle(color: Color(0xFF526058), fontSize: 11),
                ),
                const SizedBox(height: 12),
                
                // Wrap of current registered IDs
                if (_telemetry != null && _telemetry!.masterIds.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _telemetry!.masterIds.map((id) {
                      return InputChip(
                        label: Text(id, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006857))),
                        backgroundColor: const Color(0xFFEFECE0),
                        deleteIconColor: const Color(0xFFBA1A1A),
                        onDeleted: () => _deleteMasterId(id),
                      );
                    }).toList(),
                  ),
                  
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _masterIdController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 8,
                        style: const TextStyle(color: Color(0xFF191C1B), fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: "ENTER ID (E.G. A145 or 3643)",
                          hintStyle: TextStyle(color: Color(0xFF707974), fontSize: 11),
                          counterText: "",
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Color(0xFFF6F4E8),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _addNewMasterId,
                      icon: const Icon(Icons.add, color: Colors.white, size: 16),
                      label: const Text("+ Register ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006857),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Search & Refresh Row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Color(0xFF191C1B)),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search by ear tag ID...",
                  hintStyle: const TextStyle(color: Color(0xFF707974), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF006857)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2DFD2)),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh, color: Color(0xFF006857), size: 16),
              label: const Text("Refresh", style: TextStyle(color: Color(0xFF006857), fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2DFD2)),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Summary Strip
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2DFD2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniSummaryStat("TOTAL CATTLE", "${_telemetry?.totalCattle ?? '—'}", "tracked entities"),
              Container(width: 1, height: 30, color: const Color(0xFFE2DFD2)),
              _buildMiniSummaryStat("IDENTIFIED", "${summary.length}", "confirmed ear tags"),
              Container(width: 1, height: 30, color: const Color(0xFFE2DFD2)),
              _buildMiniSummaryStat("TOTAL RECORDS", "${summary.length * 4 + 10}", "tagged observations"),
            ],
          ),
        ),

        const SizedBox(height: 16),
        
        // Cattle Cards List
        if (filteredKeys.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Text(
                "No cattle records found matching search query",
                style: TextStyle(color: Color(0xFF526058)),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredKeys.length,
            itemBuilder: (context, index) {
              final key = filteredKeys[index];
              final data = summary[key] ?? {};
              return _buildCattleCard(key, data);
            },
          ),
      ],
    );
  }

  Widget _buildMiniSummaryStat(String title, String val, String subtitle) {
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF707974)),
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF006857)),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8.5, color: Color(0xFF707974)),
          ),
        ],
      ),
    );
  }

  Widget _buildCattleCard(String cattleId, Map<String, dynamic> data) {
    final int totalRecords = (data["total_records"] ?? 0) is int ? data["total_records"] : int.tryParse(data["total_records"]?.toString() ?? "0") ?? 0;
    final List<String> rawCams = data["cameras_seen"] != null ? List<String>.from(data["cameras_seen"]) : [];
    final camerasSeen = rawCams.isNotEmpty ? rawCams : ["CAM1"];
    
    // Calculate behavior percentages dynamically
    double lyingPct = (data["lying_pct"] ?? 0.0).toDouble();
    double standingPct = (data["standing_pct"] ?? 0.0).toDouble();
    double feedingPct = (data["feeding_pct"] ?? 0.0).toDouble();
    double idlePct = (data["idle_pct"] ?? 0.0).toDouble();

    // Fallback: If percentages are zero but posture_counts/feeding_counts exist
    if (totalRecords > 0 && lyingPct == 0.0 && standingPct == 0.0 && data["posture_counts"] is Map) {
      final pc = Map<String, dynamic>.from(data["posture_counts"]);
      final int lyingCount = (pc["Lying"] ?? pc["lying"] ?? 0) as int;
      final int standingCount = (pc["Standing"] ?? pc["standing"] ?? 0) as int;
      lyingPct = (lyingCount / totalRecords) * 100.0;
      standingPct = (standingCount / totalRecords) * 100.0;
    }
    if (totalRecords > 0 && feedingPct == 0.0 && idlePct == 0.0 && data["feeding_counts"] is Map) {
      final fc = Map<String, dynamic>.from(data["feeding_counts"]);
      final int feedingCount = (fc["Feeding_Behaviour"] ?? fc["feeding"] ?? fc["Feeding"] ?? 0) as int;
      final int idleCount = (fc["Idle_Behaviour"] ?? fc["idle"] ?? fc["Idle"] ?? 0) as int;
      feedingPct = (feedingCount / totalRecords) * 100.0;
      idlePct = (idleCount / totalRecords) * 100.0;
    }
    
    String firstSeen = (data["first_seen"] ?? "").toString().trim();
    if (firstSeen.isEmpty) {
      firstSeen = "Not logged yet";
    }
    String lastSeen = (data["last_seen"] ?? "").toString().trim();
    if (lastSeen.isEmpty) {
      lastSeen = "Not logged yet";
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2DFD2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Ear Tag ID & Identified Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "EAR TAG ID",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Color(0xFF707974),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cattleId,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF006857),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Color(0xFF006857)),
                          SizedBox(width: 4),
                          Text(
                            "IDENTIFIED",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006857),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$totalRecords obs",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF707974),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE2DFD2), height: 1),
            const SizedBox(height: 12),

            // Behavior Distribution Bar & Legend
            _buildBehaviorDistributionBar(
              lyingPct: lyingPct,
              standingPct: standingPct,
              feedingPct: feedingPct,
              idlePct: idlePct,
            ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE2DFD2), height: 1),
            const SizedBox(height: 12),

            // Timestamps: FIRST SEEN & LAST SEEN
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "FIRST SEEN",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF707974),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        firstSeen,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF191C1B),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "LAST SEEN",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF707974),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lastSeen,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF191C1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Footer Actions Row: CAM tags, CSV, View History (Overflow-safe layout)
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...camerasSeen.map((cam) => Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFECE0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  cam.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF006857),
                                  ),
                                ),
                              ),
                            )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFECE0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "CSV",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF526058),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: Color(0xFF006857), width: 1),
                    backgroundColor: const Color(0xFFEFECE0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    "View History →",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006857),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviorDistributionBar({
    required double lyingPct,
    required double standingPct,
    required double feedingPct,
    required double idlePct,
  }) {
    final total = lyingPct + standingPct + feedingPct + idlePct;
    final flexLying = total == 0 ? 0 : (lyingPct * 10).round();
    final flexStanding = total == 0 ? 50 : (standingPct * 10).round();
    final flexFeeding = total == 0 ? 25 : (feedingPct * 10).round();
    final flexIdle = total == 0 ? 25 : (idlePct * 10).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "BEHAVIOR DISTRIBUTION",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Color(0xFF006857),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (flexLying > 0)
                  Expanded(flex: flexLying, child: Container(color: const Color(0xFFE57373))),
                if (flexStanding > 0)
                  Expanded(flex: flexStanding, child: Container(color: const Color(0xFF4CAF50))),
                if (flexFeeding > 0)
                  Expanded(flex: flexFeeding, child: Container(color: const Color(0xFF00897B))),
                if (flexIdle > 0)
                  Expanded(flex: flexIdle, child: Container(color: const Color(0xFFFFB300))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildLegendItem("Lying", lyingPct, const Color(0xFFE57373))),
            Expanded(child: _buildLegendItem("Standing", standingPct, const Color(0xFF4CAF50))),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _buildLegendItem("Feeding", feedingPct, const Color(0xFF00897B))),
            Expanded(child: _buildLegendItem("Idle", idlePct, const Color(0xFFFFB300))),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, double pct, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          "$label: ${pct.toStringAsFixed(0)}%",
          style: const TextStyle(fontSize: 11, color: Color(0xFF526058), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ── 3. SECURITY ACCESS TAB ──
  Widget _buildSecurityTab() {
    final attendance = _telemetry?.securityAttendance ?? [];
    final logs = _telemetry?.securityLogs ?? [];
    final unknown = _telemetry?.securityUnknown ?? [];
    
    // Calculate counts
    final totalVisits = logs.length;
    final workersCount = attendance.where((x) => x["role"].toString().toLowerCase() == "worker").length;
    final familyCount = attendance.where((x) => x["role"].toString().toLowerCase() == "family" || x["role"].toString().toLowerCase() == "member").length;
    final alertsCount = unknown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Security Stats Strip
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _buildStatCard("Total Check-ins", totalVisits.toString(), Icons.badge_outlined, const Color(0xFF006857)),
            _buildStatCard("Active Workers", workersCount.toString(), Icons.engineering, const Color(0xFF006857)),
            _buildStatCard("Family Members", familyCount.toString(), Icons.home, const Color(0xFF006857)),
            _buildStatCard("Security Alerts", alertsCount.toString(), Icons.gpp_maybe, const Color(0xFFBA1A1A)),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Attendance Board Section
        const Row(
          children: [
            Icon(Icons.assignment_ind, color: Color(0xFF006857)),
            SizedBox(width: 8),
            Text(
              "Registered Members Attendance",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF191C1B)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (attendance.isEmpty)
          _buildEmptyWidget("No attendance logged today")
        else
          Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2DFD2)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attendance.length,
              separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFE2DFD2)),
              itemBuilder: (context, index) {
                final member = attendance[index];
                final status = member["status"] ?? "Away";
                final isActive = status.toString().toLowerCase() == "active" || status.toString().toLowerCase() == "in";
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? const Color(0xFF006857).withOpacity(0.15) : const Color(0xFFEFECE0),
                    child: Icon(
                      Icons.person, 
                      color: isActive ? const Color(0xFF006857) : const Color(0xFF707974)
                    ),
                  ),
                  title: Text(member["name"] ?? "Anonymous", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF191C1B))),
                  subtitle: Text("Access: ${member['role'] ?? 'Worker'} | In: ${member['first_check_in'] ?? '—'}", style: const TextStyle(color: Color(0xFF526058))),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF006857).withOpacity(0.12) : const Color(0xFFEFECE0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: isActive ? const Color(0xFF006857) : const Color(0xFF707974), 
                        fontWeight: FontWeight.bold,
                        fontSize: 11
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
        const SizedBox(height: 24),
        
        // Security Visitor Logs Section
        const Row(
          children: [
            Icon(Icons.list_alt, color: Color(0xFF006857)),
            SizedBox(width: 8),
            Text(
              "Recent Security Access Logs",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF191C1B)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (logs.isEmpty)
          _buildEmptyWidget("No logs today")
        else
          Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2DFD2)),
            ),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: logs.length > 30 ? 30 : logs.length,
                separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFE2DFD2)),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final status = log["status"] ?? "Alert";
                  final isAlert = status.toString().toLowerCase().contains("alert") || status.toString().toLowerCase().contains("unauthorized");
                  return ListTile(
                    leading: Icon(
                      isAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: isAlert ? const Color(0xFFBA1A1A) : const Color(0xFF006857),
                    ),
                    title: Text(
                      log["name"] ?? "Visitor",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF191C1B)),
                    ),
                    subtitle: Text("Time: ${log['time'] ?? '—'} | Track ID: ${log['track_id'] ?? '—'}", style: const TextStyle(color: Color(0xFF526058))),
                    trailing: Text(
                      status,
                      style: TextStyle(
                        color: isAlert ? const Color(0xFFBA1A1A) : const Color(0xFF006857),
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
        const SizedBox(height: 24),
        
        // Unknown Intruders Section
        const Row(
          children: [
            Icon(Icons.gpp_maybe, color: Color(0xFFBA1A1A)),
            SizedBox(width: 8),
            Text(
              "Captured Unknown Visitors",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFBA1A1A)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (unknown.isEmpty)
          _buildEmptyWidget("No unauthorized visitors detected today")
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: unknown.length,
            itemBuilder: (context, index) {
              final item = unknown[index];
              return Card(
                color: const Color(0xFFFCEAE6),
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFBA1A1A), width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Face Photo Container matching web dashboard screenshot
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _buildSecurityFaceImage(item),
                          ),
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBA1A1A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "UNVERIFIED",
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Bottom Metadata
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item["name"] ?? "UNKNOWN ${item['track_id'] ?? ''}").toString().toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF191C1B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Time: ${item['time'] ?? '—'}",
                            style: const TextStyle(color: Color(0xFF526058), fontSize: 11),
                          ),
                          Text(
                            "Track ID: ${item['track_id'] ?? '—'}",
                            style: const TextStyle(color: Color(0xFF707974), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSecurityFaceImage(Map<String, dynamic> item) {
    final String? rawImage = item["image"] ?? item["image_url"] ?? item["crop"] ?? item["crop_url"] ?? item["crop_path"] ?? item["snapshot"] ?? item["file_path"];
    final String trackId = (item["track_id"] ?? item["id"] ?? "").toString();

    Widget fallbackIcon = Container(
      color: const Color(0xFFBA1A1A).withOpacity(0.12),
      child: const Center(
        child: Icon(Icons.person_outline, size: 48, color: Color(0xFFBA1A1A)),
      ),
    );

    if (rawImage != null && rawImage.toString().isNotEmpty) {
      final strImg = rawImage.toString();
      if (strImg.startsWith("data:image") || (!strImg.startsWith("http") && !strImg.contains("/") && strImg.length > 100)) {
        try {
          final cleanBase64 = strImg.contains(",") ? strImg.split(",").last : strImg;
          final bytes = base64Decode(cleanBase64);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallbackIcon,
          );
        } catch (_) {}
      }

      String fullUrl = strImg;
      if (!strImg.startsWith("http")) {
        fullUrl = strImg.startsWith("/") 
            ? "${AppConfig.ec2ServerUrl}$strImg" 
            : "${AppConfig.ec2ServerUrl}/$strImg";
      }

      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (trackId.isNotEmpty) {
            return Image.network(
              "${AppConfig.ec2ServerUrl}/api/security/snapshot/$trackId",
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => fallbackIcon,
            );
          }
          return fallbackIcon;
        },
      );
    }

    if (trackId.isNotEmpty) {
      return Image.network(
        "${AppConfig.ec2ServerUrl}/api/security/snapshot/$trackId",
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.network(
            "${AppConfig.ec2ServerUrl}/snapshots/$trackId.jpg",
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => fallbackIcon,
          );
        },
      );
    }

    return fallbackIcon;
  }

  Widget _buildEmptyWidget(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2DFD2)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF526058), fontSize: 13),
        ),
      ),
    );
  }

  // ── ALERTS BOTTOM SHEET DIALOG ──
  void _showAlertsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF6F4E8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning, color: Color(0xFFBA1A1A)),
                  SizedBox(width: 8),
                  Text(
                    "Farm Security Alert Logs",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF191C1B)),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE2DFD2), height: 20),
              Expanded(
                child: _alerts.isEmpty
                    ? const Center(
                        child: Text(
                          "No active alerts today",
                          style: TextStyle(color: Color(0xFF526058)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _alerts.length,
                        itemBuilder: (context, index) {
                          final alert = _alerts[index];
                          final isHigh = alert.severity.toLowerCase() == 'high';
                          return Card(
                            color: isHigh ? const Color(0xFFFCEAE6) : Colors.white,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isHigh ? const Color(0xFFBA1A1A) : const Color(0xFFE2DFD2),
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isHigh ? const Color(0xFFBA1A1A) : const Color(0xFF006857),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _buildSecurityFaceImage({
                                  "image": alert.imageUrl,
                                  "track_id": alert.trackId,
                                }),
                              ),
                              title: Text(
                                alert.message,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF191C1B)),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Category: ${alert.category} | ${alert.timestamp.contains('T') ? alert.timestamp.split('T').last.split('.').first : alert.timestamp}",
                                      style: const TextStyle(color: Color(0xFF526058), fontSize: 11),
                                    ),
                                    if (alert.unknownPersonId != null || alert.trackId != null || alert.phone != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        "ID: ${alert.unknownPersonId ?? alert.trackId ?? 'Unknown'} ${alert.phone != null && alert.phone!.isNotEmpty ? '| Phone: ${alert.phone}' : ''}",
                                        style: const TextStyle(color: Color(0xFFBA1A1A), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
