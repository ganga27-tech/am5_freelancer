import 'dart:convert';

import 'package:am5_freelancer_web/core/network/api_client.dart';
import 'package:am5_freelancer_web/core/network/freelance_api.dart';
import 'package:am5_freelancer_web/core/storage/secure_storage_service.dart';
import 'package:am5_freelancer_web/features/refer_earn/presentation/screens/refer_earn_screen.dart';
import 'package:am5_freelancer_web/features/refer_earn/presentation/vendor_referral_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('loads Vendor and Service histories independently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/links')) {
        final type = request.url.queryParameters['type'];
        final item = type == 'vendor'
            ? {
                'referral_type': 'vendor',
                'referral_code': 'vendor-code-123456789',
                'url': VendorReferralUrl.buildTracking(
                  referralCode: 'vendor-code-123456789',
                ).toString(),
                'expires_at': DateTime.now()
                    .add(const Duration(days: 4))
                    .toUtc()
                    .toIso8601String(),
                'status': 'active',
                'clicks_count': 12,
                'conversions_count': 2,
              }
            : {
                'referral_type': 'service',
                'referral_code': 'service-code-123456789',
                'url': 'https://am5royal.com/services/6?ref=service-code-123456789',
                'target_service_name': 'AC Repair Services',
                'expires_at': DateTime.now()
                    .add(const Duration(days: 5))
                    .toUtc()
                    .toIso8601String(),
                'status': 'active',
                'clicks_count': 7,
                'conversions_count': 1,
              };
        return _response({
          'items': [item],
        });
      }
      if (request.url.path.endsWith('/points/history')) {
        return _response({'items': []});
      }
      if (request.url.path.endsWith('/referrals/vendor/dashboard')) {
        return _response({
          'freelancer_name': 'Referral owner',
          'total_invitations': 4,
          'total_referral_link_clicks': null,
          'unique_link_opens': null,
          'play_store_clicks': null,
          'app_installs': 2,
          'vendor_registrations': 1,
          'pending_registrations': 1,
          'active_vendors': 1,
          'as_of_date': DateTime.now().toUtc().toIso8601String(),
        });
      }
      if (request.url.path.endsWith('/level-progress')) {
        return _response({
          'current_points': 275,
          'current_level': 'Silver',
          'next_level': 'Gold',
          'points_required_to_next_level': 726,
          'progress_percentage': 27.5,
        });
      }
      if (request.url.path.endsWith('/rewards/summary')) {
        return _response({
          'total_points': 300,
          'available_points': 240,
          'pending_points': 40,
          'redeemed_points': 20,
          'currency_equivalent': 240.0,
        });
      }
      return _response({});
    });
    addTearDown(client.close);

    final storage = _TestStorage();
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    String? sharedText;
    Uri? openedUri;
    final api = FreelanceApi(
      client: ApiClient(client: client, storage: storage),
      storage: storage,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReferEarnScreen(
          api: api,
          shareLink: (url) async => sharedText = url,
          openVendorLink: (uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }

    expect(
      requests
          .where((r) => r.url.path.endsWith('/links'))
          .map((r) => r.url.queryParameters['type'])
          .toSet(),
      {'vendor', 'service'},
    );
    expect(find.text('Your Vendor Referrals'), findsOneWidget);
    expect(find.text('Your Service Referrals'), findsOneWidget);
    expect(find.text('AC Repair Services'), findsOneWidget);
    expect(
      find.text(
        'Destination: api.am5royal.com/api/v1/referrals/vendor/click/vendor-code-123456789',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'https://am5royal.com/services/6?ref=service-code-123456789',
      ),
      findsOneWidget,
    );
    expect(find.text('Total points'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('Redeemed'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('Currency equivalent'), findsOneWidget);
    expect(find.text('Invite Vendors. Grow Together.'), findsNWidgets(2));
    expect(find.text('Freelancer: Referral owner'), findsOneWidget);
    expect(find.text('Total Invitations'), findsOneWidget);
    expect(find.text('Total Referral Link Clicks'), findsOneWidget);
    expect(find.text('Unique Visitors'), findsOneWidget);
    expect(find.text('Attributed App Installs'), findsOneWidget);
    expect(find.text('Completed Vendor Registrations'), findsOneWidget);
    expect(find.text('Pending Registrations'), findsOneWidget);
    expect(find.text('Active Vendors'), findsOneWidget);
    expect(find.text('Not tracked yet'), findsNWidgets(2));
    expect(find.textContaining('days left · Expires'), findsWidgets);
    expect(find.text('Code: vendor…6789'), findsOneWidget);

    await tester.ensureVisible(find.text('Copy full code').first);
    await tester.tap(find.text('Copy full code').first);
    expect(copiedText, 'vendor-code-123456789');
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Copy Link').first,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy Link').first);
    expect(
      copiedText,
      VendorReferralUrl.buildTracking(referralCode: 'vendor-code-123456789')
          .toString(),
    );
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Share Link').first,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Share Link').first);
    expect(
      sharedText,
      VendorReferralUrl.buildTracking(referralCode: 'vendor-code-123456789')
          .toString(),
    );
    await tester.ensureVisible(find.text('Open Play Store'));
    await tester.tap(find.text('Open Play Store'));
    expect(
      openedUri.toString(),
      VendorReferralUrl.buildTracking(referralCode: 'vendor-code-123456789')
          .toString(),
    );

    // Opening and refreshing the screen only perform reads; no history load
    // request is allowed to create a referral record.
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
}

http.Response _response(Map<String, dynamic> data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: const {'content-type': 'application/json'},
);

class _TestStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<String?> getTokenType() async => 'Bearer';
}
