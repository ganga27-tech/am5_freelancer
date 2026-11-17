class SubCategoryModel {
  final int id;
  final String name;
  final String slug;
  final String imageUrl;
  final String bannerUrl;
  final bool activeStatus;
  final bool referralEligibility;

  const SubCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.imageUrl,
    required this.bannerUrl,
    required this.activeStatus,
    required this.referralEligibility,
  });

  factory SubCategoryModel.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);

    if (id == null || id <= 0) {
      throw const FormatException('Invalid subcategory ID');
    }

    final name = _parseRequiredString(json['name'], 'name');
    final slug = _parseRequiredString(json['slug'], 'slug');

    final activeStatus = json['active_status'];
    final referralEligibility = json['referral_eligibility'];

    if (activeStatus is! bool) {
      throw const FormatException('Invalid active_status');
    }

    if (referralEligibility is! bool) {
      throw const FormatException('Invalid referral_eligibility');
    }

    return SubCategoryModel(
      id: id,
      name: name,
      slug: slug,
      imageUrl: _parseOptionalString(json['image_url']),
      bannerUrl: _parseOptionalString(json['banner_url']),
      activeStatus: activeStatus,
      referralEligibility: referralEligibility,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _parseRequiredString(dynamic value, String fieldName) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid or missing $fieldName');
    }

    return value.trim();
  }

  static String _parseOptionalString(dynamic value) {
    if (value is String) return value.trim();
    return '';
  }
}
