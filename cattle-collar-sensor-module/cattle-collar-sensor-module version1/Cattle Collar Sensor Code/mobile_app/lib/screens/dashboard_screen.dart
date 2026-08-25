import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cattle_provider.dart';
import '../models/cattle_model.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CattleProvider>();
    final cow = provider.selectedCow;
    final activeId = provider.activeBehaviorId;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light enterprise background matching web dashboard
      appBar: _buildEnterpriseHeader(context, provider, cow),
      body: provider.isLoading && provider.cattleList.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0B6E4F)),
            )
          : RefreshIndicator(
              color: const Color(0xFF0B6E4F),
              onRefresh: () => provider.refreshData(),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                children: [
                  // 1. Behavior Simulator Horizontal Chips
                  _buildBehaviorSimulator(context, provider, activeId),
                  const SizedBox(height: 12),

                  // 2. 21-Day ML Baseline Calibration Banner
                  _buildBaselineCalibrationCard(context, provider, cow),
                  const SizedBox(height: 14),

                  if (cow != null) ...[
                    // 3. Live Cattle Posture Visualizer Card with Photo & Status
                    _buildPostureVisualizerCard(context, cow, activeId),
                    const SizedBox(height: 14),

                    // 4. KPI Stat Metrics Grid
                    _buildKpiMetricsGrid(context, cow),
                    const SizedBox(height: 14),

                    // 5. Herd Health & Action Worklist
                    _buildHerdHealthWorklist(context, provider),
                  ] else ...[
                    _buildNoDataCard(provider),
                  ],
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildEnterpriseHeader(
      BuildContext context, CattleProvider provider, CattleModel? cow) {
    return AppBar(
      backgroundColor: const Color(0xFF044E36), // Deep enterprise forest green
      elevation: 2,
      titleSpacing: 12,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sensors, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KISAN PRO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Enterprise Livestock Telemetry',
                  style: TextStyle(fontSize: 10, color: Color(0xFFA7F3D0)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Live Status Badge
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF065F46),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF34D399), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: provider.isConnected ? const Color(0xFF34D399) : Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                provider.isConnected ? 'Live' : 'Syncing',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),

        // Battery Status Pill
        if (cow != null)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF065F46),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.battery_charging_full, size: 12, color: Color(0xFF34D399)),
                const SizedBox(width: 2),
                Text(
                  '${cow.batteryLevel}%',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        const SizedBox(width: 8),

        // Cattle Selector Dropdown Button
        PopupMenuButton<CattleModel>(
          icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.white),
          tooltip: 'Select Cattle Collar',
          onSelected: (selected) => provider.selectCow(selected),
          itemBuilder: (context) {
            return provider.cattleList.map((c) {
              return PopupMenuItem<CattleModel>(
                value: c,
                child: Row(
                  children: [
                    const Icon(Icons.pets, size: 16, color: Color(0xFF044E36)),
                    const SizedBox(width: 8),
                    Text(
                      '${c.cowId} • ${c.name} (${c.breed})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        ),
      ],
    );
  }

  Widget _buildBehaviorSimulator(
      BuildContext context, CattleProvider provider, int activeId) {
    final behaviors = [
      {'id': 1, 'label': 'Standing', 'color': const Color(0xFF065F46)},
      {'id': 7, 'label': 'Grazing', 'color': const Color(0xFF0D9488)},
      {'id': 4, 'label': 'Lying', 'color': const Color(0xFF0284C7)},
      {'id': 2, 'label': 'Walking', 'color': const Color(0xFF2563EB)},
      {'id': 6, 'label': 'Head Shake', 'color': const Color(0xFF7C3AED)},
      {'id': 3, 'label': 'Super-Active (Estrus)', 'color': const Color(0xFFDB2777)},
      {'id': 5, 'label': 'Fall Alert', 'color': const Color(0xFFDC2626)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BEHAVIOR SIMULATOR & OVERRIDE:',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: behaviors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final b = behaviors[index];
              final isSelected = activeId == (b['id'] as int);
              final color = b['color'] as Color;

              return InkWell(
                onTap: () => provider.setSimulatedBehavior(b['id'] as int),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? color : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    b['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBaselineCalibrationCard(
      BuildContext context, CattleProvider provider, CattleModel? cow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: Color(0xFF044E36), size: 10),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '21-Day ML Baseline Calibration: Day ${provider.baselineDay} of 21 - Learning ${cow?.name ?? "Ganga"}\'s Normal Patterns (5%)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => provider.recalibrateBaseline(),
                child: const Row(
                  children: [
                    Icon(Icons.refresh, size: 14, color: Color(0xFF044E36)),
                    SizedBox(width: 2),
                    Text(
                      'Recalibrate',
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
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: provider.baselineProgress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              color: const Color(0xFF044E36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostureVisualizerCard(
      BuildContext context, CattleModel cow, int activeId) {
    String imageAsset = 'assets/cow_standing.png';
    String stateTitle = 'Standing Alert';
    String stateDescription = 'Calm posture in pasture field - ${cow.breed} (${cow.lactationStage})';

    switch (activeId) {
      case 0:
        imageAsset = 'assets/cow_standing.png';
        stateTitle = 'IMU Sensor Fault';
        stateDescription = 'Sensor disconnected or I2C communication error.';
        break;
      case 1:
        imageAsset = 'assets/cow_standing.png';
        stateTitle = 'Standing Alert';
        stateDescription = 'Calm upright posture in pasture field.';
        break;
      case 2:
        imageAsset = 'assets/cow_walking.png';
        stateTitle = 'Walking / Kinetic Steps';
        stateDescription = 'Steady movement across grazing pasture.';
        break;
      case 3:
        imageAsset = 'assets/cow_walking.png';
        stateTitle = 'Super-Active (Estrus)';
        stateDescription = 'High step count surge (+185% baseline). Insemination window open!';
        break;
      case 4:
        imageAsset = 'assets/cow_lying.png';
        stateTitle = 'Lying / Rumination';
        stateDescription = 'Resting in shaded quadrant. Rumination active.';
        break;
      case 5:
        imageAsset = 'assets/cow_fall.png';
        stateTitle = 'FALL / INJURY EMERGENCY';
        stateDescription = 'Sudden impact spike (>25m/s²) followed by lying.';
        break;
      case 6:
        imageAsset = 'assets/cow_headshake.png';
        stateTitle = 'Head Shake / Irritation';
        stateDescription = 'High rotational gyro jerk. Checking for fly irritation.';
        break;
      case 7:
        imageAsset = 'assets/cow_grazing.png';
        stateTitle = 'Grazing / Feeding';
        stateDescription = 'Downward neck tilt (-35°) and slow feeding pace.';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LIVE CATTLE POSTURE VISUALIZER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF044E36),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF044E36),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stateTitle.split(' ').first,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Realistic Cow Posture Photo with Gradient Overlay
          Stack(
            children: [
              ClipRRect(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE2E8F0),
                      child: const Center(
                        child: Icon(Icons.pets, size: 48, color: Color(0xFF044E36)),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom status banner overlay (as seen in web dashboard)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF044E36).withOpacity(0.88),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Cattle Posture: $stateTitle — ${cow.name} (@${cow.cowId})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stateDescription,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFA7F3D0),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsGrid(BuildContext context, CattleModel cow) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiTile(
                title: 'DISTANCE TO CATTLE',
                value: '196 m away',
                icon: Icons.near_me,
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiTile(
                title: 'DAILY MOVEMENT',
                value: '${cow.totalSteps} steps',
                icon: Icons.directions_walk,
                iconColor: const Color(0xFF0D9488),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildKpiTile(
                title: 'ACTIVE TIME',
                value: '6.5 hrs',
                icon: Icons.schedule,
                iconColor: const Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiTile(
                title: 'HEALTH SCORE',
                value: '98% OPTIMAL',
                icon: Icons.favorite,
                iconColor: const Color(0xFF044E36),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COLLAR BATTERY & POWER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.battery_charging_full, size: 16, color: Color(0xFF044E36)),
                  const SizedBox(width: 4),
                  Text(
                    '${cow.batteryLevel}% • ${cow.batteryStatus}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF044E36),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              Icon(icon, size: 14, color: iconColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHerdHealthWorklist(BuildContext context, CattleProvider provider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HERD HEALTH & ACTION WORKLIST',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF044E36),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${provider.unacknowledgedAlertsCount} active',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.alertsList.isEmpty || provider.unacknowledgedAlertsCount == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No alerts yet. Herd is calm.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.alertsList.take(3).length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final alert = provider.alertsList[index];
                return Row(
                  children: [
                    Icon(
                      alert.isCritical ? Icons.error : Icons.warning_amber,
                      color: alert.isCritical ? Colors.red : Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert.message,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard(CattleProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 40, color: Color(0xFF044E36)),
          const SizedBox(height: 10),
          const Text('Connecting to AWS Livestock Server...'),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF044E36)),
            onPressed: () => provider.refreshData(),
            child: const Text('Retry Connection', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
