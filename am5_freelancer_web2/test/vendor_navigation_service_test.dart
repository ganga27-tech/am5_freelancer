import 'package:flutter_test/flutter_test.dart';

import 'package:am5_freelancer_web/features/sub_categories/models/main_category_model.dart';
import 'package:am5_freelancer_web/features/sub_categories/models/sub_category_model.dart';
import 'package:am5_freelancer_web/features/sub_categories/services/vendor_navigation_service.dart';

void main() {
  const homeServices = MainCategoryModel(
    id: 37,
    name: 'Home Services',
    slug: 'home-services',
    categoryImageUrl: '',
    bannerUrl: '',
    activeStatus: true,
    displayOrder: 1,
  );

  const destinations = <int, String>{
    3: 'petcareservices',
    6: 'acrepairservices',
    7: 'plumbingservices',
    16: 'cookingservices',
    11: 'cleaningservices',
    12: 'driverservices',
    13: 'immediateservices',
    14: 'pestcontrolservices',
    18: 'labtest',
    9: 'smartandnormalelectricalservices',
    8: 'smartandnormalappliancerepairservices',
    19: 'nursingservice',
    20: 'painting',
    21: 'physiotherapy',
    22: 'waterproofing',
    43: 'solarservices',
    5: 'beautyandwellness',
    10: 'modularworksandinteriordesign',
    15: 'caretakerservices',
    1: '2and4wheelerservices',
    17: 'homeandonlineclasses',
  };

  test('maps all 21 API subcategory IDs to their exact Vendor URL', () {
    expect(VendorNavigationService.mappedHomeServiceCount, 21);
    final urls = <String>{};

    for (final entry in destinations.entries) {
      final service = SubCategoryModel(
        id: entry.key,
        name: 'service-${entry.key}',
        slug: _catalogSlugs[entry.key]!,
        imageUrl: '',
        bannerUrl: '',
        activeStatus: true,
        referralEligibility: true,
      );
      final uri = VendorNavigationService.homeService(homeServices, service);
      expect(uri, isNotNull);
      final mappedUri = uri!;

      expect(
        mappedUri.toString(),
        'https://vendor.am5royal.com/map/homeservices/${entry.value}',
      );
      expect(VendorNavigationService.isAllowedServiceUri(mappedUri), isTrue);
      urls.add(mappedUri.toString());

      final referralCode = 'referral_${entry.key}';
      final referredUri = VendorNavigationService.withReferralCode(
        mappedUri,
        referralCode,
      );
      expect(referredUri, isNotNull, reason: 'service ${entry.key}');
      expect(
        referredUri!.origin,
        mappedUri.origin,
        reason: 'service ${entry.key}',
      );
      expect(referredUri.path, mappedUri.path, reason: 'service ${entry.key}');
      expect(referredUri.queryParameters, {
        'ref': referralCode,
      }, reason: 'service ${entry.key}');
      expect(
        VendorNavigationService.isAllowedReferredServiceUri(referredUri),
        isTrue,
        reason: 'service ${entry.key}',
      );
    }

    expect(urls, hasLength(21));
  });

  test('builds unique referral URLs for selected Vendor services', () {
    const selectedServices = <int, String>{
      3: 'petcareservices',
      7: 'plumbingservices',
      21: 'physiotherapy',
    };

    for (final entry in selectedServices.entries) {
      final service = SubCategoryModel(
        id: entry.key,
        name: 'service-${entry.key}',
        slug: _catalogSlugs[entry.key]!,
        imageUrl: '',
        bannerUrl: '',
        activeStatus: true,
        referralEligibility: true,
      );
      final base = VendorNavigationService.homeService(homeServices, service)!;
      final share = VendorNavigationService.withReferralCode(base, 'REAL-CODE')!;

      expect(
        share.toString(),
        'https://vendor.am5royal.com/map/homeservices/${entry.value}?ref=REAL-CODE',
      );
      expect(VendorNavigationService.isAllowedReferredServiceUri(share), isTrue);
    }
  });

  test('keeps Solar routing valid when a deployment assigns a different ID', () {
    const solar = SubCategoryModel(
      id: 999,
      name: 'Solar Services',
      slug: 'solar-services',
      imageUrl: '',
      bannerUrl: '',
      activeStatus: true,
      referralEligibility: true,
    );
    expect(
      VendorNavigationService.homeService(homeServices, solar)?.toString(),
      'https://vendor.am5royal.com/map/homeservices/solarservices',
    );
  });

  test('rejects an ID/slug mismatch and inactive service', () {
    const wrongSlug = SubCategoryModel(
      id: 6,
      name: 'AC Repair',
      slug: 'plumbing-services',
      imageUrl: '',
      bannerUrl: '',
      activeStatus: true,
      referralEligibility: true,
    );
    const inactive = SubCategoryModel(
      id: 6,
      name: 'AC Repair',
      slug: 'ac-repair-services',
      imageUrl: '',
      bannerUrl: '',
      activeStatus: false,
      referralEligibility: true,
    );

    expect(
      VendorNavigationService.homeService(homeServices, wrongSlug),
      isNull,
    );
    expect(VendorNavigationService.homeService(homeServices, inactive), isNull);
  });

  test('recognizes Home Services by stable catalog ID and slug', () {
    expect(
      VendorNavigationService.isHomeServicesCategory(homeServices),
      isTrue,
    );
    expect(
      VendorNavigationService.isHomeServicesCategory(
        const MainCategoryModel(
          id: 1,
          name: 'Home Services',
          slug: 'home-services',
          categoryImageUrl: '',
          bannerUrl: '',
          activeStatus: true,
          displayOrder: 1,
        ),
      ),
      isFalse,
    );
  });

  test('rejects non-Vendor, generic, and modified service destinations', () {
    for (final url in [
      'https://am5royal.com/map/homeservices/petcareservices',
      'https://www.am5royal.com/map/homeservices/petcareservices',
      'https://vendor.am5royal.com/map',
      'https://vendor.am5royal.com/map/homeservices/unknown',
      'https://vendor.am5royal.com/map/homeservices/petcareservices?ref=x',
      'https://vendor.am5royal.com/map/homeservices/petcareservices#home',
      'http://vendor.am5royal.com/map/homeservices/petcareservices',
    ]) {
      expect(
        VendorNavigationService.isAllowedServiceUri(Uri.parse(url)),
        isFalse,
        reason: url,
      );
    }
  });

  test('encodes a referral code on the exact verified category URL', () {
    final destination = VendorNavigationService.homeService(
      homeServices,
      const SubCategoryModel(
        id: 3,
        name: 'Pet Care Services',
        slug: 'pet-care-services',
        imageUrl: '',
        bannerUrl: '',
        activeStatus: true,
        referralEligibility: true,
      ),
    )!;
    final referred = VendorNavigationService.withReferralCode(
      destination,
      'ref+code /with?reserved',
    )!;

    expect(referred.host, 'vendor.am5royal.com');
    expect(referred.path, '/map/homeservices/petcareservices');
    expect(referred.queryParameters, {'ref': 'ref+code /with?reserved'});
    expect(
      VendorNavigationService.isAllowedReferredServiceUri(referred),
      isTrue,
    );
  });

  test('rejects missing, duplicate, or unsupported referral query values', () {
    for (final url in [
      'https://vendor.am5royal.com/map/homeservices/petcareservices',
      'https://vendor.am5royal.com/map/homeservices/petcareservices?ref=',
      'https://vendor.am5royal.com/map/homeservices/petcareservices?ref=a&ref=b',
      'https://vendor.am5royal.com/map/homeservices/petcareservices?code=a',
      'https://vendor.am5royal.com/map/homeservices/unknown?ref=a',
      'https://vendor.am5royal.com/map/homeservices/petcareservices?ref=a#x',
    ]) {
      expect(
        VendorNavigationService.isAllowedReferredServiceUri(Uri.parse(url)),
        isFalse,
        reason: url,
      );
    }
    expect(
      VendorNavigationService.withReferralCode(
        Uri.parse('https://evil.example/path'),
        'some-code',
      ),
      isNull,
    );
  });
}

const _catalogSlugs = <int, String>{
  3: 'pet-care-services',
  6: 'ac-repair-services',
  7: 'plumbing-services',
  16: 'cooking-services',
  11: 'cleaning-services',
  12: 'driver-services',
  13: 'immediate-services',
  14: 'pest-control-services',
  18: 'lab-test',
  9: 'smart-and-normal-electrical-services',
  8: 'smart-and-normal-appliance-repair-services',
  19: 'nursing-service',
  20: 'painting',
  21: 'physiotherapy',
  22: 'water-proofing',
  43: 'solar-services',
  5: 'beauty-and-wellness',
  10: 'modular-works-and-interior-design',
  15: 'caretaker-services',
  1: '2-and-4-wheeler-services',
  17: 'home-and-online-classes',
};
