import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final LinearGradient? gradient;

  const AnalyticsCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: AppTheme.cardDecoration(
        isDark: isDark,
        borderRadius: 16,
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: gradient != null
            ? BoxDecoration(
                gradient: gradient!.withOpacity(0.08),
              )
            : null,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.textMuted : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textDark : AppTheme.textLight,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.textMuted : Colors.black54,
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]
          ],
        ),
      ),
    );
  }
}

extension on LinearGradient {
  LinearGradient withOpacity(double opacity) {
    return LinearGradient(
      colors: colors.map((c) => c.withOpacity(opacity)).toList(),
      begin: begin,
      end: end,
    );
  }
}
