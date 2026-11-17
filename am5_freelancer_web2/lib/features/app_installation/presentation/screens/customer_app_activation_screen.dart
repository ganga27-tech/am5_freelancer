import 'package:flutter/material.dart';

import 'reward_milestone_screen.dart';

class CustomerAppActivationScreen extends StatelessWidget {
  const CustomerAppActivationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RewardMilestoneScreen(
      title: 'Customer Activation',
      subtitle: 'Explore Customer activation and received-service rewards.',
      isInstallation: false,
      appType: 'customer',
    );
  }
}
