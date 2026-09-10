import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/farmer_auth_provider.dart';
import '../../../main_navigation_screen.dart';

class FarmerLoginScreen extends StatefulWidget {
  const FarmerLoginScreen({super.key});

  @override
  State<FarmerLoginScreen> createState() => _FarmerLoginScreenState();
}

class _FarmerLoginScreenState extends State<FarmerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController(text: '8088032780');
  final _nameController = TextEditingController(text: 'Shri Basavaraj');
  final _farmNameController = TextEditingController(text: 'Samruddhi Dairy & Livestock Farm');
  final _farmIdController = TextEditingController(text: '8088032780_Samruddhi_Farm');

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _farmNameController.dispose();
    _farmIdController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      context.read<FarmerAuthProvider>().login(
            phone: _phoneController.text.trim(),
            farmerName: _nameController.text.trim(),
            farmId: _farmIdController.text.trim(),
            farmName: _farmNameController.text.trim(),
          );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // KisanPro Brand Header
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.agriculture,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'KisanPro Cattle Health',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const Text(
                  'Farmer Portal & Multi-Module Cattle System',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),

                // Login Form Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0E7E5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Farmer Sign In',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B2D2A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter your farm registration credentials to access unified cattle data',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 20),

                        // Farmer Phone
                        const Text('Farmer Mobile Number',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                            hintText: 'e.g. 8088032780',
                          ),
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Mobile number required' : null,
                        ),
                        const SizedBox(height: 14),

                        // Farmer Name
                        const Text('Farmer / Owner Name',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                            hintText: 'e.g. Shri Basavaraj',
                          ),
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Farmer name required' : null,
                        ),
                        const SizedBox(height: 14),

                        // Farm ID
                        const Text('Farm ID / Tenancy Key',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _farmIdController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.tag, size: 20),
                            hintText: 'e.g. 8088032780_Samruddhi_Farm',
                          ),
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Farm ID required' : null,
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Sign In to Farm Dashboard',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Connected Modules: AI Health 360° • Milk Yield • Vaccination • Weight & 3D',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
