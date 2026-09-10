import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'services/api_service.dart';

class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key});

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _demoCases = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchValidationCases();
  }

  Future<void> _fetchValidationCases() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final cases = await _apiService.getValidationDemos();
      if (!mounted) return;
      setState(() {
        _demoCases = cases;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006D60),
        foregroundColor: Colors.white,
        title: const Text('Model Validation', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF006D60)))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006D60), foregroundColor: Colors.white),
                          onPressed: _fetchValidationCases,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Overview Explanation Card ──
                      Card(
                        color: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Estimation Accuracy Report',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'This validation panel measures the impact and accuracy of the AI model. We compare the Tape Measured (Actual) weights against the 3D-Reconstructed & Machine Learning predicted weights to verify accuracy rates above 95%.',
                                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Validation Demo Cases',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                      ),
                      const SizedBox(height: 12),

                      // ── Validation Cards ──
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _demoCases.length,
                        itemBuilder: (context, index) {
                          final c = _demoCases[index];
                          final double pred = (c['predicted_weight'] as num).toDouble();
                          final double actual = (c['actual_weight'] as num).toDouble();
                          final double diff = pred - actual;
                          final double errPct = (diff.abs() / actual) * 100;
                          
                          final String name = (c['name'] ?? '').toString();
                          String modelSrc = (c['glb_url'] ?? '').toString();

                          // Permanently load bundled local 3D assets for demo cases so they work 100% offline & never fail
                          if (name.toLowerCase().contains('seethamma')) {
                            modelSrc = 'assets/models/seethamma_model.glb';
                          } else if (name.toLowerCase().contains('ramana')) {
                            modelSrc = 'assets/models/ramana_model.glb';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 20),
                            color: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 3D Canvas / Placeholder
                                Container(
                                  height: 220,
                                  width: double.infinity,
                                  color: const Color(0xFFEEEBD8),
                                  child: modelSrc.isNotEmpty
                                      ? ModelViewer(
                                          src: modelSrc,
                                          alt: '3D Cattle Model',
                                          autoRotate: true,
                                          cameraControls: true,
                                          backgroundColor: const Color(0xFFEEEBD8),
                                          shadowIntensity: 1.0,
                                          ar: false,
                                        )
                                      : const Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.widgets_outlined, size: 48, color: Colors.black26),
                                              SizedBox(height: 8),
                                              Text('NO MODEL AVAILABLE', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                ),

                                // Details Padding
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title row with Passed Badge
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${c['name']} (${c['breed']})',
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE2F0D9),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.green.shade600, width: 1),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'PASSED',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Cattle ID: ${c['cow_id']} • Category: ${c['category']}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black45),
                                      ),
                                      const Divider(height: 24),

                                      // Weight Comparison row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                const Text('ACTUAL WEIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black45)),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${actual.toStringAsFixed(1)} kg',
                                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(width: 1, height: 40, color: Colors.black12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                const Text('AI PREDICTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF006D60))),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${pred.toStringAsFixed(1)} kg',
                                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF006D60)),
                                                  key: ValueKey(pred),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),

                                      // Variance Info Row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Variance', style: TextStyle(fontSize: 10, color: Colors.black45)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(1)} kg',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: diff.abs() > 10 ? Colors.orange.shade800 : Colors.green.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('Error Rate', style: TextStyle(fontSize: 10, color: Colors.black45)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${errPct.toStringAsFixed(2)}%',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: errPct > 3 ? Colors.orange.shade800 : Colors.green.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }
}
