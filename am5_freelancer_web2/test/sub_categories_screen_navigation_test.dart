import 'dart:convert';

import 'package:am5_freelancer_web/features/sub_categories/presentation/screens/sub_categories_screen.dart';
import 'package:am5_freelancer_web/features/sub_categories/services/category_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Home Services card opens the Vendor landing page', (
    tester,
  ) async {
    final requestedPaths = <String>[];
    final launchedUrls = <String>[];
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (call) async {
          if (call.method == 'launch') {
            launchedUrls.add(call.arguments['url'] as String);
            return true;
          }
          return null;
        });

    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path.endsWith('/service-categories')) {
        return _jsonResponse({
          'success': true,
          'data': [
            _mainCategory(id: 37, name: 'Home Services', slug: 'home-services'),
            _mainCategory(
              id: 42,
              name: 'Repair Services',
              slug: 'repair-services',
            ),
          ],
        });
      }
      if (request.url.path.endsWith('/service-categories/37/subcategories')) {
        return _jsonResponse({
          'success': true,
          'data': [
            _subCategory(
              id: 3,
              name: 'Pet Care Services',
              slug: 'pet-care-services',
            ),
          ],
        });
      }
      if (request.url.path.endsWith('/service-categories/42/subcategories')) {
        return _jsonResponse({
          'success': true,
          'data': [
            _subCategory(
              id: 81,
              name: 'Appliance Tune-up',
              slug: 'appliance-tune-up',
            ),
          ],
        });
      }
      return _jsonResponse({'success': false, 'message': 'Unexpected request'});
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SubCategoriesScreen(
          categoryService: CategoryService(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pet Care Services'), findsOneWidget);

    await tester.tap(find.text('Repair Services').first);
    await tester.pumpAndSettle();
    expect(find.text('Appliance Tune-up'), findsOneWidget);

    final homeSubcategoryRequestsBeforeTap = requestedPaths
        .where((path) => path == '/api/v1/service-categories/37/subcategories')
        .length;
    await tester.tap(find.text('Home Services').first);
    await tester.pumpAndSettle();
    expect(launchedUrls, ['https://vendor.am5royal.com/map/homeservices']);
    expect(
      requestedPaths
          .where(
            (path) => path == '/api/v1/service-categories/37/subcategories',
          )
          .length,
      homeSubcategoryRequestsBeforeTap,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, null);
  });
}

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json'},
);

Map<String, Object?> _mainCategory({
  required int id,
  required String name,
  required String slug,
}) => {
  'id': id,
  'name': name,
  'slug': slug,
  'category_image_url': '',
  'banner_url': '',
  'active_status': true,
  'display_order': id,
};

Map<String, Object?> _subCategory({
  required int id,
  required String name,
  required String slug,
}) => {
  'id': id,
  'name': name,
  'slug': slug,
  'image_url': '',
  'banner_url': '',
  'active_status': true,
  'referral_eligibility': true,
};
