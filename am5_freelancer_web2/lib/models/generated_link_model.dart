class GeneratedLinkModel {
  final String referralId;
  final String referralCode;
  final String referralType;
  final int targetServiceCategoryId;
  final int targetServiceId;
  final String? targetServiceName;
  final String url;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String status;
  final int validityDays;
  final bool reusedExisting;

  const GeneratedLinkModel({
    required this.referralId,
    required this.referralCode,
    required this.referralType,
    this.targetServiceCategoryId = 0,
    required this.targetServiceId,
    this.targetServiceName,
    required this.url,
    this.createdAt,
    this.expiresAt,
    required this.status,
    this.validityDays = 15,
    this.reusedExisting = false,
  });

  factory GeneratedLinkModel.fromResponse(Map<String, dynamic> response) {
    final data = response['data'];

    if (data is! Map) {
      throw const FormatException('Invalid referral response data');
    }

    final json = Map<String, dynamic>.from(data);

    final url = json['url'];

    if (url is! String || url.trim().isEmpty) {
      throw const FormatException('Generated URL is missing');
    }

    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
    final referralId = json['referral_id']?.toString().trim();
    final referralCode = json['referral_code']?.toString();
    if (referralId == null ||
        referralId.isEmpty ||
        createdAt == null ||
        expiresAt == null ||
        referralCode == null ||
        referralCode.isEmpty) {
      throw const FormatException(
        'Referral response is missing its ID, expiry, or token data',
      );
    }

    return GeneratedLinkModel(
      referralId: referralId,
      referralCode: referralCode,
      referralType: json['referral_type']?.toString() ?? '',
      targetServiceCategoryId:
          int.tryParse(json['target_service_category_id']?.toString() ?? '') ??
          0,
      targetServiceId:
          int.tryParse(json['target_service_id']?.toString() ?? '') ?? 0,
      targetServiceName: json['target_service_name']?.toString(),
      url: url.trim(),
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: json['status']?.toString() ?? '',
      validityDays:
          int.tryParse(json['validity_days']?.toString() ?? '') ?? 15,
      reusedExisting: json['reused_existing'] == true,
    );
  }
}
