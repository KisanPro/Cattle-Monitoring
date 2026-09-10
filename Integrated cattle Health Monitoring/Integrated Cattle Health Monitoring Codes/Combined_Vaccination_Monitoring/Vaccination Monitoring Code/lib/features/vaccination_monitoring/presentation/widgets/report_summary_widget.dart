import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/vaccination_model.dart';

class ReportSummaryWidget extends StatelessWidget {
  final List<VaccinationModel> vaccinations;

  const ReportSummaryWidget({
    Key? key,
    required this.vaccinations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (vaccinations.isEmpty) {
      return const Center(
        child: Text(
          'No vaccination logs found.',
          style: TextStyle(color: AppTheme.lightText, fontStyle: FontStyle.italic),
        ),
      );
    }

    // Calculate frequency and latest date for each vaccine type
    final Map<String, int> frequencies = {};
    final Map<String, DateTime> latestDates = {};

    for (var vac in vaccinations) {
      final name = vac.vaccineName.trim();
      frequencies[name] = (frequencies[name] ?? 0) + 1;
      
      final currentLatest = latestDates[name];
      if (currentLatest == null || vac.vaccinationDate.isAfter(currentLatest)) {
        latestDates[name] = vac.vaccinationDate;
      }
    }

    final sortedVaccines = frequencies.keys.toList()
      ..sort((a, b) => (frequencies[b] ?? 0).compareTo(frequencies[a] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VACCINE TYPE FREQUENCY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.lightText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedVaccines.length,
          separatorBuilder: (context, index) => const Divider(height: 16, color: Color(0xFFE0E5E2)),
          itemBuilder: (context, index) {
            final name = sortedVaccines[index];
            final count = frequencies[name] ?? 0;
            final lastDate = latestDates[name];

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.mintGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count x',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                        if (lastDate != null)
                          Text(
                            'Last given: ${lastDate.toString().substring(0, 10)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.lightText,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: AppTheme.lightText,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
