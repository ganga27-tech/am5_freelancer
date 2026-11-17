import 'package:flutter/material.dart';

class FreelancerBenefits extends StatelessWidget {
  const FreelancerBenefits({super.key});

  static const Color navy = Color(0xFF142B6F);
  static const Color gold = Color(0xFFD4A64A);
  static const Color background = Color(0xFFF7F8FC);

  static const List<Benefit> benefits = [
    Benefit(
      title: 'App Installation',
      subtitle: 'Earn up to ₹3',
      image: 'assets/images/benefits/app_installation.png',
      color: Color(0xFF2878E5),
    ),
    Benefit(
      title: 'Vendor Onboarding',
      subtitle: 'Vendor & Customer rewards',
      image: 'assets/images/benefits/vendor_onboarding.png',
      color: Color(0xFF7656D6),
    ),
    Benefit(
      title: 'Tour & Travels',
      subtitle: 'Explore travel benefits',
      image: 'assets/images/benefits/tour_travels.png',
      color: Color(0xFF009688),
    ),
    Benefit(
      title: 'Vouchers',
      subtitle: 'Exclusive vouchers',
      image: 'assets/images/benefits/vouchers.png',
      color: Color(0xFFEA8B35),
    ),
    Benefit(
      title: 'Gifts & Rewards',
      subtitle: 'Special rewards',
      image: 'assets/images/benefits/gifts_rewards.png',
      color: Color(0xFFE05280),
    ),
    Benefit(
      title: 'Dining Benefits',
      subtitle: 'Discover dining offers',
      image: 'assets/images/benefits/dining.png',
      color: Color(0xFF478A57),
    ),
  ];

  void _openBenefit(BuildContext context, Benefit benefit) {
    if (benefit.title == 'App Installation') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const BenefitDetailsScreen(type: BenefitType.appInstallation),
        ),
      );
    } else if (benefit.title == 'Vendor Onboarding') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const VendorCustomerSelectionScreen(),
        ),
      );
    } else {
      _showRegistrationDialog(context, benefit.title);
    }
  }

  void _showRegistrationDialog(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.verified_user_rounded, color: navy, size: 42),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, color: navy),
        ),
        content: const Text(
          'Please complete your registration and provide a valid '
          'Agency ID to access this benefit.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9ECF4)),
        boxShadow: [
          BoxShadow(
            color: navy.withAlpha(12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: gold.withAlpha(30),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: navy,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Freelancer Benefits',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Refer more. Unlock more benefits.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7A8295)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;

              final columns = constraints.maxWidth >= 760
                  ? 3
                  : constraints.maxWidth >= 420
                  ? 2
                  : 1;

              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: benefits.map((benefit) {
                  return SizedBox(
                    width: cardWidth,
                    child: _BenefitCard(
                      benefit: benefit,
                      onTap: () => _openBenefit(context, benefit),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Benefit card
// -----------------------------------------------------------------------------

class _BenefitCard extends StatelessWidget {
  final Benefit benefit;
  final VoidCallback onTap;

  const _BenefitCard({required this.benefit, required this.onTap});

  static const Color navy = FreelancerBenefits.navy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: benefit.color.withAlpha(45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 160,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    benefit.image,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: benefit.color.withAlpha(24),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(8),
                        child: const Text(
                          'Image unavailable',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF747D91),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      benefit.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      benefit.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: Color(0xFF788096),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Explore',
                            style: TextStyle(
                              color: benefit.color,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: benefit.color,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Benefit {
  final String title;
  final String subtitle;
  final String image;
  final Color color;

  const Benefit({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.color,
  });
}

// -----------------------------------------------------------------------------
// Vendor onboarding: select Vendor or Customer.
// -----------------------------------------------------------------------------

class VendorCustomerSelectionScreen extends StatelessWidget {
  const VendorCustomerSelectionScreen({super.key});

  static const Color navy = FreelancerBenefits.navy;
  static const Color gold = FreelancerBenefits.gold;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreelancerBenefits.background,
      appBar: AppBar(
        backgroundColor: FreelancerBenefits.background,
        foregroundColor: navy,
        elevation: 0,
        title: const Text(
          'Vendor Onboarding',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: gold.withAlpha(35),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.handshake_rounded,
                      color: navy,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Choose Your Referral',
                    style: TextStyle(
                      fontSize: 27,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Choose who you want to refer and explore '
                    'the applicable referral rewards.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF747D91),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _ReferralOptionCard(
                    icon: Icons.storefront_rounded,
                    title: 'Vendor',
                    subtitle: 'Refer a service provider to AM5 ROYAL.',
                    tag: 'Up to 5%',
                    color: const Color(0xFF7656D6),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BenefitDetailsScreen(
                            type: BenefitType.vendor,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _ReferralOptionCard(
                    icon: Icons.person_rounded,
                    title: 'Customer',
                    subtitle: 'Refer a customer who needs home services.',
                    tag: 'Up to 5%',
                    color: const Color(0xFF2878E5),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BenefitDetailsScreen(
                            type: BenefitType.customer,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7EAF2)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: navy, size: 21),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Rewards depend on referral eligibility, '
                            'service category and applicable programme '
                            'terms. Actual rewards must be confirmed '
                            'by AM5 ROYAL.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: Color(0xFF747D91),
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
    );
  }
}

class _ReferralOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final Color color;
  final VoidCallback onTap;

  const _ReferralOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withAlpha(45)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withAlpha(24),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: FreelancerBenefits.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF747D91),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Separate benefit detail screens.
// -----------------------------------------------------------------------------

enum BenefitType { appInstallation, vendor, customer }

class BenefitDetailsScreen extends StatelessWidget {
  final BenefitType type;

  const BenefitDetailsScreen({super.key, required this.type});

  static const Color navy = FreelancerBenefits.navy;

  String get title {
    switch (type) {
      case BenefitType.appInstallation:
        return 'App Installation';
      case BenefitType.vendor:
        return 'Vendor Referral Rewards';
      case BenefitType.customer:
        return 'Customer Referral Rewards';
    }
  }

  String get reward {
    switch (type) {
      case BenefitType.appInstallation:
        return 'Up to ₹3';
      case BenefitType.vendor:
      case BenefitType.customer:
        return 'Up to 5%';
    }
  }

  IconData get mainIcon {
    switch (type) {
      case BenefitType.appInstallation:
        return Icons.phone_android_rounded;
      case BenefitType.vendor:
        return Icons.storefront_rounded;
      case BenefitType.customer:
        return Icons.person_rounded;
    }
  }

  List<DetailStep> get steps {
    switch (type) {
      case BenefitType.appInstallation:
        return const [
          DetailStep(
            icon: Icons.share_rounded,
            title: 'Share your referral',
            description: 'Share the AM5 ROYAL app with someone you know.',
          ),
          DetailStep(
            icon: Icons.download_done_rounded,
            title: 'Eligible app installation',
            description:
                'The referred user must complete an eligible '
                'one-time app installation.',
          ),
          DetailStep(
            icon: Icons.card_giftcard_rounded,
            title: 'Referral reward',
            description:
                'Receive up to ₹3 when the installation qualifies '
                'under the applicable referral rules.',
          ),
        ];

      case BenefitType.vendor:
        return const [
          DetailStep(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Refer a vendor',
            description: 'Refer a service provider who may join AM5 ROYAL.',
          ),
          DetailStep(
            icon: Icons.phone_android_rounded,
            title: 'Vendor installs the app',
            description: 'The referred vendor must install the vendor app.',
          ),
          DetailStep(
            icon: Icons.event_available_rounded,
            title: 'First service booking',
            description:
                'The vendor must receive their first eligible '
                'service booking.',
          ),
          DetailStep(
            icon: Icons.percent_rounded,
            title: 'Earn up to 5%',
            description:
                'The applicable reward depends on the vendor’s '
                'service category and programme terms.',
          ),
        ];

      case BenefitType.customer:
        return const [
          DetailStep(
            icon: Icons.share_rounded,
            title: 'Refer a customer',
            description:
                'Share AM5 ROYAL with someone who needs home services.',
          ),
          DetailStep(
            icon: Icons.phone_android_rounded,
            title: 'Customer installs the app',
            description: 'The referred customer must install the customer app.',
          ),
          DetailStep(
            icon: Icons.home_repair_service_rounded,
            title: 'First service booking',
            description:
                'The customer must complete the first eligible '
                'service booking, subject to programme rules.',
          ),
          DetailStep(
            icon: Icons.percent_rounded,
            title: 'Earn up to 5%',
            description:
                'The applicable reward depends on the approved '
                'customer referral terms.',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = type == BenefitType.vendor
        ? const Color(0xFF7656D6)
        : type == BenefitType.customer
        ? const Color(0xFF2878E5)
        : const Color(0xFF009688);

    return Scaffold(
      backgroundColor: FreelancerBenefits.background,
      appBar: AppBar(
        backgroundColor: FreelancerBenefits.background,
        foregroundColor: navy,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [navy, accent],
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(35),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(mainIcon, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Refer more. Grow with AM5 ROYAL.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.card_giftcard_rounded,
                                color: navy,
                                size: 23,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Potential reward',
                                    style: TextStyle(
                                      color: Color(0xFF747D91),
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    reward,
                                    style: const TextStyle(
                                      color: navy,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'How it works',
                    style: TextStyle(
                      color: navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(steps.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: _DetailStepCard(
                        number: index + 1,
                        step: steps[index],
                        accent: accent,
                      ),
                    );
                  }),

                  // The requested information card has been removed.
                  // All other content remains in place.
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back to Benefits'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: navy,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: navy),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
}

class DetailStep {
  final IconData icon;
  final String title;
  final String description;

  const DetailStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _DetailStepCard extends StatelessWidget {
  final int number;
  final DetailStep step;
  final Color accent;

  const _DetailStepCard({
    required this.number,
    required this.step,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EBF3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withAlpha(24),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(step.icon, color: accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. ${step.title}',
                  style: const TextStyle(
                    color: FreelancerBenefits.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  step.description,
                  style: const TextStyle(
                    color: Color(0xFF747D91),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
