import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'services/api_service.dart';
import 'reports_screen.dart';
import '../registry/providers/cattle_registry_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _groupedHistory = [];
  List<dynamic> _rawHistory = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final flatHistory = await _apiService.getHistory();
      if (!mounted) return;
      _groupHistory(flatHistory);
      setState(() {
        _rawHistory = flatHistory;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '');
      });
    }
  }

  void _groupHistory(List<dynamic> flatHistory) {
    CattleRegistryProvider? registry;
    try {
      registry = Provider.of<CattleRegistryProvider>(context, listen: false);
    } catch (_) {}

    final Map<String, List<dynamic>> groups = {};
    for (var item in flatHistory) {
      final String cowId = (item['cow_id'] ?? item['id'] ?? '').toString();
      final String cowName = (item['name'] ?? item['cow_name'] ?? '').toString();

      // Strict Farmer Cattle Registry Filter: exclude any orphan or unregistered cattle data
      if (registry != null && !registry.isCattleRegistered(cowId, cowName)) {
        continue;
      }

      if (cowId.isNotEmpty && cowId != 'N/A') {
        if (!groups.containsKey(cowId)) {
          groups[cowId] = [];
        }
        groups[cowId]!.add(item);
      }
    }

    _groupedHistory = [];
    groups.forEach((cowId, list) {
      // Sort entries by timestamp descending
      list.sort((a, b) {
        final String tA = a['timestamp'] ?? '';
        final String tB = b['timestamp'] ?? '';
        return tB.compareTo(tA);
      });

      final latest = list.first;
      _groupedHistory.add({
        'cow_id': cowId,
        'name': latest['name'] ?? latest['cow_name'] ?? 'Unnamed',
        'breed': latest['breed'] ?? 'Unknown',
        'section': latest['section'] ?? 'General',
        'latest_weight': (latest['weight_kg'] as num? ?? 0.0).toDouble(),
        'latest_glb_url': latest['glb_url'],
        'entries': list,
      });
    });
  }

  void _deleteCattleGroup(String cowId, int index) async {
    final success = await _apiService.deleteCattle(cowId);
    if (success) {
      setState(() {
        _groupedHistory.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Record for Cattle ID $cowId deleted successfully.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete record.')),
        );
      }
    }
  }

  void _clearAllRecords() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAF7E8),
          title: const Text('Clear All Records', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete all estimation history? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear All'),
            )
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _apiService.clearDatabase();
      if (success) {
        setState(() {
          _groupedHistory.clear();
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database cleared successfully.')),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to clear database.')),
          );
        }
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006D60),
        foregroundColor: Colors.white,
        title: const Text('Estimation History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_groupedHistory.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportsScreen(
                      rawHistory: _rawHistory.map((item) => Map<String, dynamic>.from(item)).toList(),
                    ),
                  ),
                );
              },
              tooltip: 'PDF Reports',
            ),

            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllRecords,
              tooltip: 'Clear All Records',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF006D60)))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D60), foregroundColor: Colors.white),
                          onPressed: _fetchHistory,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _groupedHistory.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 54, color: Colors.black26),
                          SizedBox(height: 12),
                          Text(
                            'No estimation history found.',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black38),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _groupedHistory.length,
                      itemBuilder: (context, index) {
                        return HistoryCard(
                          group: _groupedHistory[index],
                          onDelete: () => _deleteCattleGroup(_groupedHistory[index]['cow_id'], index),
                          onRecheck: () {
                            Navigator.pop(context); // Go back to HomeScreen to recheck
                          },
                        );
                      },
                    ),
    );
  }
}

class HistoryCard extends StatefulWidget {
  final Map<String, dynamic> group;
  final VoidCallback onDelete;
  final VoidCallback onRecheck;

  const HistoryCard({
    super.key,
    required this.group,
    required this.onDelete,
    required this.onRecheck,
  });

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final String name = group['name'];
    final String breed = group['breed'];
    final String cowId = group['cow_id'];
    final String section = group['section'];
    final double latestWeight = group['latest_weight'];
    final String? latestGlbUrl = group['latest_glb_url'];
    final List<dynamic> entries = group['entries'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. 3D Model / Placeholder at the top ──
          Container(
            height: 220,
            width: double.infinity,
            color: const Color(0xFFEEEBD8),
            child: latestGlbUrl != null && latestGlbUrl.isNotEmpty
                ? ModelViewer(
                    src: latestGlbUrl,
                    alt: '3D Cattle Model',
                    autoRotate: true,
                    cameraControls: true,
                    backgroundColor: const Color(0xFFEEEBD8),
                    shadowIntensity: 1.0,
                    ar: false,
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.widgets_outlined, size: 48, color: Colors.black26),
                        SizedBox(height: 8),
                        Text('NO MODEL AVAILABLE', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
          ),

          // ── 2. Weight History Dropdown Header ──
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.stacked_line_chart, color: Color(0xFF006D60), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Weight History (${entries.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                  ),
                  const Spacer(),
                  Text(
                    _isExpanded ? 'Hide past entries' : 'View past entries',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Icon(
                    _isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Weight History Expanded List ──
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Column(
                children: List.generate(entries.length, (idx) {
                  final entry = entries[idx];
                  final double w = (entry['weight_kg'] as num? ?? 0.0).toDouble();
                  final String time = entry['timestamp'] ?? '';
                  final bool isLatest = idx == 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isLatest ? Colors.white : const Color(0xFFF2EFE0),
                      borderRadius: BorderRadius.circular(8),
                      border: isLatest
                          ? Border.all(color: const Color(0xFF006D60), width: 1.5)
                          : Border.all(color: Colors.transparent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isLatest ? '$time  (Latest)' : time,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                            color: isLatest ? const Color(0xFF006D60) : Colors.black87,
                          ),
                        ),
                        Text(
                          '${w.toStringAsFixed(1)} KG',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isLatest ? const Color(0xFF006D60) : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),

          const Divider(height: 1, thickness: 1),

          // ── 4. Cattle Details and Actions ──
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Metadata (Name, Breed, ID, Category)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$name ($breed)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: $cowId • $section',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    // Estimated Weight Display
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'ESTIMATED WEIGHT',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38),
                        ),
                        const SizedBox(height: 2),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Color(0xFF006D60)),
                            children: [
                              TextSpan(
                                text: latestWeight.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                              const TextSpan(
                                text: ' KG',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Recheck Weight Button
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006D60),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          onPressed: widget.onRecheck,
                          child: const Text(
                            'Recheck weight',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Delete Button
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE4D6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFFFAF7E8),
                              title: const Text('Delete Record'),
                              content: Text('Are you sure you want to delete the record for $name?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.onDelete();
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
