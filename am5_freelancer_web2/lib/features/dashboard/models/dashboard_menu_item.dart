import 'package:flutter/material.dart';

class DashboardMenuItem {
  final String title;
  final IconData icon;

  const DashboardMenuItem({required this.title, required this.icon});

  static const List<DashboardMenuItem> items = [
    DashboardMenuItem(title: 'Home', icon: Icons.home_rounded),
    DashboardMenuItem(title: 'Services', icon: Icons.category_rounded),
    DashboardMenuItem(title: 'Refer & Earn', icon: Icons.people_alt_rounded),
    DashboardMenuItem(
      title: 'App Installation & Activation',
      icon: Icons.app_registration_rounded,
    ),
    DashboardMenuItem(
      title: 'Earnings & Wallet',
      icon: Icons.account_balance_wallet_rounded,
    ),
    DashboardMenuItem(
      title: 'Rewards & Cashback',
      icon: Icons.card_giftcard_rounded,
    ),
    DashboardMenuItem(title: 'Profile', icon: Icons.person_rounded),
    DashboardMenuItem(title: 'Settings', icon: Icons.settings_rounded),
  ];
}
