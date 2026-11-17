import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const Color navy = Color(0xFF101D45);
  static const Color blue = Color(0xFF2449A5);
  static const Color background = Color(0xFFF5F7FC);
  static const Color borderColor = Color(0xFFE2E7F0);
  static const Color mutedText = Color(0xFF727D92);
  static const Color errorRed = Color(0xFFD32F2F);

  final _formKey = GlobalKey<FormState>();

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  bool _submitted = false;
  bool _saving = false;
  final FreelanceApi _api = FreelanceApi();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _api.dispose();
    super.dispose();
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your current password.';
    }

    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a new password.';
    }

    if (value.length < 8) {
      return 'Password must contain at least 8 characters.';
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return 'Include at least one letter.';
    }

    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Include at least one number.';
    }

    if (value == _currentController.text) {
      return 'New password must differ from current password.';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your new password.';
    }

    if (value != _newController.text) {
      return 'Passwords do not match.';
    }

    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _submitted = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _api.changePassword(
        _currentController.text,
        _newController.text,
        _confirmController.text,
      );
      if (!mounted) return;
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      _showMessage('Password updated successfully.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: mutedText, fontSize: 14),
      prefixIcon: const Icon(Icons.lock_outline_rounded, color: blue, size: 21),
      suffixIcon: IconButton(
        tooltip: visible ? 'Hide password' : 'Show password',
        onPressed: onToggle,
        icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: mutedText,
          size: 21,
        ),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFBFE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      errorMaxLines: 3,
      errorStyle: const TextStyle(color: errorRed, fontSize: 12, height: 1.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorRed, width: 1.5),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool visible,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    TextInputAction textInputAction = TextInputAction.next,
    VoidCallback? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: textInputAction,
      validator: validator,
      autovalidateMode: _submitted
          ? AutovalidateMode.always
          : AutovalidateMode.onUserInteraction,
      onChanged: (_) {
        setState(() {});

        onChanged?.call();

        // Revalidate dependent fields after the user has submitted
        // the form once, so password mismatch errors stay accurate.
        if (_submitted) {
          _formKey.currentState?.validate();
        }
      },
      decoration: _inputDecoration(
        label: label,
        visible: visible,
        onToggle: onToggle,
      ),
    );
  }

  Widget _buildPasswordHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 7, left: 4),
      child: Text(
        text,
        style: const TextStyle(color: mutedText, fontSize: 12, height: 1.5),
      ),
    );
  }

  Widget _buildPasswordStatus() {
    final password = _newController.text;

    final requirements = <MapEntry<String, bool>>[
      MapEntry('At least 8 characters', password.length >= 8),
      MapEntry('At least one letter', RegExp(r'[A-Za-z]').hasMatch(password)),
      MapEntry('At least one number', RegExp(r'\d').hasMatch(password)),
      MapEntry(
        'Different from current password',
        password.isNotEmpty && password != _currentController.text,
      ),
    ];

    // Show the small checklist only after the user starts typing.
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: requirements.map((requirement) {
          final passed = requirement.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Icon(
                  passed ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 14,
                  color: passed ? const Color(0xFF18845B) : errorRed,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    requirement.key,
                    style: TextStyle(
                      color: passed ? const Color(0xFF18845B) : errorRed,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: navy,
        title: const Text(
          'Change Password',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: navy,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 400 ? 16.0 : 20.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF2FF),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                size: 29,
                                color: blue,
                              ),
                            ),

                            const SizedBox(height: 22),

                            const Text(
                              'Keep your account secure',
                              style: TextStyle(
                                color: navy,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                height: 1.3,
                              ),
                            ),

                            const SizedBox(height: 9),

                            const Text(
                              'Create a new password to help keep '
                              'your AM5 ROYAL account secure.',
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),

                            const SizedBox(height: 28),

                            // CURRENT PASSWORD
                            _buildPasswordField(
                              label: 'Current password',
                              controller: _currentController,
                              visible: _showCurrent,
                              onToggle: () {
                                setState(() {
                                  _showCurrent = !_showCurrent;
                                });
                              },
                              validator: _validateCurrentPassword,
                              onChanged: () {
                                if (_submitted) {
                                  _formKey.currentState?.validate();
                                }
                              },
                            ),

                            const SizedBox(height: 22),

                            // NEW PASSWORD
                            _buildPasswordField(
                              label: 'New password',
                              controller: _newController,
                              visible: _showNew,
                              onToggle: () {
                                setState(() {
                                  _showNew = !_showNew;
                                });
                              },
                              validator: _validateNewPassword,
                            ),

                            _buildPasswordHint(
                              'Use at least 8 characters, including '
                              'a letter and a number.',
                            ),

                            _buildPasswordStatus(),

                            const SizedBox(height: 22),

                            // CONFIRM PASSWORD
                            _buildPasswordField(
                              label: 'Confirm new password',
                              controller: _confirmController,
                              visible: _showConfirm,
                              onToggle: () {
                                setState(() {
                                  _showConfirm = !_showConfirm;
                                });
                              },
                              validator: _validateConfirmPassword,
                              textInputAction: TextInputAction.done,
                            ),

                            const SizedBox(height: 26),

                            // UPDATE BUTTON
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: blue,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 52),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_reset_rounded, size: 20),
                                    SizedBox(width: 9),
                                    Text(
                                      'Update Password',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: mutedText,
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Your account security matters',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: mutedText,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
