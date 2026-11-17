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

final _url = VendorReferralUrl.buildTracking(
  referralCode: 'freelancer-demo-code',
).toString();

void main() {
  test('legacy direct Play Store referral URLs remain valid', () {
    final uri = VendorReferralUrl.build(
      referralCode: 'freelancer-demo-code',
      freelancerName: 'Referral Owner',
    );
    expect(
      VendorReferralUrl.matches(
        uri: uri,
        referralCode: 'freelancer-demo-code',
        freelancerName: 'Referral Owner',
      ),
      isTrue,
    );
  });
  testWidgets('new Vendor referrals use the first-party tracking URL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        return _response({
          'success': true,
          'data': {
            'referral_id': 'ref_test',
            'referral_code': 'freelancer-demo-code',
            'referral_type': 'vendor',
            'url': _url,
            'created_at': '2026-11-10T14:30:00Z',
            'expires_at': '2026-11-25T14:30:00Z',
            'status': 'active',
            'clicks_count': 0,
            'conversions_count': 0,
          },
        }, status: 201);
      }
      final data =
          request.url.path.endsWith('/links') ||
              request.url.path.endsWith('/points/history')
          ? {'items': <Object>[]}
          : request.url.path.endsWith('/referrals/vendor/dashboard')
          ? {'freelancer_name': 'Referral Owner'}
          : <String, Object>{};
      return _response({'success': true, 'data': data});
    });
    addTearDown(client.close);

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
    final storage = _TestStorage();
    final api = FreelanceApi(
      client: ApiClient(client: client, storage: storage),
      storage: storage,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReferEarnScreen(
            api: api,
            shareLink: (url) async => sharedText = url,
            openVendorLink: (uri) async {
              openedUri = uri;
              return true;
            },
          ),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Refer Vendor'));
    await _showConfirmation(tester);
    expect(
      find.widgetWithText(ElevatedButton, 'Creating link…'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.text(
        'Valid for 15 days. Share this invitation with vendors to join AM5 ROYAL.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('backend'), findsNothing);
    expect(find.textContaining('API'), findsNothing);
    expect(requests.where((request) => request.method == 'POST'), isEmpty);

    await tester.tap(find.text('Create Link'));
    await _settle(tester);

    final create = requests.singleWhere((request) => request.method == 'POST');
    expect(jsonDecode(create.body), {
      'referral_type': 'vendor',
      'validity_days': 15,
    });
    expect(find.text('Your Vendor invitation link is ready.'), findsOneWidget);
    expect(find.text('Vendor App Referral Link'), findsOneWidget);
    expect(find.text('Freelancer name: Referral Owner'), findsNWidgets(2));
    expect(find.text(_url), findsOneWidget);
    expect(find.text('Valid for 15 days.'), findsOneWidget);
    expect(find.textContaining('Valid until:'), findsOneWidget);
    expect(find.text('Copy Link'), findsOneWidget);
    expect(find.text('Share Link'), findsOneWidget);
    expect(find.text('Open Play Store'), findsOneWidget);
    expect(find.textContaining('Vendor Website'), findsNothing);

    await tester.tap(find.text('Copy Link'));
    await tester.pump();
    expect(copiedText, _url);

    // Reopen the invitation to check sharing and opening independently.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Refer Vendor'));
    await _showConfirmation(tester);
    await tester.tap(find.text('Create Link'));
    await _settle(tester);
    await tester.tap(find.text('Share Link'));
    await tester.pump();
    expect(
      sharedText,
      'AM5 ROYAL Vendor App invitation from Referral Owner:\n$_url',
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Refer Vendor'));
    await _showConfirmation(tester);
    await tester.tap(find.text('Create Link'));
    await _settle(tester);
    await tester.tap(find.text('Open Play Store'));
    await tester.pump();
    expect(openedUri.toString(), _url);
    expect(
      VendorReferralUrl.matches(
        uri: openedUri!,
        referralCode: 'freelancer-demo-code',
        freelancerName: 'Referral Owner',
      ),
      isTrue,
    );
  });

  testWidgets('expired invitation response shows a friendly message', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return _response({
          'success': true,
          'data': {
            'referral_id': 'ref_expired_test',
            'referral_code': 'expired-code',
            'referral_type': 'vendor',
            'url': 'https://vendor.am5royal.com/register?ref=expired-code',
            'created_at': '2026-10-01T14:30:00Z',
            'expires_at': '2026-10-02T14:30:00Z',
            'status': 'expired',
            'clicks_count': 0,
            'conversions_count': 0,
          },
        }, status: 201);
      }
      final data =
          request.url.path.endsWith('/links') ||
              request.url.path.endsWith('/points/history')
          ? {'items': <Object>[]}
          : request.url.path.endsWith('/referrals/vendor/dashboard')
          ? {'freelancer_name': 'Referral Owner'}
          : <String, Object>{};
      return _response({'success': true, 'data': data});
    });
    addTearDown(client.close);

    final storage = _TestStorage();
    final api = FreelanceApi(
      client: ApiClient(client: client, storage: storage),
      storage: storage,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReferEarnScreen(api: api)),
      ),
    );
    await _settle(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Refer Vendor'));
    await _showConfirmation(tester);
    await tester.tap(find.text('Create Link'));
    await _settle(tester);

    expect(
      find.text(
        'This invitation is invalid or expired. Please create a new invitation.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('debug'), findsNothing);
    expect(find.text(_url), findsNothing);
  });

  testWidgets('backend error details are replaced with friendly copy', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return _response({
          'success': false,
          'detail': 'DEBUG DATABASE TRACE: private implementation detail',
        }, status: 500);
      }
      final data =
          request.url.path.endsWith('/links') ||
              request.url.path.endsWith('/points/history')
          ? {'items': <Object>[]}
          : request.url.path.endsWith('/referrals/vendor/dashboard')
          ? {'freelancer_name': 'Referral Owner'}
          : <String, Object>{};
      return _response({'success': true, 'data': data});
    });
    addTearDown(client.close);

    final storage = _TestStorage();
    final api = FreelanceApi(
      client: ApiClient(client: client, storage: storage),
      storage: storage,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReferEarnScreen(api: api)),
      ),
    );
    await _settle(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Refer Vendor'));
    await _showConfirmation(tester);
    await tester.tap(find.text('Create Link'));
    await _settle(tester);

    expect(
      find.text(
        'We could not create your Vendor invitation right now. Please try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('DEBUG DATABASE TRACE'), findsNothing);
    expect(find.textContaining('private implementation detail'), findsNothing);
  });
}

http.Response _response(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
}

Future<void> _showConfirmation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

class _TestStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<String?> getTokenType() async => 'Bearer';
}
