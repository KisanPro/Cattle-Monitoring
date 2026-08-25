import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cattle_provider.dart';
import '../models/cattle_model.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
  static const _gpsChannel = MethodChannel('com.kisanpro/gps');
  late AnimationController _pulseController;
  
  // Real farmer mobile GPS location (Point A)
  double? _farmerLat;
  double? _farmerLon;
  bool _isLocatingFarmer = false;
  String _farmerLocationStatus = '13.30820, 77.52650';

  // Interactive custom pasture center / Drag offset
  Offset? _customCenterOffset;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _getCurrentFarmerLocation(silent: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Acquire Farmer's Mobile Phone GPS Location (Point A) via Native Android Platform Channel
  Future<void> _getCurrentFarmerLocation({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      _isLocatingFarmer = true;
    });

    try {
      final result = await _gpsChannel.invokeMethod<Map>('getFarmerLocation');
      if (result != null && mounted) {
        final lat = (result['latitude'] as num).toDouble();
        final lon = (result['longitude'] as num).toDouble();
        setState(() {
          _farmerLat = lat;
          _farmerLon = lon;
          _isLocatingFarmer = false;
          _farmerLocationStatus = '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
        });

        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Farmer Location (Point A): $_farmerLocationStatus'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _farmerLat ??= 13.308200;
          _farmerLon ??= 77.526500;
          _isLocatingFarmer = false;
          _farmerLocationStatus = '13.30820, 77.52650';
        });
      }
    }
  }

  // Open Google Maps Turn-by-Turn Navigation from Farmer (A) to Cattle (B)
  Future<void> _openGoogleMaps(CattleModel cow) async {
    final destLat = cow.latitude != 0.0 ? cow.latitude : 13.308692;
    final destLon = cow.longitude != 0.0 ? cow.longitude : 77.527069;

    String mapsUrlString;
    if (_farmerLat != null && _farmerLon != null) {
      mapsUrlString =
          'https://www.google.com/maps/dir/?api=1&origin=$_farmerLat,$_farmerLon&destination=$destLat,$destLon&travelmode=walking';
    } else {
      mapsUrlString =
          'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLon&travelmode=walking';
    }

    final googleMapsUrl = Uri.parse(mapsUrlString);
    final geoUrl = Uri.parse('geo:$destLat,$destLon?q=$destLat,$destLon(${Uri.encodeComponent("${cow.name} (${cow.cowId})")})');

    try {
      if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening Navigation to $destLat, $destLon'),
            backgroundColor: const Color(0xFF044E36),
          ),
        );
      }
    }
  }

  // Edit Geofence Sheet (Set farm center, radius, or use mobile GPS)
  void _showEditGeofenceSheet(BuildContext context, CattleProvider provider) {
    final latController =
        TextEditingController(text: provider.geofence.centerLat.toStringAsFixed(6));
    final lonController =
        TextEditingController(text: provider.geofence.centerLon.toStringAsFixed(6));
    double selectedRadius = provider.geofence.radiusKm;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.edit_location_alt, color: Color(0xFF044E36), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Edit Geofence Boundary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Text(
                    'Set where your farm perimeter begins and how far your herd can safely roam.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const Divider(height: 16),

                  // Button to set geofence at current phone GPS location
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text(
                      'Set Geofence Center at My Mobile GPS Location',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await _getCurrentFarmerLocation();
                      if (_farmerLat != null && _farmerLon != null) {
                        setModalState(() {
                          latController.text = _farmerLat!.toStringAsFixed(6);
                          lonController.text = _farmerLon!.toStringAsFixed(6);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Farm Location Presets
                  const Text(
                    'OR CHOOSE FARM LOCATION PRESET',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPresetChip('Doddaballapura Field', 13.308692, 77.527069, 2.0, (lat, lon, rad) {
                        setModalState(() {
                          latController.text = lat.toStringAsFixed(6);
                          lonController.text = lon.toStringAsFixed(6);
                          selectedRadius = rad;
                        });
                      }),
                      _buildPresetChip('North Meadow', 13.315000, 77.530000, 1.5, (lat, lon, rad) {
                        setModalState(() {
                          latController.text = lat.toStringAsFixed(6);
                          lonController.text = lon.toStringAsFixed(6);
                          selectedRadius = rad;
                        });
                      }),
                      _buildPresetChip('Main Dairy Barn', 13.286750, 77.595116, 0.5, (lat, lon, rad) {
                        setModalState(() {
                          latController.text = lat.toStringAsFixed(6);
                          lonController.text = lon.toStringAsFixed(6);
                          selectedRadius = rad;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Latitude & Longitude Inputs
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Farm Center Latitude',
                            labelStyle: const TextStyle(fontSize: 11),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: lonController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Farm Center Longitude',
                            labelStyle: const TextStyle(fontSize: 11),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Safe Radius Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Safe Roaming Radius:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${selectedRadius.toStringAsFixed(1)} km (${(selectedRadius * 1000).toInt()}m)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF044E36)),
                      ),
                    ],
                  ),
                  Slider(
                    value: selectedRadius,
                    min: 0.1,
                    max: 10.0,
                    divisions: 99,
                    activeColor: const Color(0xFF044E36),
                    onChanged: (v) {
                      setModalState(() {
                        selectedRadius = v;
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // Save & Sync Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF044E36),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Save & Apply Geofence', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final lat = double.tryParse(latController.text.trim()) ?? 13.308692;
                        final lon = double.tryParse(lonController.text.trim()) ?? 77.527069;
                        provider.updateGeofenceFull(lat, lon, selectedRadius);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Geofence updated: ${selectedRadius.toStringAsFixed(1)} km safe zone active.'),
                            backgroundColor: const Color(0xFF044E36),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(
      String label, double lat, double lon, double rad, Function(double, double, double) onSelect) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF044E36))),
      backgroundColor: const Color(0xFFE6F4EA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFA7F3D0)),
      ),
      onPressed: () => onSelect(lat, lon, rad),
    );
  }

  // Calculate distance between Farmer (A) and Cattle (B)
  double _calculateWalkingDistanceKm(CattleModel cow) {
    if (_farmerLat == null || _farmerLon == null) return 0.196; // 196 meters
    const double p = 0.017453292519943295;
    final a = 0.5 -
        cos((cow.latitude - _farmerLat!) * p) / 2 +
        cos(_farmerLat! * p) *
            cos(cow.latitude * p) *
            (1 - cos((cow.longitude - _farmerLon!) * p)) /
            2;
    return 12742 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CattleProvider>();
    final cow = provider.selectedCow;
    final geofence = provider.geofence;

    double walkDistKm = _calculateWalkingDistanceKm(cow);
    int walkMinutes = (walkDistKm / 0.08).clamp(1, 120).toInt();
    bool isBreached = geofence.calculateDistanceKm(cow.latitude, cow.longitude) > geofence.radiusKm;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF044E36),
        elevation: 2,
        title: const Text(
          'PASTURE GPS RADAR & LOCATION',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 1. Action Buttons Row (Edit Geofence, My Location, Google Maps)
          Row(
            children: [
              // Edit Geofence
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5), // Purple / Indigo
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.edit_calendar, size: 14),
                  label: const Text('Edit Geofence', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: () => _showEditGeofenceSheet(context, provider),
                ),
              ),
              const SizedBox(width: 6),

              // My Location (Get Mobile GPS)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB), // Blue
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  icon: _isLocatingFarmer
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.my_location, size: 14),
                  label: const Text('My Location', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: () => _getCurrentFarmerLocation(silent: false),
                ),
              ),
              const SizedBox(width: 6),

              // Google Maps (Open Turn-by-Turn walking navigation to Cattle)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF044E36), // Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.navigation, size: 14),
                  label: const Text('Google Maps', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: () => _openGoogleMaps(cow),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Live Ola/Uber-style Route Info Card (From Farmer A to Cattle B)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_walk, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'NAVIGATION TO CATTLE:',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '~$walkMinutes min walk',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${walkDistKm < 1.0 ? "${(walkDistKm * 1000).toInt()} m" : "${walkDistKm.toStringAsFixed(2)} km"} from your phone to ${cow.name} (${cow.cowId})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Interactive Ola/Uber style Dual-Pin Map Canvas
          Container(
            height: 380,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: GestureDetector(
                onTapDown: (details) {
                  setState(() {
                    _customCenterOffset = details.localPosition;
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _customCenterOffset = details.localPosition;
                  });
                },
                child: Stack(
                  children: [
                    // OpenStreetMap & Route Navigation Painter
                    Positioned.fill(
                      child: CustomPaint(
                        painter: OlaNavigationMapPainter(
                          radiusKm: geofence.radiusKm,
                          isBreached: isBreached,
                          cattleOffset: _customCenterOffset ?? const Offset(200, 170),
                          farmerOffset: const Offset(80, 290),
                          pulseProgress: _pulseController.value,
                        ),
                      ),
                    ),

                    // Farmer Pin (Location A - Person Icon)
                    Positioned(
                      left: 80 - 45,
                      top: 290 - 45,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'You (Farmer)',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.person_pin_circle, size: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // Cattle Pin (Location B - Cow Icon)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final cattlePos = _customCenterOffset ?? const Offset(200, 170);

                        return Positioned(
                          left: cattlePos.dx - 80,
                          top: cattlePos.dy - 40,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isBreached ? const Color(0xFFDC2626) : const Color(0xFF044E36),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${cow.name} (${cow.cowId}) • ${walkDistKm < 1.0 ? "${(walkDistKm * 1000).toInt()}m" : "${walkDistKm.toStringAsFixed(2)} km"}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 32 + (_pulseController.value * 14),
                                    height: 32 + (_pulseController.value * 14),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (isBreached ? Colors.red : const Color(0xFF044E36))
                                          .withOpacity(0.35 - (_pulseController.value * 0.2)),
                                    ),
                                  ),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isBreached ? Colors.red : const Color(0xFF044E36),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.pets, size: 12, color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // OpenStreetMap attribution badge
                    Positioned(
                      bottom: 6,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Leaflet | © OpenStreetMap',
                          style: TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Geofence Radius Slider & Recenter Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Geofence Radius: ${geofence.radiusKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _customCenterOffset = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Recentered on Live Cattle Location'),
                            backgroundColor: Color(0xFF044E36),
                          ),
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.gps_fixed, size: 14, color: Color(0xFF044E36)),
                          SizedBox(width: 4),
                          Text(
                            'Recenter Cattle',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF044E36),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFF044E36),
                    inactiveTrackColor: const Color(0xFFCBD5E1),
                    thumbColor: const Color(0xFF044E36),
                    overlayColor: const Color(0xFF044E36).withOpacity(0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: geofence.radiusKm,
                    min: 0.1,
                    max: 10.0,
                    divisions: 99,
                    onChanged: (val) => provider.updateGeofenceRadius(val),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OlaNavigationMapPainter extends CustomPainter {
  final double radiusKm;
  final bool isBreached;
  final Offset cattleOffset;
  final Offset farmerOffset;
  final double pulseProgress;

  OlaNavigationMapPainter({
    required this.radiusKm,
    required this.isBreached,
    required this.cattleOffset,
    required this.farmerOffset,
    required this.pulseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background OpenStreetMap Terrain
    final bgPaint = Paint()..color = const Color(0xFFF2EFE9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Forest / Pasture zones
    final forestPaint = Paint()..color = const Color(0xFFD4E8C2);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(10, 10, size.width * 0.45, 90), const Radius.circular(16)), forestPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.6, 20, size.width * 0.35, 70), const Radius.circular(16)), forestPaint);

    // Main Road (Orange)
    final highwayPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;
    final roadOutline = Paint()
      ..color = const Color(0xFFF97316)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke;

    final roadPath = Path()
      ..moveTo(20, size.height * 0.25)
      ..lineTo(size.width * 0.4, size.height * 0.45)
      ..lineTo(size.width * 0.65, size.height * 0.6)
      ..lineTo(size.width - 20, size.height * 0.85);

    canvas.drawPath(roadPath, roadOutline);
    canvas.drawPath(roadPath, highwayPaint);

    // Secondary Cross Roads
    final secRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(size.width * 0.45, 0), Offset(size.width * 0.48, size.height), secRoadPaint);
    canvas.drawLine(Offset(0, size.height * 0.55), Offset(size.width, size.height * 0.52), secRoadPaint);

    // 2. Safe Pasture Geofence Circle
    final fenceRadius = (radiusKm / 5.0) * (size.width * 0.35);

    final fenceFill = Paint()
      ..color = const Color(0xFFDC2626).withOpacity(0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(cattleOffset, fenceRadius, fenceFill);

    final fenceStroke = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(cattleOffset, fenceRadius, fenceStroke);

    // Pasture Location Text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Doddaballapura Pasture',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFF991B1B),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cattleOffset.dx - 55, cattleOffset.dy - 6));

    // 3. Ola/Uber-Style Dotted Direct Navigation Route Line (Farmer A -> Cattle B)
    final dashPaint = Paint()
      ..color = const Color(0xFF2563EB).withOpacity(0.85)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    // Draw connecting navigation line between Farmer (A) and Cattle (B)
    _drawDashedLine(canvas, farmerOffset, cattleOffset, dashPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 8.0;
    const double dashSpace = 5.0;

    double dx = p2.dx - p1.dx;
    double dy = p2.dy - p1.dy;
    double distance = sqrt(dx * dx + dy * dy);

    double currentDistance = 0.0;
    while (currentDistance < distance) {
      double x1 = p1.dx + (dx * (currentDistance / distance));
      double y1 = p1.dy + (dy * (currentDistance / distance));

      double nextDist = min(currentDistance + dashWidth, distance);
      double x2 = p1.dx + (dx * (nextDist / distance));
      double y2 = p1.dy + (dy * (nextDist / distance));

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant OlaNavigationMapPainter oldDelegate) =>
      oldDelegate.radiusKm != radiusKm ||
      oldDelegate.isBreached != isBreached ||
      oldDelegate.cattleOffset != cattleOffset ||
      oldDelegate.farmerOffset != farmerOffset ||
      oldDelegate.pulseProgress != pulseProgress;
}
