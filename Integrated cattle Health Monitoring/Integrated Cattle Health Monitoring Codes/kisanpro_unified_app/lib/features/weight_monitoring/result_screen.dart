import 'dart:io';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final bool isImperial;
  final File? sideImage;
  final File? backImage;

  const ResultScreen({
    super.key,
    required this.result,
    required this.isImperial,
    this.sideImage,
    this.backImage,
  });

  // Convert kg to lbs or keep as kg
  double _convertWeight(double kg) {
    return isImperial ? kg * 2.20462 : kg;
  }

  String get _weightUnit => isImperial ? 'lbs' : 'kg';

  @override
  Widget build(BuildContext context) {
    final double weight = (result['predicted_weight_kg'] as num).toDouble();
    final List<dynamic> confidence = result['confidence_range'] ?? [weight * 0.95, weight * 1.05];
    final double confLow = (confidence[0] as num).toDouble();
    final double confHigh = (confidence[1] as num).toDouble();

    final String? glbUrl = result['glb_url'];
    final String cowName = result['name'] ?? 'Unnamed Cattle';
    final String cowId = result['id'] ?? 'N/A';
    final String breed = result['breed'] ?? 'Unknown';
    final List<String> standardBreeds = ['gir', 'hf', 'jersey', 'sahiwal', 'ongole', 'hallikar', 'deoni', 'bargur', 'kankrej'];
    final String cleanedBreed = breed.trim().toLowerCase();
    final bool isOther = cleanedBreed.startsWith('other') || !standardBreeds.contains(cleanedBreed);

    final String section = result['section'] ?? 'General';
    final String modelUsed = result['model'] ?? 'Regressor';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006D60),
        foregroundColor: Colors.white,
        title: const Text('Estimation Results', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 3D Canvas / 2D Photo Fallback ──
            Container(
              height: 320,
              width: double.infinity,
              color: const Color(0xFFEEEBD8),
              child: glbUrl != null && glbUrl.isNotEmpty
                  ? ModelViewer(
                      src: glbUrl,
                      alt: '3D Cattle Model',
                      autoRotate: true,
                      cameraControls: true,
                      backgroundColor: const Color(0xFFEEEBD8),
                      shadowIntensity: 1.0,
                      ar: false,
                    )
                  : sideImage != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(sideImage!, fit: BoxFit.cover),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '3D Model unavailable. Showing 2D side profile fallback.',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.widgets_outlined, size: 48, color: Colors.black26),
                              SizedBox(height: 8),
                              Text('No visual model available', style: TextStyle(color: Colors.black38)),
                            ],
                          ),
                        ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Main Weight Card ──
                  Card(
                    elevation: 2,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ESTIMATED CATTLE WEIGHT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006D60),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black87),
                              children: [
                                TextSpan(
                                  text: _convertWeight(weight).toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900),
                                ),
                                TextSpan(
                                  text: ' $_weightUnit',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Confidence Range (±${isOther ? '8' : '5'}%): ${_convertWeight(confLow).toStringAsFixed(1)} - ${_convertWeight(confHigh).toStringAsFixed(1)} $_weightUnit',
                            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
                          ),
                          if (isOther) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Note: The results obtained for this breed are tentative.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.redAccent,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Metadata Footer Card ──
                  Card(
                    color: const Color(0xFFEBEAD8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$cowName ($breed)',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF006D60)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cattle ID: $cowId • Category: $section • AI: $modelUsed',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.bubble_chart, color: Color(0xFF006D60), size: 32),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Done Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF006D60), width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'BACK TO HOME',
                        style: TextStyle(color: Color(0xFF006D60), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
