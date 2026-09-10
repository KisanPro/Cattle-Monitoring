import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/milk_provider.dart';
import '../widgets/recent_entry_tile.dart';
import '../widgets/cattle_report_modal.dart';
import '../../../registry/providers/cattle_registry_provider.dart';

class MilkHistoryScreen extends StatefulWidget {
  const MilkHistoryScreen({super.key});

  @override
  State<MilkHistoryScreen> createState() => _MilkHistoryScreenState();
}

class _MilkHistoryScreenState extends State<MilkHistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-populate search text if provider already has query
    final provider = Provider.of<MilkProvider>(context, listen: false);
    _searchController.text = provider.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(BuildContext context, MilkProvider provider) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: provider.startDate != null && provider.endDate != null
          ? DateTimeRange(start: provider.startDate!, end: provider.endDate!)
          : null,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark 
              ? AppTheme.darkTheme.copyWith(
                  colorScheme: AppTheme.darkTheme.colorScheme.copyWith(
                    primary: AppTheme.primary,
                    onPrimary: Colors.white,
                  ),
                )
              : AppTheme.lightTheme.copyWith(
                  colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
                    primary: AppTheme.primary,
                    onPrimary: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      provider.setDateRange(picked.start, picked.end);
    }
  }

  void _exportCSV(BuildContext context, MilkProvider provider) {
    final records = provider.filteredRecords;
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No records to export."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Generate CSV String
    final buffer = StringBuffer();
    buffer.writeln("Cattle ID,Cattle Name,Session,Quantity (L),Fat (%),SNF (%),Rate (INR/L),Earnings (INR),Date,Timestamp");
    for (final r in records) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.timestamp);
      final timeStr = DateFormat('HH:mm:ss').format(r.timestamp);
      final rate = provider.calculateRate(r.fat, r.snf);
      final earnings = rate * r.quantity;
      buffer.writeln(
        "${r.cattleId},\"${r.cattleName}\",${r.milkTime},${r.quantity},${r.fat},${r.snf},${rate.toStringAsFixed(2)},${earnings.toStringAsFixed(2)},$dateStr,$dateStr $timeStr"
      );
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.primary),
              SizedBox(width: 8),
              Text("Export Complete"),
            ],
          ),
          content: const Text(
            "Milk records have been successfully formatted as CSV and copied to your device's clipboard.\n\nYou can now paste it into any spreadsheet (Excel, Sheets) or send it via message.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<MilkProvider>(
      builder: (context, provider, child) {
        final registry = context.watch<CattleRegistryProvider>();
        final filtered = provider.filteredRecords.where((r) => registry.isCattleRegistered(r.cattleId, r.cattleName)).toList();
        final groupedFiltered = provider.groupRecordsByCattleAndDay(filtered);

        return Column(
          children: [
            // Header & Filter Panel
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark.withOpacity(0.4) : Colors.white.withOpacity(0.6),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppTheme.borderDark.withOpacity(0.5) : AppTheme.borderLight,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Milk Production Logs",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Search cattle, apply date ranges, or export metrics.",
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // Export Button
                      IconButton(
                        tooltip: "Export Filtered Records",
                        icon: const Icon(Icons.download, color: AppTheme.primary),
                        onPressed: () => _exportCSV(context, provider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search input
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search by cow name or tag ID...",
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                provider.setSearchQuery('');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      setState(() {});
                      provider.setSearchQuery(val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips
                  Row(
                    children: [
                      // Date Selector Chip
                      ActionChip(
                        avatar: Icon(
                          Icons.calendar_today_outlined, 
                          size: 14, 
                          color: provider.startDate != null ? Colors.white : AppTheme.primary
                        ),
                        label: Text(
                          provider.startDate != null && provider.endDate != null
                              ? "${DateFormat('MMM dd').format(provider.startDate!)} - ${DateFormat('MMM dd').format(provider.endDate!)}"
                              : "Filter by Date Range",
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            color: provider.startDate != null ? Colors.white : (isDark ? Colors.white70 : Colors.black87)
                          ),
                        ),
                        backgroundColor: provider.startDate != null 
                            ? AppTheme.primary 
                            : (isDark ? AppTheme.surfaceDark : Colors.grey[200]),
                        onPressed: () => _pickDateRange(context, provider),
                      ),
                      const SizedBox(width: 8),

                      // Clear Filters Button (conditional)
                      if (provider.searchQuery.isNotEmpty || provider.startDate != null)
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            provider.clearFilters();
                          },
                          child: const Text(
                            "Clear Filters",
                            style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: groupedFiltered.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
                          SizedBox(height: 12),
                          Text(
                            "No records matching the filters.",
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20.0),
                      itemCount: groupedFiltered.length,
                      itemBuilder: (context, idx) {
                        final group = groupedFiltered[idx];
                        return RecentEntryTile(
                          records: group,
                          onTap: () => CattleReportModal.show(context, group.first.cattleName, group.first.cattleId),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
