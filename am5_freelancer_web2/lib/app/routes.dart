import 'package:flutter/material.dart';

import '../authentication/login/presentation/pages/login_page.dart';
import '../authentication/register/presentation/pages/register_page.dart';
import '../authentication/forgot_password/presentation/pages/forgot_password_page.dart';
import '../features/splash/presentation/pages/splash_page.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';

abstract final class AppRoutes {
  AppRoutes._();

  // ----------------------------------------------------------
  // ROUTE PATHS
  // ----------------------------------------------------------

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  static const String dashboard = '/dashboard';
  static const String services = '/services';
  static const String referEarn = '/refer-earn';

  static const String appInstallationActivation =
      '/app-installation-activation';

  static const String earningsWallet = '/earnings-wallet';
  static const String rewardsCashback = '/rewards-cashback';
  static const String profile = '/profile';
  static const String settings = '/settings';

  // ----------------------------------------------------------
  // APP ROUTES
  // ----------------------------------------------------------

  static final Map<String, WidgetBuilder> routes = {
    // Splash
    splash: (_) => const SplashPage(),

    // Authentication
    login: (_) => const LoginPage(),
    register: (_) => const RegisterPage(),
    forgotPassword: (_) => const ForgotPasswordPage(),

    // Home Dashboard
    dashboard: (_) => const DashboardScreen(initialMenu: 'Home'),

    // Services
    services: (_) => const DashboardScreen(initialMenu: 'Services'),

    // Refer & Earn
    referEarn: (_) => const DashboardScreen(initialMenu: 'Refer & Earn'),

    // App Installation & Activation
    appInstallationActivation: (_) =>
        const DashboardScreen(initialMenu: 'App Installation & Activation'),

    // Earnings & Wallet
    earningsWallet: (_) =>
        const DashboardScreen(initialMenu: 'Earnings & Wallet'),

    // Rewards & Cashback
    rewardsCashback: (_) =>
        const DashboardScreen(initialMenu: 'Rewards & Cashback'),

    // Profile
    profile: (_) => const DashboardScreen(initialMenu: 'Profile'),

    // Settings
    settings: (_) => const DashboardScreen(initialMenu: 'Settings'),
  };
}
