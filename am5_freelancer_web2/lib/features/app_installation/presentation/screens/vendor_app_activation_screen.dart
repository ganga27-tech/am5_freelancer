import 'package:flutter/material.dart';

import 'reward_milestone_screen.dart';

class VendorAppActivationScreen extends StatelessWidget {
  const VendorAppActivationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RewardMilestoneScreen(
      title: 'Vendor Activation',
      subtitle: 'Explore Vendor activation and received-service rewards.',
      isInstallation: false,
      appType: 'vendor',
    );
  }
}
