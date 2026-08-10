import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/vaccination_model.dart';

class RecentLogTile extends StatelessWidget {
  final VaccinationModel vaccination;
  final VoidCallback? onTap;

  const RecentLogTile({
    Key? key,
    required this.vaccination,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formattedGivenDate = DateFormat('dd MMMM yyyy').format(vaccination.vaccinationDate);
    final formattedReminderDate = DateFormat('dd MMMM yyyy').format(vaccination.nextReminderDate);

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEBE6D9), width: 1),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Stack(
            children: [
              // Golden star badge in the top right corner if starred
              if (vaccination.isStarred)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.starOrange,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Avatar + Name & ID Row
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pets,
                          color: AppTheme.accentTeal,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vaccination.cattleName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              vaccination.cattleId,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.lightText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Reserve space for the star on the right
                      if (vaccination.isStarred) const SizedBox(width: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Given info row (Vaccine Type)
                  Row(
                    children: [
                      const Icon(Icons.vaccines_outlined, size: 14, color: AppTheme.lightText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vaccination.vaccineName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.darkText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Administered Date Row
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.lightText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          formattedGivenDate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.lightText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF3EFE3), height: 1),
                  const SizedBox(height: 10),
                  // Next Reminder Section (Teal-highlighted)
                  const Text(
                    'NEXT REMINDER:',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedReminderDate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
