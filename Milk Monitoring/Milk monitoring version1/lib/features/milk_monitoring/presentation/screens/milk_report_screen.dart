import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/milk_record_model.dart';
import '../providers/milk_provider.dart';

class MilkReportScreen extends StatefulWidget {
  const MilkReportScreen({super.key});

  @override
  State<MilkReportScreen> createState() => _MilkReportScreenState();
}

class _MilkReportScreenState extends State<MilkReportScreen> {
  String? _selectedCattle; // null means "All Cattle"

  Future<Uint8List> _generatePdf(
    PdfPageFormat format,
    List<MilkRecordModel> records,
    MilkProvider provider,
    double totalProduction,
    double morningTotal,
    double eveningTotal,
    double avgDaily,
    String bestDay,
  ) async {
    final pdf = pw.Document(title: "KisanPro Milk Production Report");

    // Header theme colors
    final primaryColor = PdfColor.fromInt(AppTheme.primary.value);
    final textMutedColor = PdfColor.fromInt(AppTheme.textMuted.value);
    
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    // Advanced metrics
    double totalRevenue = 0.0;
    for (final r in records) {
      final rate = provider.calculateRate(r.fat, r.snf);
      totalRevenue += rate * r.quantity;
    }
    double totalFatQty = records.fold(0.0, (s, r) => s + (r.fat * r.quantity));
    double totalSnfQty = records.fold(0.0, (s, r) => s + (r.snf * r.quantity));
    double weightedAvgFat = totalProduction > 0 ? totalFatQty / totalProduction : 4.2;
    double weightedAvgSnf = totalProduction > 0 ? totalSnfQty / totalProduction : 8.5;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _selectedCattle != null ? "$_selectedCattle Yield Report" : "KisanPro Dairy Intelligence",
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.Text(
                    _selectedCattle != null ? "SPECIFIC CATTLE PERFORMANCE HISTORY" : "MILK PRODUCTION ANALYTICS REPORT",
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                      color: textMutedColor,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "Generated: ${dateFormat.format(DateTime.now())}",
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    "Scope: ${_selectedCattle ?? 'All Cattle'}",
                    style: pw.TextStyle(fontSize: 10, color: textMutedColor),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 20),

          // SUMMARY METRIC TILES
          pw.Text(
            "Yield Summary",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfSummaryTile("TOTAL YIELD", "${totalProduction.toStringAsFixed(1)} L", primaryColor),
              _buildPdfSummaryTile("TOTAL REVENUE", "INR ${totalRevenue.toStringAsFixed(1)}", primaryColor),
              _buildPdfSummaryTile("WEIGHTED FAT", "${weightedAvgFat.toStringAsFixed(2)}%", primaryColor),
              _buildPdfSummaryTile("WEIGHTED SNF", "${weightedAvgSnf.toStringAsFixed(2)}%", primaryColor),
            ],
          ),
          pw.SizedBox(height: 30),

          // RECORD TABLES
          pw.Text(
            "Milking Logbook Detailed Table",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ["Date & Time", "Cattle Name", "Session", "Yield (L)", "FAT/SNF (%)", "Rate (INR/L)", "Earnings (INR)"],
            data: List<List<String>>.generate(
              records.length,
              (index) {
                final r = records[index];
                final rate = provider.calculateRate(r.fat, r.snf);
                final earnings = rate * r.quantity;
                return [
                  "${dateFormat.format(r.timestamp)} ${timeFormat.format(r.timestamp)}",
                  r.cattleName,
                  r.milkTime,
                  "${r.quantity.toStringAsFixed(1)} L",
                  "${r.fat.toStringAsFixed(1)}% / ${r.snf.toStringAsFixed(1)}%",
                  "Rs ${rate.toStringAsFixed(2)}",
                  "Rs ${earnings.toStringAsFixed(2)}",
                ];
              },
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfSummaryTile(String label, String value, PdfColor themeColor) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            maxLines: 1,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: themeColor),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MilkProvider>(context);
    
    // Get unique cattle list
    final uniqueCattle = provider.records
        .map((r) => r.cattleName)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    
    // Filter records by search filters and selected cattle
    List<MilkRecordModel> records = provider.filteredRecords;
    if (_selectedCattle != null && _selectedCattle != "All Cattle") {
      records = records.where((r) => r.cattleName.toLowerCase() == _selectedCattle!.toLowerCase()).toList();
    }
    
    // Aggregate analytics specifically for this subset of records
    final total = records.fold(0.0, (sum, r) => sum + r.quantity);
    final morning = records.where((r) => r.milkTime == 'Morning').fold(0.0, (sum, r) => sum + r.quantity);
    final evening = records.where((r) => r.milkTime == 'Evening').fold(0.0, (sum, r) => sum + r.quantity);
    
    final dailyTotals = <String, double>{};
    for (final r in records) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.timestamp);
      dailyTotals[dateStr] = (dailyTotals[dateStr] ?? 0.0) + r.quantity;
    }
    final daysCount = dailyTotals.length;
    final double avg = daysCount > 0 ? total / daysCount : 0.0;
    
    String bestDay = 'N/A';
    double maxQty = 0.0;
    final weekdays = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    dailyTotals.forEach((dateStr, qty) {
      if (qty > maxQty) {
        maxQty = qty;
        final date = DateTime.parse(dateStr);
        bestDay = weekdays[date.weekday];
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Cattle Selector Dropdown Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark.withOpacity(0.4) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.pets_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                const Text(
                  "Select Cattle:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : AppTheme.inputFillLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCattle ?? "All Cattle",
                        isExpanded: true,
                        dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
                        items: ["All Cattle", ...uniqueCattle].map((name) {
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCattle = val == "All Cattle" ? null : val;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _selectedCattle != null
                              ? "No milking logs found for $_selectedCattle."
                              : "No milking logs match active filter query.",
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                : PdfPreview(
                    build: (format) => _generatePdf(
                      format,
                      records,
                      provider,
                      total,
                      morning,
                      evening,
                      avg,
                      bestDay,
                    ),
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primary)),
                    ),
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    pdfFileName: _selectedCattle != null 
                        ? "KisanPro_${_selectedCattle}_Milk_Report.pdf"
                        : "KisanPro_Milk_Report.pdf",
                  ),
          ),
        ],
      ),
    );
  }
}
