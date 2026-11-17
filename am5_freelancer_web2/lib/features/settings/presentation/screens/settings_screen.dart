import 'package:flutter/material.dart';

import '../../../../core/widgets/section_hero_banner.dart';

import '../../../../app/routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';
import '../../../../core/storage/secure_storage_service.dart';

import 'privacy_settings_screen.dart';
import 'change_password_screen.dart';
import 'contact_support_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';
import 'faq_screen.dart';
import 'report_problem_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // AM5 ROYAL theme colors
  static const Color backgroundColor = Color(0xFFFFF8ED);
  static const Color navyColor = Color(0xFF101D45);
  static const Color goldColor = Color(0xFFC5A46D);
  static const Color textColor = Color(0xFF26324B);
  static const Color secondaryTextColor = Color(0xFF778096);
  static const Color dividerColor = Color(0xFFF0E9DE);
  static const Color logoutRed = Color(0xFFD64545);

  bool pushNotifications = true;
  bool emailNotifications = false;
  final FreelanceApi _api = FreelanceApi();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _api.settings();
      final notifications = data['notifications'];
      if (!mounted || notifications is! Map) return;
      setState(() {
        pushNotifications =
            notifications['push_notifications'] as bool? ?? pushNotifications;
        emailNotifications =
            notifications['email_notifications'] as bool? ?? emailNotifications;
      });
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveNotificationPreference(String key, bool value) async {
    final previousPush = pushNotifications;
    final previousEmail = emailNotifications;
    setState(() {
      if (key == 'push_notifications') pushNotifications = value;
      if (key == 'email_notifications') emailNotifications = value;
    });
    try {
      await _api.updateNotifications({key: value});
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          pushNotifications = previousPush;
          emailNotifications = previousEmail;
        });
        _message(error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: navyColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                const SectionHeroBanner(
                  title: 'Account & Preferences',
                  subtitle:
                      'Manage your profile, privacy, alerts, and help options.',
                  icon: Icons.settings_rounded,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('ACCOUNT'),

                _buildSettingsCard(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.visibility_outlined,
                      title: 'Profile Visibility',
                      subtitle: 'Manage who can view your profile',
                      onTap: () {
                        _navigateTo(const PrivacySettingsScreen());
                      },
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy Settings',
                      subtitle: 'Control your privacy preferences',
                      onTap: () {
                        _navigateTo(const PrivacySettingsScreen());
                      },
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.key_outlined,
                      title: 'Change Password',
                      subtitle: 'Update your account password',
                      onTap: () {
                        _navigateTo(const ChangePasswordScreen());
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _buildSectionTitle('PREFERENCES'),

                _buildSettingsCard(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Push Notifications',
                      subtitle: 'Receive app notifications',
                      value: pushNotifications,
                      onChanged: (value) => _saveNotificationPreference(
                        'push_notifications',
                        value,
                      ),
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      icon: Icons.email_outlined,
                      title: 'Email Notifications',
                      subtitle: 'Receive updates through email',
                      value: emailNotifications,
                      onChanged: (value) => _saveNotificationPreference(
                        'email_notifications',
                        value,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _buildSectionTitle('HELP & SUPPORT'),

                _buildSettingsCard(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.support_agent_outlined,
                      title: 'Contact Support',
                      subtitle: 'Get help with your account',
                      onTap: () {
                        _navigateTo(const ContactSupportScreen());
                      },
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Frequently Asked Questions',
                      subtitle: 'Find answers to common questions',
                      onTap: () {
                        _navigateTo(const FaqScreen());
                      },
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.report_problem_outlined,
                      title: 'Report a Problem',
                      subtitle: 'Tell us about an issue',
                      onTap: () {
                        _navigateTo(const ReportProblemScreen());
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _buildSectionTitle('LEGAL'),

                _buildSettingsCard(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'Learn how your information is handled',
                      onTap: () {
                        _navigateTo(const PrivacyPolicyScreen());
                      },
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.description_outlined,
                      title: 'Terms & Conditions',
                      subtitle: 'Read the terms of using our services',
                      onTap: () {
                        _navigateTo(const TermsConditionsScreen());
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                _buildLogoutButton(),

                const SizedBox(height: 24),

                const Center(
                  child: Column(
                    children: [
                      Text(
                        'AM5 ROYAL',
                        style: TextStyle(
                          color: navyColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Work. Refer. Grow.',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                          letterSpacing: 0.3,
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
    );
  }

  // Section headings
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: navyColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // White settings card
  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: navyColor.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // Standard navigation tile
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              _buildIconBox(icon),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: goldColor,
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Notification switch tile
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _buildIconBox(icon),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: secondaryTextColor,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          Switch.adaptive(
            value: value,
            activeTrackColor: navyColor,
            activeThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E7ED),
            inactiveThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // Consistent gold icon background
  Widget _buildIconBox(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: goldColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: goldColor, size: 21),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 67),
      child: Divider(height: 1, thickness: 1, color: dividerColor),
    );
  }

  // Logout confirmation
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _showLogoutConfirmation,
        icon: const Icon(Icons.logout_rounded, size: 19),
        label: const Text(
          'Log Out',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: logoutRed,
          side: BorderSide(color: logoutRed.withValues(alpha: 0.45)),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(color: navyColor, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(color: textColor, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: secondaryTextColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _handleLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: navyColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    await SecureStorageService().deleteAccessToken();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }
}
