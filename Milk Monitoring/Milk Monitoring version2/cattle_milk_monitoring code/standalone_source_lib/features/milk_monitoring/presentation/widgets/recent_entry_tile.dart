import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/milk_record_model.dart';
import '../providers/milk_provider.dart';

class RecentEntryTile extends StatelessWidget {
  final List<MilkRecordModel> records;
  final VoidCallback? onTap;

  const RecentEntryTile({
    super.key,
    required this.records,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstRecord = records.first;
    
    // Sort so Morning comes first, then Evening
    final sortedRecs = List<MilkRecordModel>.from(records)
      ..sort((a, b) => a.milkTime == 'Morning' ? -1 : 1);

    final double totalQuantity = records.fold(0.0, (s, r) => s + r.quantity);
    final dateFormat = DateFormat('dd MMM yyyy');
    final formattedDate = dateFormat.format(firstRecord.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppTheme.cardDecoration(
        isDark: isDark,
        borderRadius: 16,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER: Cow identity & total daily yield
              Row(
                children: [
                  // Paw Avatar Circle
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE0B2), // Light Orange Accent
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.pets,
                        color: Color(0xFFE65100),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name and ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstRecord.cattleName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textLight,
                          ),
                        ),
                        Text(
                          "ID: ${firstRecord.cattleId}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Total Quantity Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1), // Light Mint Green
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.opacity,
                          color: AppTheme.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${totalQuantity.toStringAsFixed(1)} L",
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.5, color: AppTheme.borderLight),
              const SizedBox(height: 10),

              // 2. SESSIONS: Morning & Evening milking detail rows
              ...sortedRecs.map((r) {
                final isMorning = r.milkTime == 'Morning';
                return Consumer<MilkProvider>(
                  builder: (context, provider, _) {
                    final rate = provider.calculateRate(r.fat, r.snf);
                    final earnings = rate * r.quantity;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          // Session Icon
                          Icon(
                            isMorning ? Icons.wb_sunny_outlined : Icons.mode_night_outlined,
                            size: 16,
                            color: isMorning ? Colors.orange : Colors.indigo,
                          ),
                          const SizedBox(width: 8),
                          
                          // Session details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${r.milkTime} Milking: ${r.quantity.toStringAsFixed(1)}L",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textLight,
                                      ),
                                    ),
                                    Text(
                                      "₹${earnings.toStringAsFixed(1)}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Fat: ${r.fat.toStringAsFixed(1)}% | SNF: ${r.snf.toStringAsFixed(1)}%  (Rate: ₹${rate.toStringAsFixed(1)}/L)",
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 0.5, color: AppTheme.borderLight),
              const SizedBox(height: 10),

              // 3. BOTTOM ROW: Date & Total Combined Earnings
              Consumer<MilkProvider>(
                builder: (context, provider, _) {
                  double totalEarnings = 0.0;
                  for (final r in records) {
                    totalEarnings += provider.calculateRate(r.fat, r.snf) * r.quantity;
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Daily Earnings: ₹${totalEarnings.toStringAsFixed(1)}",
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
