/// Builds Google Play links that carry the existing backend-owned Vendor code.
class VendorReferralUrl {
  static const packageName = 'com.am5royal.am5royal';
  static const trackingHost = 'api.am5royal.com';
  static const trackingPath = '/api/v1/referrals/vendor/click';

  static final Uri playStoreListing = Uri.https(
    'play.google.com',
    '/store/apps/details',
    {'id': packageName},
  );

  static Uri buildTracking({required String referralCode}) {
    final code = referralCode.trim();
    if (code.isEmpty) {
      throw ArgumentError('A referral code is required.');
    }
    return Uri.https(trackingHost, '$trackingPath/$code');
  }

  static Uri build({
    required String referralCode,
    required String freelancerName,
  }) {
    final code = referralCode.trim();
    final name = freelancerName.trim();
    if (code.isEmpty || name.isEmpty) {
      throw ArgumentError('A referral code and Freelancer name are required.');
    }

    final installReferrer = Uri(
      queryParameters: {
        'referral_type': 'vendor',
        'referral_code': code,
        'referrer_name': name,
      },
    ).query;
    return playStoreListing.replace(
      queryParameters: {'id': packageName, 'referrer': installReferrer},
    );
  }

  static Map<String, String>? parseInstallReferrer(String value) {
    try {
      final params = Uri.splitQueryString(value);
      if (params['referral_type'] != 'vendor' ||
          params['referral_code']?.trim().isNotEmpty != true ||
          params['referrer_name']?.trim().isNotEmpty != true) {
        return null;
      }
      return params;
    } on FormatException {
      return null;
    }
  }

  static bool matches({
    required Uri uri,
    required String referralCode,
    required String freelancerName,
  }) {
    if (matchesTracking(uri: uri, referralCode: referralCode)) {
      return freelancerName.trim().isNotEmpty;
    }
    if (uri.scheme != 'https' ||
        uri.host != 'play.google.com' ||
        uri.path != '/store/apps/details' ||
        uri.queryParameters['id'] != packageName) {
      return false;
    }
    final campaign = parseInstallReferrer(
      uri.queryParameters['referrer'] ?? '',
    );
    return campaign?['referral_code'] == referralCode &&
        campaign?['referrer_name'] == freelancerName &&
        uri.queryParametersAll['referrer']?.length == 1;
  }

  static bool matchesTracking({
    required Uri uri,
    required String referralCode,
  }) =>
      uri.scheme == 'https' &&
      uri.host == trackingHost &&
      uri.pathSegments.length == 6 &&
      uri.pathSegments.take(5).join('/') == trackingPath.substring(1) &&
      uri.pathSegments.last == referralCode &&
      uri.query.isEmpty &&
      uri.fragment.isEmpty;
}
