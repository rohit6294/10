import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/loading_overlay.dart';

class RegisterScreen extends StatefulWidget {
  final String role;
  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  // Common fields
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // Driver fields
  final _vehicleCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  // Hospital fields
  final _addressCtrl = TextEditingController();
  final _selectedSpecs = <String>{};

  static const _specializations = [
    'General', 'Trauma', 'Cardiac', 'Neuro', 'Pediatric', 'Burn', 'ICU',
  ];

  bool get _isDriver => widget.role == 'driver';

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (_isDriver) {
        await _authService.registerDriver(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          vehicleNumber: _vehicleCtrl.text.trim(),
          licenseNumber: _licenseCtrl.text.trim(),
        );
        if (!mounted) return;
        context.go('/driver/home');
      } else {
        await _authService.registerHospital(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          specializations: _selectedSpecs.toList(),
        );
        if (!mounted) return;
        context.go('/hospital/home');
      }
    } catch (e) {
      setState(() => _error = 'Registration failed: ${e.toString().split(']').last.trim()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _passCtrl,
        _vehicleCtrl, _licenseCtrl, _addressCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        backgroundColor: AppColors.lightBg,
        appBar: AppBar(
          title: Text(_isDriver ? 'Driver Registration' : 'Hospital Registration'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/auth/login/${widget.role}'),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(_nameCtrl, _isDriver ? 'Full Name' : 'Hospital Name',
                    Icons.person_outline),
                const SizedBox(height: 12),
                _field(_emailCtrl, 'Email', Icons.email_outlined,
                    type: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
                    type: TextInputType.phone),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 20),

                if (_isDriver) ...[
                  const Text('Vehicle Details',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy)),
                  const SizedBox(height: 12),
                  _field(_vehicleCtrl, 'Vehicle Number (e.g. WB01AB1234)',
                      Icons.directions_car_outlined),
                  const SizedBox(height: 12),
                  _field(_licenseCtrl, 'Driving License Number',
                      Icons.badge_outlined),
                ] else ...[
                  const Text('Hospital Details',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy)),
                  const SizedBox(height: 12),
                  _field(_addressCtrl, 'Full Address', Icons.location_on_outlined,
                      maxLines: 2),
                  const SizedBox(height: 16),
                  const Text('Specializations',
                      style: TextStyle(fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _specializations.map((s) {
                      final selected = _selectedSpecs.contains(s);
                      return FilterChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: (v) => setState(() {
                          if (v) _selectedSpecs.add(s);
                          else _selectedSpecs.remove(s);
                        }),
                        selectedColor: AppColors.accentBlue.withOpacity(0.15),
                        checkmarkColor: AppColors.accentBlue,
                      );
                    }).toList(),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.emergency.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.emergency.withOpacity(0.3)),
                    ),
                    child: Text(_error!,
                        style:
                            const TextStyle(color: AppColors.emergency)),
                  ),
                ],
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        context.go('/auth/login/${widget.role}'),
                    child: const Text('Already have an account? Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'Required' : null,
    );
  }
}
