import 'package:flutter/material.dart';

import 'reward_milestone_screen.dart';

class VendorAppInstallationScreen extends StatelessWidget {
  const VendorAppInstallationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RewardMilestoneScreen(
      title: 'Vendor App Installation',
      subtitle: 'Explore rewards for Vendor App installations.',
      isInstallation: true,
      appType: 'vendor',
    );
  }
}
