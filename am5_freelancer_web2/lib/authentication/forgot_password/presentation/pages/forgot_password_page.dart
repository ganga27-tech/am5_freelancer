import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _api = FreelanceApi();

  bool _useMobile = false;

  static const Color _navy = Color(0xFF142B6F);
  static const Color _deepNavy = Color(0xFF0D1C4A);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _background = Color(0xFFF7F8FC);
  static const Color _secondary = Color(0xFF64748B);

  @override
  void dispose() {
    _emailController.dispose();
    _mobileController.dispose();
    _api.dispose();
    super.dispose();
  }

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Please enter your email address.';
    }

    if (email.length > 254) {
      return 'Email address is too long.';
    }

    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+"
      r"@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
      r"(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  // ============================================================
  // MOBILE VALIDATION
  // ============================================================

  String? _validateMobile(String? value) {
    final mobile = value?.trim() ?? '';

    if (mobile.isEmpty) {
      return 'Please enter your mobile number.';
    }

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }

    return null;
  }

  // ============================================================
  // CHANGE RECOVERY METHOD
  // ============================================================

  void _changeMethod(bool useMobile) {
    if (_useMobile == useMobile) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _useMobile = useMobile;
    });
  }

  // ============================================================
  // CONTINUE
  // ============================================================

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    final identifier = (_useMobile ? _mobileController : _emailController).text
        .trim();
    try {
      final challenge = await _api.forgotPassword(
        identifier,
        channel: _useMobile ? 'sms' : 'email',
      );
      final challengeId = challenge['challenge_id']?.toString();
      if (challengeId == null || challengeId.isEmpty) {
        throw const ApiException(
          'The recovery service returned an invalid response.',
        );
      }
      if (!mounted) return;
      final otp = await _requestValue(
        title: 'Enter verification code',
        label: 'Enter the code if you received one',
      );
      if (otp == null || otp.trim().isEmpty) return;
      final verification = await _api.verifyOtp(challengeId, otp.trim());
      final resetToken = verification['reset_token']?.toString();
      if (verification['verified'] != true ||
          resetToken == null ||
          resetToken.isEmpty) {
        throw const ApiException(
          'The verification code could not be confirmed.',
        );
      }
      if (!mounted) return;
      final password = await _requestValue(
        title: 'Choose a new password',
        label: 'New password',
        obscure: true,
      );
      if (password == null) return;
      final confirmation = await _requestValue(
        title: 'Confirm password',
        label: 'Confirm new password',
        obscure: true,
      );
      if (confirmation == null) return;
      await _api.resetPassword(resetToken, password, confirmation);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. You can now sign in.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).popUntil(
        (route) => route.settings.name == AppRoutes.login || route.isFirst,
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String?> _requestValue({
    required String title,
    required String label,
    bool obscure = false,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  // ============================================================
  // RESPONSIVE PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 950) {
              return _buildDesktopLayout(constraints);
            }

            return _buildCompactLayout(constraints);
          },
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP LAYOUT
  // ============================================================

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    const horizontalPadding = 36.0;
    const verticalPadding = 24.0;

    return LayoutBuilder(
      builder: (context, viewportConstraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (viewportConstraints.maxHeight - verticalPadding * 2)
                  .clamp(0.0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT BRAND CARD

                      Expanded(flex: 9, child: _buildBrandPanel()),

                      const SizedBox(width: 28),

                      // RIGHT FORM CARD
                      Expanded(flex: 7, child: _buildDesktopFormCard()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DESKTOP FORM CARD
  // ============================================================

  Widget _buildDesktopFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _navy.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.055),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _buildFormContents(),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE AND TABLET LAYOUT
  // ============================================================

  Widget _buildCompactLayout(BoxConstraints constraints) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
        horizontal: constraints.maxWidth < 380 ? 16 : 24,
        vertical: 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: _buildFormCard(),
        ),
      ),
    );
  }

  // ============================================================
  // LEFT BRAND PANEL
  // ============================================================

  Widget _buildBrandPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _deepNavy],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // BRAND LOGO

          _buildLogo(light: true),

          const SizedBox(height: 32),

          // GOLD ACCENT
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 22),

          // HEADING
          const Text(
            'Your Account.\nYour Control.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              height: 1.20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),

          const SizedBox(height: 14),

          // DESCRIPTION
          Text(
            'A simple way to get back into your '
            'AM5 ROYAL freelancer account.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              height: 1.65,
            ),
          ),

          const SizedBox(height: 26),

          // DIVIDER
          Container(width: 60, height: 1, color: _gold.withValues(alpha: 0.75)),

          const SizedBox(height: 18),

          // FOOTER
          Text(
            'AM5 ROYAL  ·  FREELANCER NETWORK',
            style: TextStyle(
              color: _gold,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMPACT FORM CARD
  // ============================================================

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _navy.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.055),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _buildFormContents(),
    );
  }

  // ============================================================
  // FORM CONTENTS
  // ============================================================

  Widget _buildFormContents() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // LOGO

          Center(child: _buildLogo(light: false)),

          const SizedBox(height: 24),

          // HEADING
          const Text(
            'Forgot Password?',
            style: TextStyle(
              color: _navy,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),

          const SizedBox(height: 8),

          // DESCRIPTION
          const Text(
            'Enter your registered email or mobile number '
            'to recover your account.',
            style: TextStyle(color: _secondary, fontSize: 13, height: 1.6),
          ),

          const SizedBox(height: 20),

          // EMAIL / MOBILE SELECTOR
          _buildMethodSelector(),

          const SizedBox(height: 18),

          // FIELD LABEL
          Text(
            _useMobile ? 'Mobile Number' : 'Email Address',
            style: const TextStyle(
              color: _navy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          // INPUT FIELD
          _buildRecoveryField(),

          const SizedBox(height: 20),

          // CONTINUE BUTTON
          Center(
            child: SizedBox(
              width: 200,
              height: 46,
              child: ElevatedButton(
                onPressed: _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 17),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // BACK TO LOGIN
          Center(
            child: TextButton(
              onPressed: _backToLogin,
              style: TextButton.styleFrom(
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: const Text(
                '←  Back to Login',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMAIL / MOBILE SELECTOR
  // ============================================================

  Widget _buildMethodSelector() {
    return Container(
      height: 45,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _navy.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMethodButton(
              label: 'Email',
              selected: !_useMobile,
              onTap: () => _changeMethod(false),
            ),
          ),

          const SizedBox(width: 5),

          Expanded(
            child: _buildMethodButton(
              label: 'Mobile',
              selected: _useMobile,
              onTap: () => _changeMethod(true),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // METHOD BUTTON
  // ============================================================

  Widget _buildMethodButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? _navy : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: selected ? Border.all(color: _gold, width: 1.1) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _navy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RECOVERY INPUT FIELD
  // ============================================================

  Widget _buildRecoveryField() {
    return TextFormField(
      key: ValueKey(_useMobile ? 'mobile-field' : 'email-field'),
      controller: _useMobile ? _mobileController : _emailController,
      keyboardType: _useMobile
          ? TextInputType.phone
          : TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autofillHints: _useMobile
          ? const [AutofillHints.telephoneNumber]
          : const [AutofillHints.email],
      maxLength: _useMobile ? 10 : null,
      autocorrect: false,
      enableSuggestions: false,
      validator: _useMobile ? _validateMobile : _validateEmail,
      onFieldSubmitted: (_) => _continue(),
      decoration: InputDecoration(
        hintText: _useMobile
            ? 'Enter your 10-digit mobile number'
            : 'Enter your email address',
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        prefixIcon: Icon(
          _useMobile ? Icons.phone_outlined : Icons.email_outlined,
          color: _navy,
          size: 19,
        ),
        counterText: '',
        filled: true,
        fillColor: _background,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: _navy.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _gold, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
      ),
    );
  }

  // ============================================================
  // BRAND LOGO
  // ============================================================

  Widget _buildLogo({required bool light}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text(
            'AM5',
            style: TextStyle(
              color: _deepNavy,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AM5 ROYAL',
              style: TextStyle(
                color: light ? Colors.white : _navy,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              'FREELANCER',
              style: TextStyle(
                color: light ? _gold : _secondary,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // BACK TO LOGIN
  // ============================================================

  void _backToLogin() {
    FocusScope.of(context).unfocus();

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }
}
