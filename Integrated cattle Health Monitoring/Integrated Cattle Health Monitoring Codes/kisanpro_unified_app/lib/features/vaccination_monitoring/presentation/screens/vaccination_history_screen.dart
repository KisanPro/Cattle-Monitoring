import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/vaccination_provider.dart';
import '../widgets/recent_log_tile.dart';
import '../../../registry/providers/cattle_registry_provider.dart';

class VaccinationHistoryScreen extends StatefulWidget {
  final String? searchFilter;

  const VaccinationHistoryScreen({
    Key? key,
    this.searchFilter,
  }) : super(key: key);

  @override
  State<VaccinationHistoryScreen> createState() => _VaccinationHistoryScreenState();
}

class _VaccinationHistoryScreenState extends State<VaccinationHistoryScreen> {
  late TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchFilter ?? '');
    _query = widget.searchFilter ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VaccinationProvider>(context);
    final registry = Provider.of<CattleRegistryProvider>(context);

    // Filter list based on search query and farmer cattle registry
    final filteredLogs = provider.vaccinations.where((log) {
      if (!registry.isCattleRegistered(log.cattleId, log.cattleName)) return false;
      final q = _query.toLowerCase().trim();
      if (q.isEmpty) return true;

      return log.cattleName.toLowerCase().contains(q) ||
          log.cattleId.toLowerCase().contains(q) ||
          log.vaccineName.toLowerCase().contains(q) ||
          log.status.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaccination History'),
      ),
      body: Column(
        children: [
          // Search Box Widget
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _query = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by cattle ID, name, or vaccine...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.lightText),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.lightText),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E5E2), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                ),
              ),
            ),
          ),

          // Total count label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${filteredLogs.length} records',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.lightText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_query.isNotEmpty)
                  Text(
                    'Filtered by "$_query"',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryGreen,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Logs List
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: AppTheme.lightText.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No matching vaccination records found.',
                            style: TextStyle(fontSize: 16, color: AppTheme.lightText),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      return RecentLogTile(
                        vaccination: log,
                        onTap: () {
                          // View specific details in a bottom drawer or modal
                          _showDetailsBottomSheet(context, log);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDetailsBottomSheet(BuildContext context, dynamic log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vaccination Record Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE0E5E2)),
              const SizedBox(height: 12),
              _buildDetailRow('Cattle Name', log.cattleName),
              _buildDetailRow('Cattle ID', log.cattleId),
              _buildDetailRow('Vaccine Type', log.vaccineName),
              _buildDetailRow('Administered On', log.vaccinationDate.toString().substring(0, 10)),
              _buildDetailRow('Next Booster Date', log.nextReminderDate.toString().substring(0, 10)),
              _buildDetailRow('Verification Status', log.status),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.lightText, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppTheme.darkText, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
