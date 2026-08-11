import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'register_screen.dart';

class MemberListScreen extends StatefulWidget {
  final VoidCallback onOpenSettings;
  const MemberListScreen({Key? key, required this.onOpenSettings}) : super(key: key);

  @override
  State<MemberListScreen> createState() => MemberListScreenState();
}

class MemberListScreenState extends State<MemberListScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  String _farmId = "";

  @override
  void initState() {
    super.initState();
    _loadFarmIdAndMembers();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadMembersOnly());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void reloadSettings() {
    _loadFarmIdAndMembers();
  }

  Future<void> _loadFarmIdAndMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final mobile = prefs.getString("mobile_number") ?? "";
    final farm = prefs.getString("farm_name") ?? "";
    
    if (mobile.isNotEmpty && farm.isNotEmpty) {
      _farmId = "farm_${mobile}_${farm.replaceAll(' ', '_')}";
      _loadMembers();
    } else {
      setState(() {
        _members = [];
        _isLoading = false;
        _farmId = "";
      });
    }
  }

  Future<void> _loadMembersOnly() async {
    if (_farmId.isEmpty) return;
    final list = await ApiService.fetchRegisteredMembers(_farmId);
    if (mounted) {
      // Smart Diff Check: Only update state if member names or roles changed
      bool hasChanged = false;
      if (list.length != _members.length) {
        hasChanged = true;
      } else {
        for (int i = 0; i < list.length; i++) {
          if (list[i]['raw_name'] != _members[i]['raw_name'] ||
              list[i]['role'] != _members[i]['role']) {
            hasChanged = true;
            break;
          }
        }
      }

      if (hasChanged) {
        setState(() {
          _members = list;
        });
      }
    }
  }

  Future<void> _loadMembers() async {
    if (_farmId.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });

    final list = await ApiService.fetchRegisteredMembers(_farmId);
    if (mounted) {
      setState(() {
        _members = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteMember(String rawName, String name) async {
    if (_farmId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Member?", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to remove $name and delete their registered face embeddings?", style: const TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.black38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.deleteMember(rawName, _farmId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$name successfully deleted from database.")),
        );
        _loadMembers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete member. Please try again.")),
        );
      }
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    ).then((_) => _loadMembers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Member Monitoring",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
          : RefreshIndicator(
              onRefresh: _loadMembers,
              color: const Color(0xFF004D40),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Add Farm Member Button (Teal Block)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _navigateToRegister,
                    child: const Text(
                      "Add Farm Member",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Summary Card matching web UI details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE9ECEF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F3F5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.security, color: Colors.black45, size: 24),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.circle, color: Color(0xFF2E7D32), size: 8),
                                  SizedBox(width: 4),
                                  Text(
                                    "SECURITY ACTIVE",
                                    style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Farm Access Monitoring",
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "AI cameras monitor authorized farm members and alert on unrecognized personnel.",
                          style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. List Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "ACTIVE MEMBERS",
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                      Text(
                        "${_members.length} Registered",
                        style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. Members list
                  if (_members.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: const Center(
                        child: Text(
                          "No active members registered.",
                          style: TextStyle(color: Colors.black38, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._members.map((m) {
                      final String name = m['name'] ?? 'Unknown';
                      final String rawName = m['raw_name'] ?? '';
                      final String role = m['role'] ?? 'Worker';
                      final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                      // Cycle circle colors matching web UI look
                      final List<Color> avatarColors = [
                        const Color(0xFF00897B),
                        const Color(0xFF1E88E5),
                        const Color(0xFFD81B60),
                        const Color(0xFF8E24AA),
                      ];
                      final Color avColor = avatarColors[rawName.hashCode % avatarColors.length];

                      return Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE9ECEF)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: m['profile_url'] != null && (m['profile_url'] as String).isNotEmpty
                                  ? Image.network(
                                      m['profile_url'] as String,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 40,
                                          height: 40,
                                          color: avColor,
                                          alignment: Alignment.center,
                                          child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                                        );
                                      },
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      color: avColor,
                                      alignment: Alignment.center,
                                      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    role,
                                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  const Row(
                                    children: [
                                      Icon(Icons.check, color: Color(0xFF2E7D32), size: 12),
                                      SizedBox(width: 2),
                                      Text(
                                        "Authorized",
                                        style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFEBEE),
                                foregroundColor: const Color(0xFFC62828),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Color(0xFFFBC02D), width: 0),
                                ),
                              ),
                              onPressed: () => _deleteMember(rawName, name),
                              child: const Text("Delete", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
    );
  }
}
