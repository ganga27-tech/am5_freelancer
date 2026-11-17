import '../models/main_category_model.dart';
import '../models/sub_category_model.dart';

/// Builds only Vendor destinations confirmed by the live Freelancer catalog
/// and the URL mapping supplied for Home Services.
class VendorNavigationService {
  VendorNavigationService._();

  static const int homeServicesCategoryId = 37;
  static const String homeServicesCategorySlug = 'home-services';
  static const String _host = 'vendor.am5royal.com';

  static const Map<int, ({String catalogSlug, String vendorSlug})>
  _homeServiceDestinations = {
    3: (catalogSlug: 'pet-care-services', vendorSlug: 'petcareservices'),
    6: (catalogSlug: 'ac-repair-services', vendorSlug: 'acrepairservices'),
    7: (catalogSlug: 'plumbing-services', vendorSlug: 'plumbingservices'),
    16: (catalogSlug: 'cooking-services', vendorSlug: 'cookingservices'),
    11: (catalogSlug: 'cleaning-services', vendorSlug: 'cleaningservices'),
    12: (catalogSlug: 'driver-services', vendorSlug: 'driverservices'),
    13: (catalogSlug: 'immediate-services', vendorSlug: 'immediateservices'),
    14: (
      catalogSlug: 'pest-control-services',
      vendorSlug: 'pestcontrolservices',
    ),
    18: (catalogSlug: 'lab-test', vendorSlug: 'labtest'),
    9: (
      catalogSlug: 'smart-and-normal-electrical-services',
      vendorSlug: 'smartandnormalelectricalservices',
    ),
    8: (
      catalogSlug: 'smart-and-normal-appliance-repair-services',
      vendorSlug: 'smartandnormalappliancerepairservices',
    ),
    19: (catalogSlug: 'nursing-service', vendorSlug: 'nursingservice'),
    20: (catalogSlug: 'painting', vendorSlug: 'painting'),
    21: (catalogSlug: 'physiotherapy', vendorSlug: 'physiotherapy'),
    22: (catalogSlug: 'water-proofing', vendorSlug: 'waterproofing'),
    5: (catalogSlug: 'beauty-and-wellness', vendorSlug: 'beautyandwellness'),
    10: (
      catalogSlug: 'modular-works-and-interior-design',
      vendorSlug: 'modularworksandinteriordesign',
    ),
    15: (catalogSlug: 'caretaker-services', vendorSlug: 'caretakerservices'),
    1: (
      catalogSlug: '2-and-4-wheeler-services',
      vendorSlug: '2and4wheelerservices',
    ),
    17: (
      catalogSlug: 'home-and-online-classes',
      vendorSlug: 'homeandonlineclasses',
    ),
    43: (catalogSlug: 'solar-services', vendorSlug: 'solarservices'),
  };

  static Uri? homeService(
    MainCategoryModel mainCategory,
    SubCategoryModel subCategory,
  ) {
    if (mainCategory.id != homeServicesCategoryId ||
        mainCategory.slug != homeServicesCategorySlug ||
        !subCategory.activeStatus) {
      return null;
    }

    var destination = _homeServiceDestinations[subCategory.id];
    // Catalog IDs can differ by environment. The Vendor URL remains selected
    // only from the fixed allowlist and must still match the catalog slug.
    if (destination == null) {
      for (final candidate in _homeServiceDestinations.values) {
        if (candidate.catalogSlug == subCategory.slug) {
          destination = candidate;
          break;
        }
      }
    }
    if (destination == null || destination.catalogSlug != subCategory.slug) {
      return null;
    }

    return Uri.https(_host, '/map/homeservices/${destination.vendorSlug}');
  }

  static Uri homeServicesLanding() => Uri.https(_host, '/map/homeservices');

  /// Adds the referral API's existing `ref` parameter to a verified Vendor URL.
  /// Uri handles query encoding so referral codes are never concatenated raw.
  static Uri? withReferralCode(Uri destination, String referralCode) {
    final code = referralCode.trim();
    if (!isAllowedServiceUri(destination) || code.isEmpty) return null;

    return destination.replace(
      queryParameters: {...destination.queryParameters, 'ref': code},
    );
  }

  static bool isAllowedHomeServicesLandingUri(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == _host &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.path == '/map/homeservices';
  static int get mappedHomeServiceCount => _homeServiceDestinations.length;

  static bool isHomeServicesCategory(MainCategoryModel category) =>
      category.id == homeServicesCategoryId &&
      category.slug == homeServicesCategorySlug;

  static bool isAllowedServiceUri(Uri uri) =>
      _isAllowedServicePath(uri) && !uri.hasQuery;

  static bool isAllowedReferredServiceUri(Uri uri) {
    if (!_isAllowedServicePath(uri) || !uri.hasQuery || uri.hasFragment) {
      return false;
    }
    final referralCodes = uri.queryParametersAll['ref'];
    return uri.queryParametersAll.length == 1 &&
        referralCodes?.length == 1 &&
        referralCodes!.single.trim().isNotEmpty;
  }

  static bool _isAllowedServicePath(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == _host &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      _homeServiceDestinations.values.any(
        (destination) =>
            uri.path == '/map/homeservices/${destination.vendorSlug}',
      );
}
