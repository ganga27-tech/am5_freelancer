import 'dart:convert';

import 'package:am5_freelancer_web/features/sub_categories/presentation/screens/sub_categories_screen.dart';
import 'package:am5_freelancer_web/features/sub_categories/services/category_service.dart';
import 'package:am5_freelancer_web/features/sub_categories/services/link_generation_service.dart';
import 'package:am5_freelancer_web/features/sub_categories/presentation/widgets/remote_service_image.dart';
import 'package:am5_freelancer_web/features/sub_categories/presentation/widgets/sub_category_card.dart';
import 'package:am5_freelancer_web/features/sub_categories/services/vendor_navigation_service.dart';
import 'package:am5_freelancer_web/core/storage/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:am5_freelancer_web/models/generated_link_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _services = <({int id, String name, String slug, String path})>[
  (
    id: 3,
    name: 'Pet Care Services',
    slug: 'pet-care-services',
    path: 'petcareservices',
  ),
  (
    id: 6,
    name: 'AC Repair Services',
    slug: 'ac-repair-services',
    path: 'acrepairservices',
  ),
  (
    id: 7,
    name: 'Plumbing Services',
    slug: 'plumbing-services',
    path: 'plumbingservices',
  ),
  (
    id: 16,
    name: 'Cooking Services',
    slug: 'cooking-services',
    path: 'cookingservices',
  ),
  (
    id: 11,
    name: 'Cleaning Services',
    slug: 'cleaning-services',
    path: 'cleaningservices',
  ),
  (
    id: 12,
    name: 'Driver Services',
    slug: 'driver-services',
    path: 'driverservices',
  ),
  (
    id: 13,
    name: 'Immediate Services',
    slug: 'immediate-services',
    path: 'immediateservices',
  ),
  (
    id: 14,
    name: 'Pest Control Services',
    slug: 'pest-control-services',
    path: 'pestcontrolservices',
  ),
  (id: 18, name: 'Lab Test', slug: 'lab-test', path: 'labtest'),
  (
    id: 9,
    name: 'Smart and Normal Electrical Services',
    slug: 'smart-and-normal-electrical-services',
    path: 'smartandnormalelectricalservices',
  ),
  (
    id: 8,
    name: 'Smart and Normal Appliance Repair Services',
    slug: 'smart-and-normal-appliance-repair-services',
    path: 'smartandnormalappliancerepairservices',
  ),
  (
    id: 19,
    name: 'Nursing Service',
    slug: 'nursing-service',
    path: 'nursingservice',
  ),
  (id: 20, name: 'Painting', slug: 'painting', path: 'painting'),
  (id: 21, name: 'Physiotherapy', slug: 'physiotherapy', path: 'physiotherapy'),
  (
    id: 22,
    name: 'Waterproofing',
    slug: 'water-proofing',
    path: 'waterproofing',
  ),
  (
    id: 5,
    name: 'Beauty and Wellness',
    slug: 'beauty-and-wellness',
    path: 'beautyandwellness',
  ),
  (
    id: 10,
    name: 'Modular Works and Interior Design',
    slug: 'modular-works-and-interior-design',
    path: 'modularworksandinteriordesign',
  ),
  (
    id: 15,
    name: 'Caretaker Services',
    slug: 'caretaker-services',
    path: 'caretakerservices',
  ),
  (
    id: 1,
    name: '2 and 4 Wheeler Services',
    slug: '2-and-4-wheeler-services',
    path: '2and4wheelerservices',
  ),
  (
    id: 17,
    name: 'Home and Online Classes',
    slug: 'home-and-online-classes',
    path: 'homeandonlineclasses',
  ),
  (
    id: 43,
    name: 'Solar Services',
    slug: 'solar-services',
    path: 'solarservices',
  ),
];

void main() {
  testWidgets(
    'each of the 21 service cards opens its exact Vendor route without generating a referral',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requestedPaths = <String>[];
      final launchedUrls = <String>[];
      final referralRequests = <({String type, int targetId, int days})>[];
      var referralSequence = 0;
      final referralService = _TestLinkGenerationService((
        type,
        targetSubServiceId,
        validityDays,
        targetServiceUrl,
      ) {
        referralRequests.add((
          type: type,
          targetId: targetSubServiceId,
          days: validityDays,
        ));
        referralSequence++;
        final referralUrl = VendorNavigationService.withReferralCode(
          Uri.parse(targetServiceUrl!),
          'unique_ref_$referralSequence',
        )!;
        return GeneratedLinkModel(
          referralId: 'test-ref-$referralSequence',
          referralCode: 'unique_ref_$referralSequence',
          referralType: type,
          targetServiceCategoryId: 37,
          targetServiceId: targetSubServiceId,
          url: referralUrl.toString(),
          createdAt: DateTime.now().toUtc(),
          expiresAt: DateTime.now().toUtc().add(Duration(days: validityDays)),
          status: 'active',
        );
      });
      const launcher = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcher, (call) async {
            if (call.method == 'launch') {
              launchedUrls.add(call.arguments['url'] as String);
              return true;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(launcher, null),
      );

      final client = MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path.endsWith('/service-categories')) {
          return _jsonResponse({
            'success': true,
            'data': [_mainCategory()],
          });
        }
        if (request.url.path.endsWith('/service-categories/37/subcategories')) {
          return _jsonResponse({
            'success': true,
            'data': _services.map(_subCategory).toList(),
          });
        }
        return _jsonResponse({
          'success': false,
          'message': 'Unexpected request',
        });
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SubCategoriesScreen(
            categoryService: CategoryService(client: client),
            linkGenerationServiceFactory: () => referralService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      var expectedLaunchCount = 0;
      Future<void> assertLaunch(
        String expectedUrl,
        String serviceName,
        int expectedTargetId,
      ) async {
        expectedLaunchCount++;
        expect(
          launchedUrls,
          hasLength(expectedLaunchCount),
          reason: 'one launch per tap: $serviceName',
        );
        final actual = launchedUrls.last;
        final uri = Uri.parse(actual);
        expect(uri.scheme, 'https', reason: serviceName);
        expect(uri.host, 'vendor.am5royal.com', reason: serviceName);
        expect(uri.path, Uri.parse(expectedUrl).path, reason: serviceName);
        expect(uri.queryParameters, isEmpty, reason: serviceName);
        expect(referralRequests, isEmpty, reason: 'opening $serviceName');
      }

      Future<void> tapAndAssert(
        Finder target,
        String expectedUrl,
        String serviceName,
        int expectedTargetId,
      ) async {
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        await assertLaunch(expectedUrl, serviceName, expectedTargetId);
      }

      for (final service in _services) {
        final expectedUrl =
            'https://vendor.am5royal.com/map/homeservices/${service.path}';
        final title = find.text(service.name).first;
        final card = find
            .ancestor(of: title, matching: find.byType(SubCategoryCard))
            .first;
        await tester.ensureVisible(title);
        final image = find
            .descendant(of: card, matching: find.byType(RemoteServiceImage))
            .first;
        await tapAndAssert(
          image,
          expectedUrl,
          '${service.name} image',
          service.id,
        );
        await tapAndAssert(
          title,
          expectedUrl,
          '${service.name} title',
          service.id,
        );
        expect(
          find.text('Generate Link'),
          findsWidgets,
          reason: 'referral action remains separate',
        );
      }
      expect(launchedUrls, hasLength(42));
      expect(referralRequests, isEmpty);
      expect(
        requestedPaths.where((path) => path.contains('/referrals/')),
        isEmpty,
        reason: 'the API client is injected in this widget test',
      );
    },
  );

  testWidgets(
    'service referral keeps the selected Vendor URL and adds only ref',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ({String type, int id, int days, String? targetUrl})? captured;
      const code = 'freelancer-unique-service-code';
      final linkService = _TestLinkGenerationService((
        type,
        targetSubServiceId,
        validityDays,
        targetServiceUrl,
      ) {
        captured = (
          type: type,
          id: targetSubServiceId,
          days: validityDays,
          targetUrl: targetServiceUrl,
        );
        final permanentUrl = Uri.parse(targetServiceUrl!);
        final referralUrl = VendorNavigationService.withReferralCode(
          permanentUrl,
          code,
        )!;
        final now = DateTime.now().toUtc();
        return GeneratedLinkModel(
          referralId: 'ref_qa_service',
          referralCode: code,
          referralType: type,
          targetServiceCategoryId: 37,
          targetServiceId: targetSubServiceId,
          url: referralUrl.toString(),
          createdAt: now,
          expiresAt: now.add(Duration(days: validityDays)),
          status: 'active',
        );
      });

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/service-categories')) {
          return _jsonResponse({
            'success': true,
            'data': [_mainCategory()],
          });
        }
        if (request.url.path.endsWith('/service-categories/37/subcategories')) {
          return _jsonResponse({
            'success': true,
            'data': [_subCategory(_services.first)],
          });
        }
        return _jsonResponse({
          'success': false,
          'message': 'Unexpected request',
        });
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SubCategoriesScreen(
            categoryService: CategoryService(client: client),
            linkGenerationServiceFactory: () => linkService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = find.text('Pet Care Services').first;
      final card = find
          .ancestor(of: title, matching: find.byType(SubCategoryCard))
          .first;
      final cardGenerateButton = find.descendant(
        of: card,
        matching: find.widgetWithText(ElevatedButton, 'Generate Link'),
      );
      await tester.ensureVisible(cardGenerateButton);
      await tester.tap(cardGenerateButton);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '15 Days'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(ElevatedButton, 'Generate Link'),
        ),
      );
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.type, 'service');
      expect(captured!.id, 3);
      expect(captured!.days, 15);
      expect(
        captured!.targetUrl,
        'https://vendor.am5royal.com/map/homeservices/petcareservices',
      );
      expect(
        find.text(
          'https://vendor.am5royal.com/map/homeservices/'
          'petcareservices?ref=$code',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shares the verified Vendor App Link with the backend referral code',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const code = 'freelancer-local-code';
      const generatedUrl =
          'http://127.0.0.1:8001/api/v1/referrals/service/click/$code';
      final categoryClient = MockClient((request) async {
        if (request.url.path.endsWith('/service-categories')) {
          return _jsonResponse({
            'success': true,
            'data': [_mainCategory()],
          });
        }
        if (request.url.path.endsWith('/service-categories/37/subcategories')) {
          return _jsonResponse({
            'success': true,
            'data': [_subCategory(_services.first)],
          });
        }
        return _jsonResponse({
          'success': false,
          'message': 'Unexpected request',
        });
      });
      final referralClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/referrals/links');
        return _jsonResponse({
          'success': true,
          'message': 'Referral link generated successfully',
          'data': {
            'referral_id': 'ref_901',
            'referral_code': code,
            'referral_type': 'service',
            'target_service_category_id': 37,
            'target_service_id': 3,
            'url': generatedUrl,
            'created_at': '2026-11-10T12:00:00Z',
            'expires_at': '2026-11-25T12:00:00Z',
            'status': 'active',
          },
        }, statusCode: 201);
      });
      final referralService = LinkGenerationService(
        client: referralClient,
        secureStorage: _TestReferralStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SubCategoriesScreen(
            categoryService: CategoryService(client: categoryClient),
            linkGenerationServiceFactory: () => referralService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = find
          .ancestor(
            of: find.text('Pet Care Services').first,
            matching: find.byType(SubCategoryCard),
          )
          .first;
      final cardGenerateButton = find.descendant(
        of: card,
        matching: find.widgetWithText(ElevatedButton, 'Generate Link'),
      );
      await tester.ensureVisible(cardGenerateButton);
      await tester.tap(cardGenerateButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(ElevatedButton, 'Generate Link'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'https://vendor.am5royal.com/map/homeservices/'
          'petcareservices?ref=$code',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pumpAndSettle();
    },
  );
}

typedef _GenerateReferral = GeneratedLinkModel Function(
  String type,
  int targetSubServiceId,
  int validityDays,
  String? targetServiceUrl,
);

class _TestLinkGenerationService extends LinkGenerationService {
  _TestLinkGenerationService(this._generate);

  final _GenerateReferral _generate;

  @override
  Future<GeneratedLinkModel> generateLink({
    required String referralType,
    required int targetSubServiceId,
    required int validityDays,
    String? targetServiceUrl,
  }) async => _generate(
    referralType,
    targetSubServiceId,
    validityDays,
    targetServiceUrl,
  );

  @override
  void dispose() {}
}

class _TestReferralStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'test-access-token';

  @override
  Future<String?> getTokenType() async => 'Bearer';
}

http.Response _jsonResponse(
  Map<String, Object?> body, {
  int statusCode = 200,
}) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: const {'content-type': 'application/json'},
);

Map<String, Object?> _mainCategory() => {
  'id': 37,
  'name': 'Home Services',
  'slug': 'home-services',
  'category_image_url': '',
  'banner_url': '',
  'active_status': true,
  'display_order': 1,
};

Map<String, Object?> _subCategory(
  ({int id, String name, String slug, String path}) service,
) => {
  'id': service.id,
  'name': service.name,
  'slug': service.slug,
  'image_url': '',
  'banner_url': '',
  'active_status': true,
  'referral_eligibility': true,
};
