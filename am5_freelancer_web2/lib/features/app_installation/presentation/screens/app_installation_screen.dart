import 'package:flutter/material.dart';

import '../../../../core/widgets/section_hero_banner.dart';

import 'vendor_app_installation_screen.dart';
import 'vendor_app_activation_screen.dart';
import 'customer_app_installation_screen.dart';
import 'customer_app_activation_screen.dart';

class AppInstallationScreen extends StatelessWidget {
  const AppInstallationScreen({super.key});

  static const Color navy = Color(0xFF101D45);
  static const Color royalBlue = Color(0xFF2449A5);
  static const Color gold = Color(0xFFFFC857);
  static const Color background = Color(0xFFFFF8ED);
  static const Color textDark = Color(0xFF17233F);
  static const Color textGrey = Color(0xFF778198);

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'App Installation',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeroBanner(
                title: 'Install. Activate. Earn.',
                subtitle: 'Choose an app category to review its installation and activation milestones.',
                icon: Icons.install_mobile_rounded,
                imageAsset: 'assets/images/benefits/one_time_installation.png',
              ),

              const SizedBox(height: 26),

              // SECTION TITLE
              const Text(
                'Choose a Category',
                style: TextStyle(
                  color: textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Select a category to view its rewards.',
                style: TextStyle(color: textGrey, fontSize: 13),
              ),

              const SizedBox(height: 18),

              // ROW 1: VENDOR CARDS
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _InstallationCard(
                      title: 'Vendor App Installation',
                      subtitle: 'Installation milestones and rewards',
                      icon: Icons.storefront_rounded,
                      accent: const Color(0xFF2459C4),
                      onTap: () {
                        _openScreen(
                          context,
                          const VendorAppInstallationScreen(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _InstallationCard(
                      title: 'Vendor Activation + Services',
                      subtitle: 'Activation and received service rewards',
                      icon: Icons.verified_user_rounded,
                      accent: const Color(0xFF16866B),
                      onTap: () {
                        _openScreen(context, const VendorAppActivationScreen());
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ROW 2: CUSTOMER CARDS
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _InstallationCard(
                      title: 'Customer App Installation',
                      subtitle: 'Customer installation rewards',
                      icon: Icons.phone_android_rounded,
                      accent: const Color(0xFF7B55C7),
                      onTap: () {
                        _openScreen(
                          context,
                          const CustomerAppInstallationScreen(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _InstallationCard(
                      title: 'Customer Activation + Services',
                      subtitle: 'Activation and service rewards',
                      icon: Icons.card_giftcard_rounded,
                      accent: const Color(0xFFD18A13),
                      onTap: () {
                        _openScreen(
                          context,
                          const CustomerAppActivationScreen(),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // INFORMATION SECTION
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD9E4FA)),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withValues(alpha: 0.035),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: royalBlue,
                      size: 26,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Check each reward section to view its '
                        'milestones, benefits and wallet details.',
                        style: TextStyle(
                          color: Color(0xFF536585),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================
// PROFESSIONAL INSTALLATION CATEGORY CARD
// ======================================================

class _InstallationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _InstallationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.20), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF101D45).withValues(alpha: 0.055),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ICON: COLOUR DEPENDS ON CARD
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),

              const SizedBox(height: 16),

              // TITLE
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF172B5E),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 6),

              // SUBTITLE
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF778198),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),

              // PUSH ARROW TO BOTTOM
              const Spacer(),

              // BOTTOM-RIGHT ARROW
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
