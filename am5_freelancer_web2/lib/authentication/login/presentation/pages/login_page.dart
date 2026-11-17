import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../app/routes.dart';
import '../../data/login_service.dart';
import '../../../../core/storage/secure_storage_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LoginService _loginService = LoginService();
  final SecureStorageService _secureStorage = SecureStorageService();

  bool _isEmailLogin = false;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _loginService.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _selectLoginMethod(bool isEmail) {
    if (_isLoading || _isEmailLogin == isEmail) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isEmailLogin = isEmail;
    });

    _formKey.currentState?.reset();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    // Validate form fields.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final identifier = _isEmailLogin
        ? _emailController.text.trim()
        : _mobileController.text.trim();

    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _loginService.login(
        identifier: identifier,
        password: password,
      );

      await _secureStorage.saveAccessToken(
        accessToken: response.accessToken,
        tokenType: response.tokenType,
      );

      if (!mounted) return;

      // Backend authentication succeeded.
      setState(() {
        _isLoading = false;
      });

      // Never print or expose the access token.
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.dashboard, (route) => false);
    } on LoginException catch (error) {
      if (!mounted) return;

      _showMessage(error.message);

      setState(() {
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      _showMessage('Something went wrong. Please try again.');

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _forgotPassword() {
    if (_isLoading) return;

    Navigator.pushNamed(context, AppRoutes.forgotPassword);
  }

  void _register() {
    if (_isLoading) return;

    Navigator.pushNamed(context, AppRoutes.register);
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);

    final bool isMobile = screenSize.width < AppConstants.mobileBreakpoint;

    final bool isTablet =
        screenSize.width >= AppConstants.mobileBreakpoint &&
        screenSize.width < AppConstants.tabletBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isMobile
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _buildLoginCard(isCompact: false),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final double pageHeight = (constraints.maxHeight - 32).clamp(
                    480.0,
                    680.0,
                  );

                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: SizedBox(
                          width: double.infinity,
                          height: pageHeight,
                          child: _buildDesktopLayout(isTablet: isTablet),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP LAYOUT
  // ---------------------------------------------------------------------------

  Widget _buildDesktopLayout({required bool isTablet}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double imageWidth = totalWidth * 0.50;
        final double loginWidth = totalWidth - imageWidth;

        return SizedBox(
          width: totalWidth,
          height: constraints.maxHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT IMAGE PANEL
              SizedBox(
                width: imageWidth,
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/images/freelancer_login.jpeg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24),
                        child: const Text(
                          'Unable to load login image.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // RIGHT LOGIN PANEL
              SizedBox(
                width: loginWidth,
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(20),
                  ),
                  child: _buildLoginCard(isCompact: true, isAttached: true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // LOGIN CARD
  // ---------------------------------------------------------------------------

  Widget _buildLoginCard({required bool isCompact, bool isAttached = false}) {
    final double padding = isCompact ? 22 : 18;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: isAttached
            ? BorderRadius.zero
            : BorderRadius.circular(22),
        border: isAttached ? null : Border.all(color: AppColors.border),
        boxShadow: isAttached
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 22,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // AM5 ROYAL LOGO
                  Center(
                    child: Image.asset(
                      'assets/images/am5_royal_logo.png',
                      width: 100,
                      height: 75,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          width: 100,
                          height: 75,
                          child: Center(
                            child: Text(
                              'Logo image not found',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red, fontSize: 11),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // WELCOME BACK - CENTER
                  Center(
                    child: Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.pageTitle.copyWith(fontSize: 25),
                    ),
                  ),

                  const SizedBox(height: 5),

                  // DESCRIPTION - CENTER
                  Center(
                    child: Text(
                      'Sign in to continue to your freelancer account.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.pageSubtitle,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // MOBILE / EMAIL SELECTOR
                  _buildLoginMethodSelector(),

                  const SizedBox(height: 14),

                  // MOBILE OR EMAIL
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isEmailLogin
                        ? _buildEmailField()
                        : _buildMobileField(),
                  ),

                  const SizedBox(height: 8),

                  // PASSWORD
                  _buildPasswordField(),

                  // FORGOT PASSWORD
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Forgot Password?'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // SIGN IN BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: 'Sign In',
                      onPressed: _isLoading ? null : _login,
                      isLoading: _isLoading,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // OR DIVIDER
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.divider)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: AppTextStyles.bodySecondary),
                      ),
                      const Expanded(child: Divider(color: AppColors.divider)),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // REGISTER - CENTER
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: AppTextStyles.bodySecondary,
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _register,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Register'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOGIN METHOD SELECTOR
  // ---------------------------------------------------------------------------

  Widget _buildLoginMethodSelector() {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildLoginMethodButton(
              title: 'Mobile',
              icon: Icons.phone_outlined,
              selected: !_isEmailLogin,
              onPressed: () => _selectLoginMethod(false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildLoginMethodButton(
              title: 'Email',
              icon: Icons.email_outlined,
              selected: _isEmailLogin,
              onPressed: () => _selectLoginMethod(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginMethodButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: _isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(9),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppColors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  color: selected ? AppColors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE FIELD
  // ---------------------------------------------------------------------------

  Widget _buildMobileField() {
    return AppTextField(
      key: const ValueKey('mobile-field'),
      controller: _mobileController,
      label: 'Mobile Number',
      hintText: 'Enter your mobile number',
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      prefixIcon: Icons.phone_outlined,
      maxLength: 10,
      validator: Validators.mobileNumber,
      autofocus: true,
    );
  }

  // ---------------------------------------------------------------------------
  // EMAIL FIELD
  // ---------------------------------------------------------------------------

  Widget _buildEmailField() {
    return AppTextField(
      key: const ValueKey('email-field'),
      controller: _emailController,
      label: 'Email Address',
      hintText: 'Enter your email address',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      prefixIcon: Icons.email_outlined,
      validator: Validators.email,
      autofocus: true,
    );
  }

  // ---------------------------------------------------------------------------
  // PASSWORD FIELD
  // ---------------------------------------------------------------------------

  Widget _buildPasswordField() {
    return AppTextField(
      controller: _passwordController,
      label: 'Password',
      hintText: 'Enter your password',
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      obscureText: !_isPasswordVisible,
      prefixIcon: Icons.lock_outline,
      maxLength: AppConstants.maxPasswordLength,
      validator: Validators.password,
      suffixIcon: IconButton(
        tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
        onPressed: _isLoading
            ? null
            : () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
        icon: Icon(
          _isPasswordVisible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
      ),
    );
  }
}
