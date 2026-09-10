import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _isObscure = true;

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final farmName = _farmNameController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || farmName.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formattedFarm = farmName.replaceAll(RegExp(r'\s+'), '_');
      final username = 'farm_${phone}_$formattedFarm';

      final success = await _apiService.login(username, password);
      if (success) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRegisterDialog() {
    final regPhoneController = TextEditingController();
    final regFarmNameController = TextEditingController();
    final regPasswordController = TextEditingController();
    bool isRegistering = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Register New Account',
                style: TextStyle(
                  color: Color(0xFF006D60),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: regPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: TextStyle(color: Color(0xFF006D60)),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF006D60)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: regFarmNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Farm Name',
                      labelStyle: TextStyle(color: Color(0xFF006D60)),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF006D60)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: regPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Color(0xFF006D60)),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF006D60)),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isRegistering ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isRegistering
                      ? null
                      : () async {
                          final phone = regPhoneController.text.trim();
                          final farm = regFarmNameController.text.trim();
                          final pass = regPasswordController.text.trim();
                          if (phone.isEmpty || farm.isEmpty || pass.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('All fields are required')),
                            );
                            return;
                          }
                          if (phone.length < 8 || int.tryParse(phone) == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid phone number')),
                            );
                            return;
                          }
                          setDialogState(() => isRegistering = true);
                          try {
                            final formattedFarm = farm.replaceAll(RegExp(r'\s+'), '_');
                            final user = 'farm_${phone}_$formattedFarm';
                            final success = await _apiService.register(user, pass);
                            if (success) {
                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Registration successful! Please log in.')),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                            );
                          } finally {
                            setDialogState(() => isRegistering = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006D60),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isRegistering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSettingsDialog() async {
    final currentUrl = await _apiService.getBaseUrl();
    final controller = TextEditingController(text: currentUrl);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAF7E8),
          title: const Text('Server Configuration', style: TextStyle(color: Color(0xFF006D60), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the Flask backend base URL:',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://192.168.x.x:5000',
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF006D60), width: 2),
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006D60),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await _apiService.setBaseUrl(controller.text);
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF006D60)),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon & Title Header
                const Icon(
                  Icons.analytics_outlined,
                  size: 80,
                  color: Color(0xFF006D60),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kisan Pro',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006D60),
                  ),
                ),
                const Text(
                  'Cattle Weight & 3D Reconstruction',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 48),

                // Card wrapping the inputs
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006D60),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Phone Number Field
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF006D60)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF006D60), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Farm Name Field
                        TextField(
                          controller: _farmNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Farm Name',
                            prefixIcon: const Icon(Icons.storefront_outlined, color: Color(0xFF006D60)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF006D60), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: _isObscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF006D60)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: const Color(0xFF006D60),
                              ),
                              onPressed: () => setState(() => _isObscure = !_isObscure),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF006D60), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Login Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006D60),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('New user? '),
                    GestureDetector(
                      onTap: _showRegisterDialog,
                      child: const Text(
                        'Register here',
                        style: TextStyle(
                          color: Color(0xFF006D60),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
