import 'package:flutter/material.dart';

import 'reward_milestone_screen.dart';

class CustomerAppInstallationScreen extends StatelessWidget {
  const CustomerAppInstallationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RewardMilestoneScreen(
      title: 'Customer App Installation',
      subtitle: 'Explore rewards for Customer App installations.',
      isInstallation: true,
      appType: 'customer',
    );
  }
}
