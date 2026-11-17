import 'dart:convert';

import 'package:am5_freelancer_web/features/dashboard/data/dashboard_banner_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses the backend banner envelope and requests home freelancer data', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'message': 'Active banners retrieved successfully',
          'data': [
            {
              'id': 'banner-1',
              'title': 'Home banner',
              'subtitle': 'From the API',
              'image_url': 'https://media.example.test/home.webp',
              'mobile_image_url': 'https://media.example.test/home-mobile.webp',
              'placement': 'home',
              'target_audience': 'freelancer',
              'action_type': 'navigate',
              'action_value': '/services',
              'priority': 7,
              'active': true,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = DashboardBannerService(client: client);
    addTearDown(client.close);

    final banners = await service.fetchHomeBanners();

    expect(requestedUri.queryParameters, {
      'placement': 'home',
      'audience': 'freelancer',
    });
    expect(banners, hasLength(1));
    expect(banners.single.id, 'banner-1');
    expect(banners.single.mobileImageUrl, 'https://media.example.test/home-mobile.webp');
    expect(banners.single.actionValue, '/services');
  });

  test('surfaces backend and malformed response errors instead of fake banners', () async {
    final unavailable = DashboardBannerService(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    expect(
      unavailable.fetchHomeBanners(),
      throwsA(isA<DashboardBannerException>()),
    );

    final malformed = DashboardBannerService(
      client: MockClient((_) async => http.Response('<html>fallback</html>', 200)),
    );
    expect(
      malformed.fetchHomeBanners(),
      throwsA(isA<DashboardBannerException>()),
    );
  });
}
