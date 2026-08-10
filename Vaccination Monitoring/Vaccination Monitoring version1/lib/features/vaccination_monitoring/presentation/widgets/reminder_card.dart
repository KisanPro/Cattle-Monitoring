import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/reminder_model.dart';

class ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback? onComplete;

  const ReminderCard({
    Key? key,
    required this.reminder,
    this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCompleted = reminder.status.toLowerCase() == 'completed';
    final isOverdue = !isCompleted && reminder.reminderDate.isBefore(DateTime.now());

    Color cardBorderColor = const Color(0xFFE0E5E2);
    Color dateColor = AppTheme.warningColor;
    IconData statusIcon = Icons.pending_actions_outlined;

    if (isCompleted) {
      cardBorderColor = AppTheme.accentGreen.withOpacity(0.3);
      dateColor = AppTheme.accentGreen;
      statusIcon = Icons.check_circle_outline;
    } else if (isOverdue) {
      cardBorderColor = AppTheme.errorColor.withOpacity(0.3);
      dateColor = AppTheme.errorColor;
      statusIcon = Icons.error_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted ? AppTheme.mintGreen.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Left Status Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: dateColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: dateColor, size: 22),
            ),
            const SizedBox(width: 16),
            // Middle Content Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.vaccineName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reminder.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.lightText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 12, color: dateColor),
                      const SizedBox(width: 4),
                      Text(
                        'Scheduled: ${reminder.reminderDate.toString().substring(0, 10)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: dateColor,
                        ),
                      ),
                      if (isOverdue) ...[
                        const SizedBox(width: 8),
                        const Text(
                          '(Overdue)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Right Action Button
            if (!isCompleted)
              IconButton(
                onPressed: onComplete,
                icon: const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 28),
                tooltip: 'Mark Completed',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.mintGreen,
                  padding: const EdgeInsets.all(6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
