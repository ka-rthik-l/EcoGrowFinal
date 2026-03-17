import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_page.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _passwordError;
  bool _loading = false;

  void _validatePassword(String password) {
    setState(() {
      _passwordError = null;
      if (password.length < 8) {
        _passwordError = 'Password must be at least 8 characters long.';
      } else if (!password.contains(RegExp(r'[A-Z]'))) {
        _passwordError = 'Password must contain an uppercase letter.';
      } else if (!password.contains(RegExp(r'[a-z]'))) {
        _passwordError = 'Password must contain a lowercase letter.';
      } else if (!password.contains(RegExp(r'[0-9]'))) {
        _passwordError = 'Password must contain a number.';
      } else if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
        _passwordError = 'Password must contain a special character.';
      }
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    _validatePassword(_passwordController.text);
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _passwordError = 'Passwords do not match.');
    }
    if (_passwordError != null) return;

    setState(() => _loading = true);

    try {
      await ApiService().register(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access requested. Approved. Please authenticate.'),
          backgroundColor: Color(0xFF1B4332),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request failed: ${_parseError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      if (e.response?.data != null) {
        try {
          final detail = e.response!.data['detail'];
          if (detail is String) return detail;
          if (detail is List && detail.isNotEmpty) {
            return detail.first['msg']?.toString() ?? 'Validation error';
          }
        } catch (_) {}
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Helper for field labels
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- HEADER ---
                    const Text(
                      'Request Auditor Access',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'System registration requires an authoritative government or cooperative email address.',
                      style: TextStyle(color: Color(0xFF4B5563), height: 1.4),
                    ),

                    const SizedBox(height: 32),

                    // --- EMAIL ---
                    _buildLabel('Official Email'),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: 'admin@ecogrow.gov',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty || !value.contains('@')) {
                          return 'Valid official email required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // --- PASSWORD ---
                    _buildLabel('Strong Password'),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        errorText: _passwordError,
                        errorMaxLines: 2,
                      ),
                      onChanged: _validatePassword,
                    ),
                    const SizedBox(height: 20),

                    // --- CONFIRM PASSWORD ---
                    _buildLabel('Verify Password'),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icon(Icons.lock_outline, size: 20),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Mismatched verification password.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 40),

                    // --- SUBMIT ---
                    ElevatedButton(
                      onPressed: _loading ? null : _register,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit Request',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
