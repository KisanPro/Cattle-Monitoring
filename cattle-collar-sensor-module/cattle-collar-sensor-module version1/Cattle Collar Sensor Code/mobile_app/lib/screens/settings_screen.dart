import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/cattle_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiService.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _applyServerUrl(String url) {
    setState(() {
      _urlController.text = url;
      ApiService.setBaseUrl(url);
    });
    context.read<CattleProvider>().refreshData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Target server switched to: $url'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.settings, color: Color(0xFF94A3B8), size: 24),
            SizedBox(width: 10),
            Text(
              'Server & IoT Gateway Config',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active Server Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACTIVE TELEMETRY INGESTION ENDPOINT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    hintText: 'http://15.206.32.94:5000',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Save & Reconnect'),
                        onPressed: () => _applyServerUrl(_urlController.text.trim()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Presets
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUICK ENVIRONMENT PRESETS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),
                _buildPresetTile(
                  name: 'AWS EC2 Production Server (Port 5000)',
                  url: 'http://15.206.32.94:5000',
                  subtitle: 'Live AWS Elastic IP Cloud Endpoint',
                  onSelect: () => _applyServerUrl('http://15.206.32.94:5000'),
                ),
                const Divider(color: Color(0xFF334155), height: 16),
                _buildPresetTile(
                  name: 'Android Emulator Localhost (10.0.2.2:5005)',
                  url: 'http://10.0.2.2:5005',
                  subtitle: 'Loopback proxy to host computer',
                  onSelect: () => _applyServerUrl('http://10.0.2.2:5005'),
                ),
                const Divider(color: Color(0xFF334155), height: 16),
                _buildPresetTile(
                  name: 'Local Dev Server (127.0.0.1:5005)',
                  url: 'http://127.0.0.1:5005',
                  subtitle: 'Direct localhost connection for desktop/web',
                  onSelect: () => _applyServerUrl('http://127.0.0.1:5005'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // IoT Hardware Spec Sheet
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONNECTED IOT HARDWARE STACK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                SizedBox(height: 12),
                Text('• Collar Microcontroller: ESP32 Master Node (Tag KA_1989)',
                    style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                SizedBox(height: 6),
                Text('• IMU Motion Sensor: LSM6DSOX 6-Axis (104 Hz Sampling)',
                    style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                SizedBox(height: 6),
                Text('• GNSS Module: Quectel L89 (NavIC / GPS / GLONASS)',
                    style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                SizedBox(height: 6),
                Text('• Long-Range Radio: SX1278 433MHz LoRa Transceiver (17 dBm)',
                    style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                SizedBox(height: 6),
                Text('• Battery Monitor: 12-bit ADC Voltage Divider (GPIO 35)',
                    style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetTile({
    required String name,
    required String url,
    required String subtitle,
    required VoidCallback onSelect,
  }) {
    final isCurrent = ApiService.baseUrl == url;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isCurrent ? const Color(0xFF10B981) : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
            Icon(
              isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isCurrent ? const Color(0xFF10B981) : const Color(0xFF64748B),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
