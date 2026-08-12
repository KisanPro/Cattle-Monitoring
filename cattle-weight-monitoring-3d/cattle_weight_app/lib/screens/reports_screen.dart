import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> rawHistory;

  const ReportsScreen({super.key, required this.rawHistory});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isGenerating = false;
  bool _showMockDataToggle = false;

  // Compute stats
  int get totalCattle => widget.rawHistory.map((item) => item['cow_id']).toSet().length;

  double get avgWeight {
    if (widget.rawHistory.isEmpty) return 0.0;
    final total = widget.rawHistory.fold<double>(0.0, (sum, item) => sum + (item['weight_kg'] as num? ?? 0.0).toDouble());
    return total / widget.rawHistory.length;
  }

  double get maxWeight {
    if (widget.rawHistory.isEmpty) return 0.0;
    return widget.rawHistory.fold<double>(0.0, (max, item) {
      final w = (item['weight_kg'] as num? ?? 0.0).toDouble();
      return w > max ? w : max;
    });
  }

  double get minWeight {
    if (widget.rawHistory.isEmpty) return 0.0;
    return widget.rawHistory.fold<double>(9999.0, (min, item) {
      final w = (item['weight_kg'] as num? ?? 0.0).toDouble();
      return w < min ? w : min;
    });
  }

  Future<File> _buildPDFFile() async {
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
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal800, width: 2)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('KisanPro Weight Intelligence',
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                      pw.Text('CATTLE WEIGHT ANALYTICS REPORT',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Generated: ${DateTime.now().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Scope: All Cattle', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Yield Summary section (mimicking the screenshot)
            pw.Text('Yield Summary', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPDFSummaryCard('TOTAL CATTLE', '$totalCattle'),
                _buildPDFSummaryCard('AVG WEIGHT', '${avgWeight.toStringAsFixed(1)} kg'),
                _buildPDFSummaryCard('HEAVIEST', '${maxWeight.toStringAsFixed(1)} kg'),
                _buildPDFSummaryCard('LIGHTEST', '${(minWeight == 9999.0 ? 0.0 : minWeight).toStringAsFixed(1)} kg'),
              ],
            ),
            pw.SizedBox(height: 24),

            // Table Header
            pw.Text('Weight Logbook Detailed Table',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
            pw.SizedBox(height: 8),

            // Table Content
            pw.TableHelper.fromTextArray(
              headers: ['Date & Time', 'Cattle ID', 'Cattle Name', 'Weight (kg)'],
              data: widget.rawHistory.map((item) {
                final date = item['timestamp'] ?? '';
                final cowId = item['cow_id'] ?? 'N/A';
                final name = item['name'] ?? 'Unnamed';
                final weight = (item['weight_kg'] as num? ?? 0.0).toStringAsFixed(1);
                return [date, cowId, name, '$weight kg'];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              cellAlignment: pw.Alignment.centerLeft,
              cellHeight: 22,
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
          ];
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/cattle_weight_report.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildPDFSummaryCard(String title, String value) {
    return pw.Container(
      width: 115,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
        ],
      ),
    );
  }

  Future<void> _sharePDF() async {
    setState(() => _isGenerating = true);
    try {
      final file = await _buildPDFFile();
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'KisanPro Cattle Weight Analytics Report');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateTime.now().toString().split(' ')[0];

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5), // Gray canvas background to highlight the PDF paper sheet
      appBar: AppBar(
        backgroundColor: const Color(0xFF006D60),
        foregroundColor: Colors.white,
        title: const Text('PDF Reports', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // White PDF Sheet Simulation Card
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 6,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'KisanPro Weight Intelligence',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                                ),
                                Text(
                                  'CATTLE WEIGHT ANALYTICS REPORT',
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Generated: $todayStr', style: const TextStyle(fontSize: 8)),
                              const Text('Scope: All Cattle', style: TextStyle(fontSize: 8)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFF006D60), thickness: 2),
                      const SizedBox(height: 16),

                      // Yield Summary UI Cards
                      const Text(
                        'Yield Summary',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildSummaryCard('TOTAL CATTLE', '$totalCattle')),
                          const SizedBox(width: 6),
                          Expanded(child: _buildSummaryCard('AVG WEIGHT', '${avgWeight.toStringAsFixed(1)} kg')),
                          const SizedBox(width: 6),
                          Expanded(child: _buildSummaryCard('HEAVIEST', '${maxWeight.toStringAsFixed(1)} kg')),
                          const SizedBox(width: 6),
                          Expanded(child: _buildSummaryCard('LIGHTEST', '${(minWeight == 9999.0 ? 0.0 : minWeight).toStringAsFixed(1)} kg')),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Logbook Table Title
                      const Text(
                        'Weight Logbook Detailed Table',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                      ),
                      const SizedBox(height: 8),

                      // Logbook Table
                      Table(
                        border: TableBorder.all(color: Colors.grey[300]!, width: 1),
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(1.0),
                          2: FlexColumnWidth(1.0),
                          3: FlexColumnWidth(0.8),
                        },
                        children: [
                          // Table Header
                          const TableRow(
                            decoration: BoxDecoration(color: Color(0xFF006D60)),
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Date & Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Cattle ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Cattle Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Weight', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                              ),
                            ],
                          ),
                          // Table Records
                          ...widget.rawHistory.map((item) {
                            final date = item['timestamp'] ?? '';
                            final cowId = item['cow_id'] ?? 'N/A';
                            final name = item['name'] ?? 'Unnamed';
                            final weight = (item['weight_kg'] as num? ?? 0.0).toStringAsFixed(1);
                            return TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(date, style: const TextStyle(fontSize: 8)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(cowId, style: const TextStyle(fontSize: 8)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(name, style: const TextStyle(fontSize: 8)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('$weight kg', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Panel mimicking the screenshot
          Container(
            color: const Color(0xFF006D60),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                // Print PDF Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _sharePDF,
                    icon: const Icon(Icons.print, color: Color(0xFF006D60), size: 18),
                    label: const Text(
                      'Print / Save',
                      style: TextStyle(color: Color(0xFF006D60), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Share PDF Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _sharePDF,
                    icon: const Icon(Icons.share, color: Colors.white, size: 18),
                    label: const Text(
                      'Share PDF',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[850],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Mock Toggle Switch
                Switch(
                  value: _showMockDataToggle,
                  onChanged: (val) {
                    setState(() {
                      _showMockDataToggle = val;
                    });
                  },
                  activeColor: Colors.white,
                  activeTrackColor: Colors.teal[900],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7E8),
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
          ),
        ],
      ),
    );
  }
}
