import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/register_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // COMMON MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFB42318)
              : AppColors.primaryDark,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String? _validateName(String? value) {
    final String name = value?.trim() ?? '';

    if (name.isEmpty) return 'Please enter your full name.';
    if (name.length < 3) return 'Enter at least 3 characters.';
    if (name.length > 60) return 'Name cannot exceed 60 characters.';

    if (!RegExp(r"^[A-Za-z][A-Za-z .'-]*$").hasMatch(name)) {
      return 'Enter a valid name using English letters.';
    }

    return null;
  }

  String? _validateMobile(String? value) {
    final String mobile = value?.trim() ?? '';

    if (mobile.isEmpty) return 'Mobile number is required.';

    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobile)) {
      return 'Enter a valid 10-digit mobile number.';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final String email = value?.trim() ?? '';

    if (email.isEmpty) return 'Email address is required.';
    if (email.length > 254) return 'Email address is too long.';

    final RegExp emailPattern = RegExp(
      r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+"
      r"(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*"
      r"@"
      r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?"
      r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$",
    );

    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final String password = value ?? '';

    if (password.isEmpty) return 'Password is required.';
    if (password.length < 8) return 'Use at least 8 characters.';
    if (password.length > 64) return 'Password cannot exceed 64 characters.';

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Include one uppercase letter.';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Include one lowercase letter.';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Include one number.';
    }

    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Include one special character.';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final String confirmPassword = value ?? '';

    if (confirmPassword.isEmpty) {
      return 'Please confirm your password.';
    }

    if (confirmPassword != _passwordController.text) {
      return 'Passwords do not match.';
    }

    return null;
  }

  // ============================================================
  // REGISTRATION ACTION
  // ============================================================

  Future<void> _register() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _hasSubmitted = true;
    });

    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {
      _showMessage('Please correct the highlighted fields.', isError: true);
      return;
    }

    if (!_acceptedTerms) {
      _showMessage(
        'Please accept the Terms & Conditions and Privacy Policy.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await RegisterService().register(
        fullName: _nameController.text,
        mobileNumber: _mobileController.text,
        email: _emailController.text,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;

      _showMessage(
        response['message']?.toString() ?? 'Account registered successfully.',
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openLogin() {
    if (_isLoading) return;

    Navigator.of(context).pop();
  }
  // ============================================================
  // FIELD LABEL
  // ============================================================

  Widget _fieldLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // FULL NAME FIELD
  // ============================================================

  Widget _nameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Full Name'),
        AppTextField(
          controller: _nameController,
          label: 'Full Name',
          hintText: 'Enter your full name',
          prefixIcon: Icons.person_outline_rounded,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          validator: _validateName,
          enabled: !_isLoading,
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE NUMBER FIELD
  // ============================================================

  Widget _mobileField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Mobile Number'),
        AppTextField(
          controller: _mobileController,
          label: 'Mobile Number',
          hintText: '10-digit mobile number',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          maxLength: 10,
          validator: _validateMobile,
          enabled: !_isLoading,
        ),
      ],
    );
  }

  // ============================================================
  // EMAIL FIELD
  // ============================================================

  Widget _emailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Email Address'),
        AppTextField(
          controller: _emailController,
          label: 'Email Address',
          hintText: 'Enter your email',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: _validateEmail,
          enabled: !_isLoading,
        ),
      ],
    );
  }

  // ============================================================
  // PASSWORD FIELD
  // ============================================================

  Widget _passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Password'),
        AppTextField(
          controller: _passwordController,
          label: 'Password',
          hintText: 'Create a password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          validator: _validatePassword,
          enabled: !_isLoading,
          onChanged: (_) {
            if (_hasSubmitted || _confirmPasswordController.text.isNotEmpty) {
              _formKey.currentState?.validate();
            }
          },
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textSecondary,
              size: 19,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CONFIRM PASSWORD FIELD
  // ============================================================

  Widget _confirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Confirm Password'),
        AppTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hintText: 'Re-enter your password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          validator: _validateConfirmPassword,
          enabled: !_isLoading,
          onChanged: (_) {
            if (_hasSubmitted) {
              _formKey.currentState?.validate();
            }
          },
          suffixIcon: IconButton(
            tooltip: _obscureConfirmPassword
                ? 'Show password'
                : 'Hide password',
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textSecondary,
              size: 19,
            ),
          ),
        ),
      ],
    );
  }
  // ============================================================
  // RESPONSIVE FIELD ROW
  // ============================================================

  Widget _fieldRow({required Widget first, required Widget second}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 440) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 14), second],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 18),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  // ============================================================
  // TERMS AND CONDITIONS
  // ============================================================

  Widget _termsCheckbox() {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primary,
      value: _acceptedTerms,
      onChanged: _isLoading
          ? null
          : (value) {
              setState(() {
                _acceptedTerms = value ?? false;
              });
            },
      title: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'I agree to the ',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          GestureDetector(
            onTap: () {
              _showMessage('Terms & Conditions page is not connected yet.');
            },
            child: const Text(
              'Terms & Conditions',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Text(
            ' and ',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          GestureDetector(
            onTap: () {
              _showMessage('Privacy Policy page is not connected yet.');
            },
            child: const Text(
              'Privacy Policy',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SIGN IN FOOTER
  // ============================================================

  Widget _signInFooter() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Already have an account?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        TextButton(
          onPressed: _openLogin,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 38),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Sign In  →',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REGISTRATION FORM
  // ============================================================

  Widget _registrationForm() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),

          _nameField(),

          const SizedBox(height: 16),

          _fieldRow(first: _mobileField(), second: _emailField()),

          const SizedBox(height: 16),

          _fieldRow(first: _passwordField(), second: _confirmPasswordField()),

          const SizedBox(height: 8),

          _termsCheckbox(),

          const SizedBox(height: 17),

          SizedBox(
            height: 50,
            child: PrimaryButton(
              text: 'Create Account',
              onPressed: _register,
              isLoading: _isLoading,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.border)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.border)),
            ],
          ),

          const SizedBox(height: 12),

          _signInFooter(),
        ],
      ),
    );
  }

  // ============================================================
  // FREELANCER BENEFITS
  // ============================================================

  Widget _freelancerBenefits() {
    final List<Map<String, dynamic>> benefits = [
      {'icon': Icons.work_outline_rounded, 'title': 'Flexible Work'},
      {
        'icon': Icons.account_balance_wallet_outlined,
        'title': 'Multiple Earnings',
      },
      {'icon': Icons.card_giftcard_rounded, 'title': 'Rewards & Benefits'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Freelancer Benefits',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < benefits.length; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.13),
                        ),
                      ),
                      child: Icon(
                        benefits[i]['icon'] as IconData,
                        color: AppColors.goldLight,
                        size: 28,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      benefits[i]['title'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              if (i != benefits.length - 1)
                Container(
                  width: 1,
                  height: 82,
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  color: Colors.white.withValues(alpha: 0.22),
                ),
            ],
          ],
        ),
      ],
    );
  }
  // ============================================================
  // DESKTOP BRAND PANEL
  // ============================================================

  Widget _brandPanel() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 650),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172D52), Color(0xFF0B1730)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -95,
            top: 170,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldLight.withValues(alpha: 0.10),
                  width: 1.5,
                ),
              ),
            ),
          ),

          Positioned(
            right: -55,
            top: 210,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldLight.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),

          Positioned(
            left: -70,
            right: -70,
            bottom: -125,
            child: Container(
              height: 210,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.goldLight.withValues(alpha: 0.25),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(32, 34, 30, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLogo(showText: true, light: true),

                const SizedBox(height: 90),

                const Text(
                  'Grow Your Skills.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    letterSpacing: -0.7,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Build Your Future.',
                  style: TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    letterSpacing: -0.7,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Discover opportunities. Create your success.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 14,
                    height: 1.8,
                  ),
                ),

                const SizedBox(height: 22),

                Container(
                  width: 58,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.goldLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                const SizedBox(height: 48),

                _freelancerBenefits(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMPACT BRAND PANEL - TABLET AND MOBILE
  // ============================================================

  Widget _compactBrandPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172D52), Color(0xFF0B1730)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppLogo(showText: true, light: true),

          const SizedBox(height: 30),

          const Text(
            'Grow Your Skills.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 3),

          const Text(
            'Build Your Future.',
            style: TextStyle(
              color: AppColors.goldLight,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Discover opportunities. Create your success.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.7,
            ),
          ),

          const SizedBox(height: 18),

          Container(
            width: 48,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.goldLight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(height: 28),

          _freelancerBenefits(),
        ],
      ),
    );
  }

  // ============================================================
  // REGISTRATION CARD
  // ============================================================

  Widget _registrationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF142B6F).withValues(alpha: 0.055),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.goldLight.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'JOIN AM5 ROYAL',
                style: TextStyle(
                  color: Color(0xFF9A681E),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          const Text(
            'Create Your Account',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Fill in your details to get started.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),

          _registrationForm(),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN SCREEN - RESPONSIVE LAYOUT
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;

            // DESKTOP: Brand panel left, registration card right.
            if (width >= 1050) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 9, child: _brandPanel()),

                        const SizedBox(width: 28),

                        Expanded(flex: 11, child: _registrationCard()),
                      ],
                    ),
                  ),
                ),
              );
            }

            // TABLET: Branding above the registration form.
            if (width >= 600) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _compactBrandPanel(),

                        const SizedBox(height: 20),

                        _registrationCard(),
                      ],
                    ),
                  ),
                ),
              );
            }

            // MOBILE: Registration form first, branding below.
            return SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _registrationCard(),

                  const SizedBox(height: 16),

                  _compactBrandPanel(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
