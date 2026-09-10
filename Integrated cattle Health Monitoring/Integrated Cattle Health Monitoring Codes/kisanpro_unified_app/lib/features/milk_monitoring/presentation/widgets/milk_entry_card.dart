import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../registry/providers/cattle_registry_provider.dart';
import '../../data/models/milk_record_model.dart';
import '../providers/milk_provider.dart';

class MilkEntryCard extends StatefulWidget {
  const MilkEntryCard({super.key});

  @override
  State<MilkEntryCard> createState() => _MilkEntryCardState();
}

class _MilkEntryCardState extends State<MilkEntryCard> {
  final _formKey = GlobalKey<FormState>();
  final _cattleNameController = TextEditingController();
  final _cattleIdController = TextEditingController();
  final _quantityController = TextEditingController();
  final _fatController = TextEditingController(text: "4.5");
  final _snfController = TextEditingController(text: "8.5");
  
  String _selectedSession = 'Morning';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_updatePricingPreview);
    _fatController.addListener(_updatePricingPreview);
    _snfController.addListener(_updatePricingPreview);
  }

  void _updatePricingPreview() {
    setState(() {});
  }

  @override
  void dispose() {
    _quantityController.removeListener(_updatePricingPreview);
    _fatController.removeListener(_updatePricingPreview);
    _snfController.removeListener(_updatePricingPreview);
    _cattleNameController.dispose();
    _cattleIdController.dispose();
    _quantityController.dispose();
    _fatController.dispose();
    _snfController.dispose();
    super.dispose();
  }

  void _submitEntry() {
    if (_formKey.currentState!.validate()) {
      final record = MilkRecordModel(
        cattleId: _cattleIdController.text.trim().toUpperCase(),
        cattleName: _cattleNameController.text.trim(),
        milkTime: _selectedSession,
        quantity: double.parse(_quantityController.text),
        fat: double.parse(_fatController.text),
        snf: double.parse(_snfController.text),
        timestamp: _selectedDate,
      );

      Provider.of<MilkProvider>(context, listen: false).addRecord(record);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Text("Milking log saved for ${record.cattleName}!"),
            ],
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      _cattleNameController.clear();
      _cattleIdController.clear();
      _quantityController.clear();
      setState(() {
        _fatController.text = "4.5";
        _snfController.text = "8.5";
        _selectedDate = DateTime.now();
      });
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: AppTheme.cardDecoration(
        isDark: isDark,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CATTLE SELECTION FROM REGISTRY
            Consumer<CattleRegistryProvider>(
              builder: (context, registry, child) {
                final cattles = registry.cattles;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "SELECT REGISTERED CATTLE",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.pets, size: 20, color: AppTheme.textMuted),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintText: "Choose registered cattle...",
                      ),
                      selectedItemBuilder: (BuildContext context) {
                        return cattles.map<Widget>((c) {
                          return Text(
                            "${c.name} (${c.cattleId}) - ${c.breed}",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 14),
                          );
                        }).toList();
                      },
                      items: cattles.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.cattleId,
                          child: Text(
                            "${c.name} (${c.cattleId}) - ${c.breed}",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (selectedId) {
                        if (selectedId != null) {
                          final selected = cattles.firstWhere((c) => c.cattleId == selectedId);
                          setState(() {
                            _cattleNameController.text = selected.name;
                            _cattleIdController.text = selected.cattleId;
                            _quantityController.text = selected.dailyMilkLiters.toStringAsFixed(1);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // CATTLE NAME
            const Text(
              "CATTLE NAME",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cattleNameController,
              decoration: const InputDecoration(
                hintText: "Enter cattle name",
                prefixIcon: Icon(Icons.badge, size: 20, color: AppTheme.textMuted),
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              validator: (val) => val == null || val.trim().isEmpty ? "Cattle name is required" : null,
            ),
            const SizedBox(height: 16),

            // CATTLE ID
            const Text(
              "CATTLE ID",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cattleIdController,
              decoration: const InputDecoration(
                hintText: "Enter cattle ID",
                prefixIcon: Icon(Icons.tag, size: 20, color: AppTheme.textMuted),
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              validator: (val) => val == null || val.trim().isEmpty ? "Cattle ID is required" : null,
            ),
            const SizedBox(height: 16),

            // MILKING TIME Toggle
            const Text(
              "MILKING TIME",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedSession = 'Morning';
                      _selectedDate = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                        6,
                        30,
                      );
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedSession == 'Morning' ? AppTheme.primary : (isDark ? AppTheme.surfaceDark : AppTheme.inputFillLight),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _selectedSession == 'Morning' ? Colors.transparent : AppTheme.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wb_sunny_outlined, color: _selectedSession == 'Morning' ? Colors.white : AppTheme.textMuted, size: 18),
                          const SizedBox(width: 8),
                          Text("Morning", style: TextStyle(color: _selectedSession == 'Morning' ? Colors.white : AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedSession = 'Evening';
                      _selectedDate = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                        18,
                        0,
                      );
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedSession == 'Evening' ? AppTheme.primary : (isDark ? AppTheme.surfaceDark : AppTheme.inputFillLight),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _selectedSession == 'Evening' ? Colors.transparent : AppTheme.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mode_night_outlined, color: _selectedSession == 'Evening' ? Colors.white : AppTheme.textMuted, size: 18),
                          const SizedBox(width: 8),
                          Text("Evening", style: TextStyle(color: _selectedSession == 'Evening' ? Colors.white : AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // MILKING DATE
            const Text(
              "MILKING DATE",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
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
                  setState(() {
                    _selectedDate = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      _selectedSession == 'Morning' ? 6 : 18,
                      30,
                    );
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : AppTheme.inputFillLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 20, color: AppTheme.textMuted),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_drop_down, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // QUANTITY IN LITERS
            const Text(
              "QUANTITY (LITERS)",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: "Enter milk quantity in lit",
                prefixIcon: Icon(Icons.opacity, size: 20, color: AppTheme.primary),
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              validator: (val) => val == null || double.tryParse(val) == null || double.parse(val) <= 0 ? "Enter valid quantity" : null,
            ),
            const SizedBox(height: 16),

            // DUAL INPUT GRID: FAT % & SNF %
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "FAT (%)",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _fatController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: "e.g. 4.5",
                          prefixIcon: Icon(Icons.percent, size: 16, color: AppTheme.textMuted),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        validator: (val) {
                          if (val == null || double.tryParse(val) == null) return "Enter fat";
                          final f = double.parse(val);
                          if (f < 1.0 || f > 15.0) return "1.0 - 15.0";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "SNF (%)",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _snfController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: "e.g. 8.5",
                          prefixIcon: Icon(Icons.analytics_outlined, size: 16, color: AppTheme.textMuted),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        validator: (val) {
                          if (val == null || double.tryParse(val) == null) return "Enter SNF";
                          final s = double.parse(val);
                          if (s < 5.0 || s > 12.0) return "5.0 - 12.0";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // DYNAMIC PRICING ESTIMATOR
            Consumer<MilkProvider>(
              builder: (context, provider, _) {
                final qty = double.tryParse(_quantityController.text) ?? 0.0;
                final fat = double.tryParse(_fatController.text) ?? 4.0;
                final snf = double.tryParse(_snfController.text) ?? 8.5;
                
                final rate = provider.calculateRate(fat, snf);
                final estTotal = rate * qty;
                
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.15), width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calculate_outlined, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "ESTIMATED RATE",
                                style: TextStyle(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                              Text(
                                "₹${rate.toStringAsFixed(2)}/L",
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            "ESTIMATED EARNINGS",
                            style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          Text(
                            "₹${estTotal.toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // SAVE ENTRY BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitEntry,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_outlined, size: 20),
                    SizedBox(width: 8),
                    Text("Save Milk Entry", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
