import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';
import 'change_password_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  static const Color navy = Color(0xFF101D45);
  static const Color blue = Color(0xFF2449A5);
  static const Color gold = Color(0xFFD6AD55);
  static const Color background = Color(0xFFF5F7FC);
  static const Color textGrey = Color(0xFF737B8C);

  bool _profileVisible = true;
  final bool _showContactDetails = false;
  bool _personalisedUpdates = true;
  bool _securityAlerts = true;
  final FreelanceApi _api = FreelanceApi();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.settings();
      final privacy = data['privacy'];
      final security = data['security'];
      if (!mounted) return;
      setState(() {
        if (privacy is Map) {
          _profileVisible =
              privacy['show_profile_in_directory'] as bool? ?? _profileVisible;
          _personalisedUpdates =
              privacy['allow_marketing_contact'] as bool? ??
              _personalisedUpdates;
        }
        if (security is Map) {
          _securityAlerts =
              security['login_alerts'] as bool? ?? _securityAlerts;
        }
      });
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _savePreference(
    String section,
    String key,
    bool value,
    bool previous,
  ) async {
    setState(() {
      if (key == 'show_profile_in_directory') _profileVisible = value;
      if (key == 'allow_marketing_contact') _personalisedUpdates = value;
      if (key == 'login_alerts') _securityAlerts = value;
    });
    try {
      if (section == 'privacy') {
        await _api.updatePrivacy({key: value});
      } else {
        await _api.updateSecurity({key: value});
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          if (key == 'show_profile_in_directory') _profileVisible = previous;
          if (key == 'allow_marketing_contact') _personalisedUpdates = previous;
          if (key == 'login_alerts') _securityAlerts = previous;
        });
        _showMessage(error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Privacy & Security',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),

                  _buildSection(
                    title: 'Privacy Preferences',
                    subtitle:
                        'Choose how your profile information is displayed.',
                    icon: Icons.privacy_tip_outlined,
                    children: [
                      _buildToggle(
                        title: 'Profile Visibility',
                        subtitle:
                            'Allow your freelancer profile to be visible.',
                        icon: Icons.visibility_outlined,
                        value: _profileVisible,
                        onChanged: (value) => _savePreference(
                          'privacy',
                          'show_profile_in_directory',
                          value,
                          _profileVisible,
                        ),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        title: 'Show Contact Details',
                        subtitle: 'Allow contact details to be displayed on your profile.',
                        icon: Icons.contact_phone_outlined,
                        value: _showContactDetails,
                        onChanged: (_) => _showMessage(
                          'Contact detail visibility is not supported by the backend.',
                        ),
                      ),
                      _buildDivider(),
                      _buildToggle(
                        title: 'Personalised Updates',
                        subtitle: 'Receive personalised platform updates and information.',
                        icon: Icons.notifications_active_outlined,
                        value: _personalisedUpdates,
                        onChanged: (value) => _savePreference(
                          'privacy',
                          'allow_marketing_contact',
                          value,
                          _personalisedUpdates,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildSection(
                    title: 'Security Preferences',
                    subtitle: 'Choose whether to receive account security notifications.',
                    icon: Icons.shield_outlined,
                    children: [
                      _buildToggle(
                        title: 'Security Alerts',
                        subtitle: 'Receive alerts about important account security activity.',
                        icon: Icons.gpp_good_outlined,
                        value: _securityAlerts,
                        onChanged: (value) => _savePreference(
                          'security',
                          'login_alerts',
                          value,
                          _securityAlerts,
                        ),
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.lock_outline,
                        title: 'Change Password',
                        subtitle: 'Update your account password',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildNotice(),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _showMessage(
                        'Available privacy preferences save automatically.',
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text(
                        'Save Preferences',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'AM5 ROYAL • Work. Refer. Grow.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textGrey,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [navy, blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(19),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.security_outlined, color: gold, size: 30),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Privacy Matters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Manage your privacy and security preferences.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE7EAF2)),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(color: textGrey, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: blue, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeTrackColor: blue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: blue, size: 23),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(color: textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: textGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Color(0xFFEEF0F5));
  }

  Widget _buildNotice() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E7),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFF0DEB4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: navy, size: 22),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Preview mode: preferences change on this screen only. They are not stored permanently until the backend API is connected.',
              style: TextStyle(color: navy, fontSize: 12, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
