import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';


import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import 'api_client.dart';

/// Endpoint-level API facade for modules in the freelancer portal.
class FreelanceApi {
  FreelanceApi({ApiClient? client, SecureStorageService? storage})
    : _api = client ?? ApiClient(storage: storage),
      _ownsClient = client == null,
      _storage = storage ?? SecureStorageService();

  final ApiClient _api;
  final bool _ownsClient;
  final SecureStorageService _storage;

  Future<Map<String, dynamic>> profile() async =>
      _map(await _api.get(ApiConstants.profile));
  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> fields,
  ) async => _map(await _api.patch(ApiConstants.profile, body: fields));
  Future<Map<String, dynamic>> profileCompletion() async =>
      _map(await _api.get(ApiConstants.profileCompletion));
  Future<Map<String, dynamic>> submitKyc({
    String? aadhaar,
    String? pan,
    String? gst,
    List<int> documentIds = const [],
  }) async => _map(
    await _api.post(
      ApiConstants.kycSubmissions,
      body: {
        if (aadhaar != null && aadhaar.isNotEmpty) 'aadhaar_number': aadhaar,
        if (pan != null && pan.isNotEmpty) 'pan_number': pan,
        if (gst != null && gst.isNotEmpty) 'gst_number': gst,
        'document_ids': documentIds,
      },
    ),
  );
  Future<Map<String, dynamic>> kycStatus() async =>
      _map(await _api.get(ApiConstants.kycStatus));
  Future<Map<String, dynamic>> faceVerificationStart({
    bool consent = true,
  }) async => _map(
    await _api.post(ApiConstants.faceVerification, body: {'consent': consent}),
  );
  Future<Map<String, dynamic>> faceVerificationStatus() async =>
      _map(await _api.get('${ApiConstants.faceVerification}/status'));
  Future<Map<String, dynamic>> bankDetails() async =>
      _map(await _api.get(ApiConstants.bankDetails));
  Future<Map<String, dynamic>> updateBankDetails(
    Map<String, dynamic> fields,
  ) async => _map(await _api.put(ApiConstants.bankDetails, body: fields));
  Future<Map<String, dynamic>> walletSummary() async =>
      _map(await _api.get(ApiConstants.walletSummary));
  Future<Map<String, dynamic>> walletTransactions({
    int page = 1,
    int limit = 10,
    String? type,
    String? category,
    String? status,
  }) async => _map(
    await _api.get(
      ApiConstants.walletTransactions,
      query: {
        'page': '$page',
        'limit': '$limit',
        'sort': 'createdAt:desc',
        'type': ?type,
        'category': ?category,
        'status': ?status,
      },
    ),
  );
  Future<Map<String, dynamic>> requestPayout(double amount) async => _map(
    await _api.post(ApiConstants.payoutRequest, body: {'amount': amount}),
  );
  Future<Map<String, dynamic>> rewardsSummary() async =>
      _map(await _api.get(ApiConstants.rewardsSummary));
  Future<Map<String, dynamic>> rewardsHistory({
    int page = 1,
    int limit = 10,
  }) async => _map(
    await _api.get(
      ApiConstants.rewardsHistory,
      query: {'page': '$page', 'limit': '$limit'},
    ),
  );
  Future<Map<String, dynamic>> referralSummary() async =>
      _map(await _api.get(ApiConstants.referralSummary));
  Future<Map<String, dynamic>> vendorReferralDashboard() async =>
      _map(await _api.get(ApiConstants.vendorReferralDashboard));
  Future<Map<String, dynamic>> serviceReferralDashboard() async =>
      _map(await _api.get(ApiConstants.serviceReferralDashboard));
  Future<Map<String, dynamic>> createReferralLink({
    required String type,
    int? targetSubcategoryId,
    int validityDays = 15,
  }) async => _map(
    await _api.post(
      ApiConstants.referralLinks,
      body: {
        'referral_type': type,
        'target_sub_service_id': ?targetSubcategoryId,
        'validity_days': validityDays,
      },
    ),
  );
  Future<Map<String, dynamic>> recordReferralAction({
    required String referralId,
    required String eventType,
  }) async {
    final match = RegExp(r'^ref_(\d+)$').firstMatch(referralId.trim());
    final id = int.tryParse(match?.group(1) ?? '');
    if (id == null || id <= 0) {
      throw const ApiException('Invalid referral link ID.');
    }
    if (eventType != 'copy' && eventType != 'share_initiated') {
      throw const ApiException('Unsupported referral action.');
    }
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    final eventId = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            TargetPlatform.windows => 'windows',
            TargetPlatform.macOS => 'macos',
            TargetPlatform.linux => 'linux',
            _ => 'unknown',
          };
    return _map(
      await _api.post(
        '${ApiConstants.referralLinks}/$id/events',
        body: {
          'event_id': eventId,
          'event_type': eventType,
          'platform': platform,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> referralEventHistory({
    required String referralId,
  }) async {
    final match = RegExp(r'^ref_(\d+)$').firstMatch(referralId.trim());
    final id = int.tryParse(match?.group(1) ?? '');
    if (id == null || id <= 0) {
      throw const ApiException('Invalid referral link ID.');
    }
    return _map(await _api.get('${ApiConstants.referralLinks}/$id/events'));
  }

  Future<Map<String, dynamic>> referralLinks({
    int page = 1,
    int limit = 10,
    String? type,
  }) async => _map(
    await _api.get(
      ApiConstants.referralLinks,
      query: {
        'page': '$page',
        'limit': '$limit',
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      },
    ),
  );
  Future<Map<String, dynamic>> referralLevelProgress() async =>
      _map(await _api.get(ApiConstants.referralLevelProgress));
  Future<Map<String, dynamic>> referralPointHistory({
    int page = 1,
    int limit = 10,
  }) async => _map(
    await _api.get(
      ApiConstants.referralPointHistory,
      query: {'page': '$page', 'limit': '$limit'},
    ),
  );
  Future<List<dynamic>> banners({String placement = 'home'}) async => _list(
    await _api.get(
      ApiConstants.banners,
      query: {'placement': placement, 'audience': 'freelancer'},
    ),
  );
  Future<List<dynamic>> demoVideos() async => _list(
    await _api.get(
      ApiConstants.demoVideos,
      query: const {'audience': 'freelancer'},
    ),
  );
  Future<List<dynamic>> categories() async =>
      _list(await _api.get(ApiConstants.serviceCategories));
  Future<List<dynamic>> subcategories(int categoryId) async =>
      _list(await _api.get(ApiConstants.subCategories(categoryId)));
  Future<List<dynamic>> faqs() async =>
      _list(await _api.get(ApiConstants.faqs));
  Future<Map<String, dynamic>> installationRules(String appType) async => _map(
    await _api.get(
      ApiConstants.installationRules,
      query: {'app_type': appType},
    ),
  );
  Future<Map<String, dynamic>> installationStatistics() async =>
      _map(await _api.get(ApiConstants.installationStatistics));
  Future<Map<String, dynamic>> installationTracking({
    String? appType,
    int page = 1,
    int limit = 10,
  }) async => _map(
    await _api.get(
      ApiConstants.installationTracking,
      query: {
        'page': '$page',
        'limit': '$limit',
        if (appType != null && appType.trim().isNotEmpty) 'app_type': appType,
      },
    ),
  );
  Future<List<dynamic>> installationStatus({String? status}) async => _list(
    await _api.get(
      ApiConstants.installationStatus,
      query: {if (status != null && status.trim().isNotEmpty) 'status': status},
    ),
  );
  Future<Map<String, dynamic>> installationEligibility(String appType) async =>
      _map(
        await _api.get(
          ApiConstants.installationEligibility,
          query: {'app_type': appType},
        ),
      );
  Future<Map<String, dynamic>> submitKycTicket(
    Map<String, dynamic> fields,
  ) async => _map(await _api.post(ApiConstants.kycSubmissions, body: fields));
  Future<Map<String, dynamic>> settings() async =>
      _map(await _api.get(ApiConstants.settings));
  Future<Map<String, dynamic>> updateNotifications(
    Map<String, dynamic> fields,
  ) async => _map(
    await _api.patch(ApiConstants.notificationPreferences, body: fields),
  );
  Future<Map<String, dynamic>> updatePrivacy(
    Map<String, dynamic> fields,
  ) async =>
      _map(await _api.patch(ApiConstants.privacyPreferences, body: fields));
  Future<Map<String, dynamic>> updateSecurity(
    Map<String, dynamic> fields,
  ) async =>
      _map(await _api.patch(ApiConstants.securityPreferences, body: fields));
  Future<Map<String, dynamic>> notifications({
    int page = 1,
    int limit = 20,
  }) async => _map(
    await _api.get(
      ApiConstants.notifications,
      query: {'page': '$page', 'limit': '$limit'},
    ),
  );
  Future<Map<String, dynamic>> unreadNotificationCount() async =>
      _map(await _api.get(ApiConstants.notificationUnreadCount));
  Future<void> markNotificationRead(String id) async =>
      _api.patch('${ApiConstants.notifications}/$id/read');
  Future<void> markAllNotificationsRead() async =>
      _api.patch(ApiConstants.notificationReadAll);
  Future<List<dynamic>> legalPages({String? slug}) async =>
      _list(await _api.get(ApiConstants.legalPages, query: {'slug': ?slug}));
  Future<Map<String, dynamic>> acceptLegal(String slug, String version) async =>
      _map(
        await _api.post(
          ApiConstants.legalAcceptances,
          body: {'document_slug': slug, 'document_version': version},
        ),
      );
  Future<Map<String, dynamic>> submitSupportTicket(
    Map<String, dynamic> fields,
  ) async => _map(await _api.post(ApiConstants.supportTickets, body: fields));
  Future<Map<String, dynamic>> reportProblem(
    Map<String, dynamic> fields,
  ) async => _map(await _api.post(ApiConstants.problemReports, body: fields));
  Future<Map<String, dynamic>> changePassword(
    String current,
    String next,
    String confirm,
  ) async => _map(
    await _api.post(
      ApiConstants.changePassword,
      body: {
        'current_password': current,
        'new_password': next,
        'confirm_new_password': confirm,
      },
    ),
  );
  Future<Map<String, dynamic>> forgotPassword(
    String identifier, {
    String channel = 'sms',
  }) async => _map(
    await _api.post(
      ApiConstants.forgotPassword,
      body: {'identifier': identifier, 'preferred_channel': channel},
    ),
  );
  Future<Map<String, dynamic>> verifyOtp(
    String challengeId,
    String otp,
  ) async => _map(
    await _api.post(
      ApiConstants.verifyOtp,
      body: {
        'challenge_id': challengeId,
        'otp': otp,
        'purpose': 'password_recovery',
      },
    ),
  );
  Future<Map<String, dynamic>> resetPassword(
    String token,
    String password,
    String confirm,
  ) async => _map(
    await _api.post(
      ApiConstants.resetPassword,
      body: {
        'reset_token': token,
        'new_password': password,
        'confirm_new_password': confirm,
      },
    ),
  );

  Future<Map<String, dynamic>> uploadKycDocument(
    Uint8List bytes,
    String filename,
    String documentType, {
    String contentType = 'application/octet-stream',
  }) async => _map(
    await _multipart(
      ApiConstants.kycDocuments,
      bytes,
      filename,
      contentType,
      fields: {'document_type': documentType},
    ),
  );

  Future<Map<String, dynamic>> uploadProfilePhoto(
    Uint8List bytes,
    String filename, {
    String contentType = 'image/jpeg',
  }) async => _map(
    await _multipart(ApiConstants.profilePhoto, bytes, filename, contentType),
  );

  Future<Map<String, dynamic>> _multipart(
    String path,
    Uint8List bytes,
    String filename,
    String contentType, {
    Map<String, String> fields = const {},
  }) async {
    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('Please log in to continue.', statusCode: 401);
    }
    final tokenType = (await _storage.getTokenType()) ?? 'Bearer';
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse(ApiConstants.baseUrl).resolve(path.substring(1)),
          )
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] =
              '${tokenType.trim().isEmpty ? 'Bearer' : tokenType} $token'
          ..fields.addAll(fields)
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
              contentType: _mediaType(contentType),
            ),
          );
    try {
      final response = await request.send().timeout(ApiClient.timeout);
      final body = await response.stream.bytesToString();
      final decoded = body.isEmpty ? null : jsonDecode(body);
      if (response.statusCode == 401) {
        await _storage.deleteAccessToken();
        throw const ApiException(
          'Your session has expired. Please log in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Upload failed (HTTP ${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      if (decoded is Map && decoded['success'] == false) {
        throw ApiException(decoded['message']?.toString() ?? 'Upload failed.');
      }
      return _map(decoded is Map ? decoded['data'] : decoded);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Unable to upload the file. Check your connection and try again.',
      );
    }
  }

  MediaType _mediaType(String value) {
    final pieces = value.split('/');
    return MediaType(
      pieces.first,
      pieces.length > 1 ? pieces.last : 'octet-stream',
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const ApiException('The server returned an invalid data format.');
  }

  static List<dynamic> _list(dynamic value) {
    if (value is List) return value;
    throw const ApiException('The server returned an invalid list format.');
  }

  void dispose() {
    if (_ownsClient) _api.dispose();
  }
}
