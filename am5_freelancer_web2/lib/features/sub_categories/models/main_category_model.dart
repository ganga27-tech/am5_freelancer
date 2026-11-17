class MainCategoryModel {
  final int id;
  final String name;
  final String slug;
  final String categoryImageUrl;
  final String bannerUrl;
  final bool activeStatus;
  final int displayOrder;

  const MainCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.categoryImageUrl,
    required this.bannerUrl,
    required this.activeStatus,
    required this.displayOrder,
  });

  factory MainCategoryModel.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);

    if (id == null || id <= 0) {
      throw const FormatException('Invalid category ID');
    }

    final name = _parseRequiredString(json['name'], 'name');
    final slug = _parseRequiredString(json['slug'], 'slug');

    final activeStatus = json['active_status'];
    if (activeStatus is! bool) {
      throw const FormatException('Invalid active_status');
    }

    return MainCategoryModel(
      id: id,
      name: name,
      slug: slug,
      categoryImageUrl: _parseOptionalString(json['category_image_url']),
      bannerUrl: _parseOptionalString(json['banner_url']),
      activeStatus: activeStatus,
      displayOrder: _parseInt(json['display_order']) ?? 0,
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
