import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, kReleaseMode, TargetPlatform;

abstract final class ApiConstants {
  ApiConstants._();

  static const String productionBaseUrl = 'https://api.am5royal.com';
  static const String localDevelopmentBaseUrl = 'http://127.0.0.1:8001';
  static const String localSwaggerUrl = '$localDevelopmentBaseUrl/docs';

  /// Chooses an API origin for the build target. Explicit overrides support
  /// staging and other controlled environments.
  static String resolveBaseUrl({
    required String override,
    required bool isRelease,
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    final configured = override.trim();
    if (configured.isNotEmpty) return configured;
    if (isRelease) return productionBaseUrl;
    if (!isWeb && platform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return localDevelopmentBaseUrl;
  }

  static final String baseUrl = resolveBaseUrl(
    override: const String.fromEnvironment('API_BASE_URL'),
    isRelease: kReleaseMode,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );

  static const String apiPrefix = '/api/v1';
  static const String register = '$apiPrefix/freelancer/auth/register';
  static const String login = '$apiPrefix/freelancer/auth/login';
  static const String forgotPassword =
      '$apiPrefix/freelancer/auth/forgot-password';
  static const String verifyOtp = '$apiPrefix/freelancer/auth/verify-otp';
  static const String resetPassword =
      '$apiPrefix/freelancer/auth/reset-password';
  static const String changePassword =
      '$apiPrefix/freelancer/auth/change-password';
  static const String banners = '$apiPrefix/banners';
  static const String demoVideos = '$apiPrefix/demo-videos';
  static const String serviceCategories = '$apiPrefix/service-categories';
  static String subCategories(int categoryId) =>
      '$serviceCategories/$categoryId/subcategories';

  static const String profile = '$apiPrefix/freelancer/profile';
  static const String profileCompletion = '$profile/completion';
  static const String profilePhoto = '$profile/photo';
  static const String bankDetails = '$apiPrefix/freelancer/bank-details';
  static const String kycDocuments = '$apiPrefix/freelancer/kyc/documents';
  static const String kycSubmissions = '$apiPrefix/freelancer/kyc/submissions';
  static const String kycStatus = '$apiPrefix/freelancer/kyc/status';
  static const String faceVerification =
      '$apiPrefix/freelancer/kyc/face-verification';
  static const String walletSummary = '$apiPrefix/wallet/summary';
  static const String walletTransactions = '$apiPrefix/wallet/transactions';
  static const String payoutRequest = '$apiPrefix/wallet/payout-request';
  static const String rewardsSummary = '$apiPrefix/rewards/summary';
  static const String rewardsHistory = '$apiPrefix/rewards/history';
  static const String referralLinks = '$apiPrefix/referrals/links';
  static const String vendorReferralDashboard =
      '$apiPrefix/referrals/vendor/dashboard';
  static const String serviceReferralDashboard =
      '$apiPrefix/referrals/services/dashboard';
  static const String referralSummary = '$apiPrefix/referrals/rewards/summary';
  static const String referralLevelProgress =
      '$apiPrefix/referrals/level-progress';
  static const String referralPointHistory =
      '$apiPrefix/referrals/points/history';
  static const String installationRules =
      '$apiPrefix/installation-rewards/rules';
  static const String installationStatistics =
      '$apiPrefix/installation-rewards/statistics';
  static const String installationTracking =
      '$apiPrefix/installation-rewards/tracking';
  static const String installationStatus =
      '$apiPrefix/installation-rewards/status';
  static const String installationEligibility =
      '$apiPrefix/installation-rewards/eligibility';
  static const String settings = '$apiPrefix/freelancer/settings';
  static const String notificationPreferences = '$settings/notifications';
  static const String privacyPreferences = '$settings/privacy';
  static const String securityPreferences = '$settings/security';
  static const String faqs = '$apiPrefix/faqs';
  static const String supportTickets = '$apiPrefix/support/tickets';
  static const String problemReports = '$apiPrefix/support/problem-reports';
  static const String legalPages = '$apiPrefix/legal-pages';
  static const String legalAcceptances =
      '$apiPrefix/freelancer/legal-acceptances';
  static const String notifications = '$apiPrefix/freelancer/notifications';
  static const String notificationUnreadCount = '$notifications/unread-count';
  static const String notificationReadAll = '$notifications/read-all';
  static const String notificationDevices = '$notifications/devices';
}
