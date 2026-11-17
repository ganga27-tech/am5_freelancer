import 'dart:convert';

import 'package:am5_freelancer_web/core/storage/secure_storage_service.dart';
import 'package:am5_freelancer_web/features/sub_categories/services/link_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'parses the exact HTTP 201 referral envelope and nested link fields',
    () async {
      final service = LinkGenerationService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'message': 'Referral link generated successfully',
              'data': {
                'referral_id': 'ref_456',
                'referral_code': 'freelancer-service-code',
                'referral_type': 'service',
                'target_service_category_id': 37,
                'target_service_id': 3,
                'url':
                    'http://127.0.0.1:8001/api/v1/referrals/service/click/'
                    'freelancer-service-code',
                'created_at': '2026-11-10T12:00:00Z',
                'expires_at': '2026-11-25T12:00:00Z',
                'status': 'active',
              },
            }),
            201,
            headers: const {'content-type': 'application/json'},
          ),
        ),
        secureStorage: _TestStorage(),
      );
      addTearDown(service.dispose);

      final link = await service.generateLink(
        referralType: 'service',
        targetSubServiceId: 3,
        validityDays: 15,
        targetServiceUrl:
            'https://vendor.am5royal.com/map/homeservices/petcareservices',
      );

      expect(link.referralId, 'ref_456');
      expect(link.referralCode, 'freelancer-service-code');
      expect(link.referralType, 'service');
      expect(link.targetServiceCategoryId, 37);
      expect(link.targetServiceId, 3);
      expect(
        link.url,
        'http://127.0.0.1:8001/api/v1/referrals/service/click/'
        'freelancer-service-code',
      );
      expect(link.createdAt, DateTime.utc(2026, 11, 10, 12));
      expect(link.expiresAt, DateTime.utc(2026, 11, 25, 12));
      expect(link.status, 'active');
    },
  );

  test(
    'posts the selected service with auth and parses the backend referral',
    () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Referral link generated successfully',
            'data': {
              'referral_id': 'ref_123',
              'referral_code': 'freelancer-unique-token',
              'referral_type': 'service',
              'target_service_category_id': 37,
              'target_service_id': 3,
              'target_service_name': 'Pet Care Services',
              'url':
                  'https://vendor.am5royal.com/map/homeservices/'
                  'petcareservices?ref=freelancer-unique-token',
              'created_at': '2026-11-10T12:00:00Z',
              'expires_at': '2026-11-25T12:00:00Z',
              'status': 'active',
              'clicks_count': 0,
              'conversions_count': 0,
            },
          }),
          201,
          headers: const {'content-type': 'application/json'},
        );
      });
      final service = LinkGenerationService(
        client: client,
        secureStorage: _TestStorage(tokenType: 'bearer'),
      );
      addTearDown(service.dispose);

      final referral = await service.generateLink(
        referralType: 'service',
        targetSubServiceId: 3,
        validityDays: 15,
        targetServiceUrl:
            'https://vendor.am5royal.com/map/homeservices/petcareservices',
      );

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v1/referrals/links');
      expect(captured!.headers['Authorization'], 'Bearer test-access-token');
      expect(jsonDecode(captured!.body), {
        'referral_type': 'service',
        'target_sub_service_id': 3,
        'target_service_url':
            'https://vendor.am5royal.com/map/homeservices/petcareservices',
        'validity_days': 15,
      });
      expect(referral.referralCode, 'freelancer-unique-token');
      expect(referral.referralType, 'service');
      expect(referral.targetServiceId, 3);
      expect(
        referral.url,
        'https://vendor.am5royal.com/map/homeservices/'
        'petcareservices?ref=freelancer-unique-token',
      );
      expect(referral.status, 'active');
      expect(referral.expiresAt, DateTime.utc(2026, 11, 25, 12));
    },
  );

  test('keeps customer referral requests at seven days', () async {
    http.Request? captured;
    final service = LinkGenerationService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'referral_id': 'ref_customer',
              'referral_code': 'customer-unique-token',
              'referral_type': 'customer',
              'target_service_id': 0,
              'url': 'https://am5royal.com/signup?ref=customer-unique-token',
              'created_at': '2026-11-10T12:00:00Z',
              'expires_at': '2026-11-17T12:00:00Z',
              'status': 'active',
            },
          }),
          201,
        );
      }),
      secureStorage: _TestStorage(),
    );
    addTearDown(service.dispose);

    final referral = await service.generateLink(
      referralType: 'customer',
      targetSubServiceId: 1,
      validityDays: 7,
    );

    expect(jsonDecode(captured!.body)['validity_days'], 7);
    expect(referral.referralCode, 'customer-unique-token');
    expect(referral.referralType, 'customer');
  });

  test('records copy action for the authenticated owned referral', () async {
    http.Request? captured;
    final service = LinkGenerationService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'accepted': true, 'duplicate': false},
          }),
          200,
        );
      }),
      secureStorage: _TestStorage(),
    );
    addTearDown(service.dispose);

    await service.recordAction(referralId: 'ref_321', eventType: 'copy');

    expect(captured?.method, 'POST');
    expect(captured?.url.path, '/api/v1/referrals/links/321/events');
    expect(captured?.headers['Authorization'], 'Bearer test-access-token');
    final payload = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(payload['event_type'], 'copy');
    expect(payload['platform'], isA<String>());
    expect((payload['event_id'] as String).length, 48);
  });

  test('shows field details for backend service validation errors', () async {
    final service = LinkGenerationService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': [
              {
                'loc': ['body', 'target_service_url'],
                'msg': 'Field required',
                'type': 'missing',
              },
            ],
          }),
          422,
        ),
      ),
      secureStorage: _TestStorage(),
    );
    addTearDown(service.dispose);

    await expectLater(
      service.generateLink(
        referralType: 'service',
        targetSubServiceId: 14,
        validityDays: 7,
        targetServiceUrl:
            'https://vendor.am5royal.com/map/homeservices/pestcontrolservices',
      ),
      throwsA(
        isA<LinkGenerationException>().having(
          (error) => error.message,
          'message',
          'target_service_url: Field required',
        ),
      ),
    );
  });

  test('preserves the backend error message for server failures', () async {
    final service = LinkGenerationService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'Referral service is offline',
          }),
          500,
        ),
      ),
      secureStorage: _TestStorage(),
    );
    addTearDown(service.dispose);

    await expectLater(
      service.generateLink(
        referralType: 'customer',
        targetSubServiceId: 1,
        validityDays: 7,
      ),
      throwsA(
        isA<LinkGenerationException>().having(
          (error) => error.message,
          'message',
          'Referral service is offline',
        ),
      ),
    );
  });

  test(
    'asks for reauthentication when the backend rejects the token',
    () async {
      final storage = _TestStorage();
      final service = LinkGenerationService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'detail': 'Authentication token required'}),
            401,
          ),
        ),
        secureStorage: storage,
      );
      addTearDown(service.dispose);

      await expectLater(
        service.generateLink(
          referralType: 'customer',
          targetSubServiceId: 1,
          validityDays: 7,
        ),
        throwsA(
          isA<LinkGenerationException>().having(
            (error) => error.message,
            'message',
            'Your session has expired. Please log in again.',
          ),
        ),
      );
      expect(storage.tokenDeleted, isTrue);
    },
  );
}

class _TestStorage extends SecureStorageService {
  _TestStorage({this.tokenType = 'Bearer'});

  final String tokenType;
  bool tokenDeleted = false;

  @override
  Future<String?> getAccessToken() async => 'test-access-token';

  @override
  Future<String?> getTokenType() async => tokenType;

  @override
  Future<void> deleteAccessToken() async {
    tokenDeleted = true;
  }
}
