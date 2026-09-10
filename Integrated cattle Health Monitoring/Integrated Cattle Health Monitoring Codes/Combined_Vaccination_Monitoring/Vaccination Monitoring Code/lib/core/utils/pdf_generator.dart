import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/vaccination_monitoring/data/models/vaccination_model.dart';
import '../../features/vaccination_monitoring/data/models/reminder_model.dart';

class PdfGenerator {
  static Future<Uint8List> generateVaccinationReport({
    required String cattleName,
    required String cattleId,
    required List<VaccinationModel> vaccinations,
    required List<ReminderModel> reminders,
    required double complianceRate,
    required int totalVaccinations,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF0F7643), width: 2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'KisanPro',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF0F7643),
                        ),
                      ),
                      pw.Text(
                        'Smart Vaccination Monitoring System',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColor.fromInt(0xFF708076),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'VACCINATION REPORT',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF1B2A21),
                        ),
                      ),
                      pw.Text(
                        'Date: ${DateTime.now().toString().substring(0, 10)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Cattle Profile Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF7F9FB),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFE0E5E2)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CATTLE PROFILE',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF0F7643),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Cattle Name: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                pw.TextSpan(text: cattleName),
                              ],
                            ),
                          ),
                          pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Cattle ID: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                pw.TextSpan(text: cattleId),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Total Vaccinations: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                pw.TextSpan(text: '$totalVaccinations'),
                              ],
                            ),
                          ),
                          pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Compliance Rate: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                pw.TextSpan(text: '${complianceRate.toStringAsFixed(1)}%'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table of Vaccination Records
            pw.Text(
              'VACCINATION LOGS',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF0F7643),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE0E5E2), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(2.5),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8F5E9)),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Cattle ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Vaccine Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Administered Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Next Reminder', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                  ],
                ),
                // Table Body
                ...vaccinations.map((vac) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(vac.cattleId, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(vac.vaccineName, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(vac.vaccinationDate.toString().substring(0, 10), style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(vac.nextReminderDate.toString().substring(0, 10), style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          vac.status,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: vac.status.toLowerCase() == 'completed'
                                ? const PdfColor.fromInt(0xFF2E7D32)
                                : const PdfColor.fromInt(0xFFD32F2F),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 20),

            // Table of Reminders
            pw.Text(
              'UPCOMING SCHEDULED REMINDERS',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF0F7643),
              ),
            ),
            pw.SizedBox(height: 8),
            if (reminders.isEmpty)
              pw.Text('No pending reminders scheduled.', style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF708076)))
            else
              pw.Table(
                border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE0E5E2), width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(4.5),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8F5E9)),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Reminder Target', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Target Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                    ],
                  ),
                  ...reminders.map((rem) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(rem.vaccineName, style: const pw.TextStyle(fontSize: 8)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(rem.reminderDate.toString().substring(0, 10), style: const pw.TextStyle(fontSize: 8)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(rem.description, style: const pw.TextStyle(fontSize: 8)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(rem.status, style: const pw.TextStyle(fontSize: 8)),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            
            // Footer Branding
            pw.Spacer(),
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'This is a computer-generated report from KisanPro Smart Farming Solutions.',
                style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF708076)),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
