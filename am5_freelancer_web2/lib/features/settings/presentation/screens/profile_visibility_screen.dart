import 'package:flutter/material.dart';

class ProfileVisibilityScreen extends StatefulWidget {
  const ProfileVisibilityScreen({super.key});

  @override
  State<ProfileVisibilityScreen> createState() =>
      _ProfileVisibilityScreenState();
}

class _ProfileVisibilityScreenState extends State<ProfileVisibilityScreen> {
  static const Color navy = Color(0xFF101D45);
  static const Color blue = Color(0xFF2449A5);
  static const Color background = Color(0xFFF5F7FC);

  bool profileVisible = true;
  bool showContactDetails = false;
  bool showEarnings = false;

  void _showPreviewMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Preview only. Visibility preferences are not saved to the server yet.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Profile Visibility'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [navy, blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 46,
                          color: Colors.white,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Profile Visibility',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Choose which profile information you want to display.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        _buildToggle(
                          icon: Icons.person_outline,
                          title: 'Make Profile Visible',
                          subtitle: 'Allow your profile to be visible on the platform.',
                          value: profileVisible,
                          onChanged: (value) {
                            setState(() => profileVisible = value);
                            _showPreviewMessage();
                          },
                        ),
                        const Divider(height: 28),
                        _buildToggle(
                          icon: Icons.phone_outlined,
                          title: 'Show Contact Details',
                          subtitle:
                              'Allow your contact details to be displayed.',
                          value: showContactDetails,
                          onChanged: (value) {
                            setState(() => showContactDetails = value);
                            _showPreviewMessage();
                          },
                        ),
                        const Divider(height: 28),
                        _buildToggle(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Show Earnings',
                          subtitle:
                              'Allow earnings information to be displayed.',
                          value: showEarnings,
                          onChanged: (value) {
                            setState(() => showEarnings = value);
                            _showPreviewMessage();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6E5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF0DEB4)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: navy),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'These controls are currently a UI preview. Changes will not be saved permanently until the backend is connected.',
                            style: TextStyle(
                              color: navy,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _showPreviewMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'Save Preferences',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE7EAF2)),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: 0.035),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: blue),
        ),
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
                style: const TextStyle(
                  color: Color(0xFF737B8C),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeTrackColor: blue,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
