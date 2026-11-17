import 'dart:convert';

import 'package:am5_freelancer_web/core/network/api_client.dart';
import 'package:am5_freelancer_web/core/network/freelance_api.dart';
import 'package:am5_freelancer_web/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemoryStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'unit-test-token';

  @override
  Future<String?> getTokenType() async => 'Bearer';
}

void main() {
  test('installation progress maps backend statistics and tracking envelope',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final isStatistics = request.url.path.endsWith('/statistics');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': isStatistics
              ? {
                  'customer_installs': 7,
                  'customer_activations': 4,
                  'customer_eligible': 2,
                  'vendor_installs': 1,
                  'vendor_activations': 0,
                  'vendor_eligible': 0,
                  'as_of_date': '2026-11-10',
                }
              : {
                  'items': [
                    {
                      'tracking_id': 'record-1',
                      'app_type': 'customer',
                      'referral_code': 'TESTCODE',
                      'install_date': '2026-11-01T00:00:00Z',
                      'activation_date': null,
                      'retention_days_completed': 0,
                      'retention_status': 'pending',
                      'eligibility_status': 'in_review',
                      'reward_status': 'pending',
                    },
                  ],
                  'page': 1,
                  'limit': 10,
                  'total': 1,
                  'hasMore': false,
                },
        }),
        200,
      );
    });
    final api = FreelanceApi(
      client: ApiClient(client: client, storage: _MemoryStorage()),
      storage: _MemoryStorage(),
    );
    addTearDown(client.close);

    final stats = await api.installationStatistics();
    final tracking = await api.installationTracking(appType: 'customer');

    expect(stats['customer_installs'], 7);
    expect(tracking['items'], hasLength(1));
    expect(requests, hasLength(2));
    expect(requests.every((request) =>
        request.headers['authorization'] == 'Bearer unit-test-token'), isTrue);
    expect(requests.last.url.queryParameters['app_type'], 'customer');
  });

  test('installation status does not send unsupported app_type filter',
      () async {
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({'success': true, 'data': <dynamic>[]}),
        200,
      );
    });
    final api = FreelanceApi(
      client: ApiClient(client: client, storage: _MemoryStorage()),
      storage: _MemoryStorage(),
    );
    addTearDown(client.close);

    expect(await api.installationStatus(), isEmpty);
    expect(requestedUri!.queryParameters.containsKey('app_type'), isFalse);
  });
}
