import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/session_events.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../models/generated_link_model.dart';

class LinkGenerationException implements Exception {
  final String message;

  const LinkGenerationException(this.message);

  @override
  String toString() => message;
}

class LinkGenerationService {
  LinkGenerationService({
    http.Client? client,
    SecureStorageService? secureStorage,
  }) : _client = client ?? http.Client(),
       _secureStorage = secureStorage ?? SecureStorageService();

  final http.Client _client;
  final SecureStorageService _secureStorage;

  Future<GeneratedLinkModel> generateLink({
    required String referralType,
    required int targetSubServiceId,
    required int validityDays,
    String? targetServiceUrl,
  }) async {
    final type = referralType.trim().toLowerCase();

    if (type != 'vendor' && type != 'customer' && type != 'service') {
      throw const LinkGenerationException(
        'Referral type must be vendor, customer, or service.',
      );
    }

    if (targetSubServiceId <= 0) {
      throw const LinkGenerationException('Invalid subcategory selected.');
    }

    if (validityDays != 7 && validityDays != 15) {
      throw const LinkGenerationException('Validity must be 7 or 15 days.');
    }

    final selectedServiceUrl = targetServiceUrl?.trim();
    if (type == 'service' &&
        (selectedServiceUrl == null || selectedServiceUrl.isEmpty)) {
      throw const LinkGenerationException(
        'A verified Vendor destination is required for service referrals.',
      );
    }

    final token = (await _secureStorage.getAccessToken())?.trim();

    if (token == null || token.isEmpty) {
      throw const LinkGenerationException(
        'Session expired. Please login again.',
      );
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/referrals/links');

    try {
      final requestBody = <String, Object>{
        'referral_type': type,
        'target_sub_service_id': targetSubServiceId,
        'validity_days': validityDays,
      };
      if (type == 'service') {
        requestBody['target_service_url'] = selectedServiceUrl!;
      }

      final response = await _client
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> responseData = {};

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          responseData = Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        throw const LinkGenerationException(
          'Invalid response received from server.',
        );
      }

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          responseData['success'] == true) {
        try {
          return GeneratedLinkModel.fromResponse(responseData);
        } on FormatException {
          throw const LinkGenerationException(
            'Referral was created, but the response format is invalid.',
          );
        } catch (_) {
          throw const LinkGenerationException(
            'Unable to read the generated referral link.',
          );
        }
      }

      if (response.statusCode == 401) {
        await _secureStorage.deleteAccessToken();
        SessionEvents.notifyExpired();
      }

      throw LinkGenerationException(
        _getErrorMessage(response.statusCode, responseData),
      );
    } on TimeoutException {
      throw const LinkGenerationException(
        'Server is taking too long to respond. Try again.',
      );
    } on http.ClientException {
      throw const LinkGenerationException('Unable to connect to the server.');
    } on LinkGenerationException {
      rethrow;
    } catch (_) {
      throw const LinkGenerationException(
        'Something went wrong while generating the referral link.',
      );
    }
  }

  Future<void> recordAction({
    required String referralId,
    required String eventType,
  }) async {
    if (eventType != 'copy' && eventType != 'share_initiated') {
      throw const LinkGenerationException('Unsupported referral action.');
    }
    final match = RegExp(r'^ref_(\d+)$').firstMatch(referralId.trim());
    final id = int.tryParse(match?.group(1) ?? '');
    if (id == null || id <= 0) {
      throw const LinkGenerationException('Invalid referral link ID.');
    }
    final token = await _secureStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const LinkGenerationException(
        'Session expired. Please login again.',
      );
    }
    final tokenType = (await _secureStorage.getTokenType()) ?? 'Bearer';
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
    final response = await _client
        .post(
          Uri.parse(
            '${ApiConstants.baseUrl}/api/v1/referrals/links/$id/events',
          ),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization':
                '${tokenType.trim().isEmpty ? 'Bearer' : tokenType} $token',
          },
          body: jsonEncode({
            'event_id': eventId,
            'event_type': eventType,
            'platform': platform,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw LinkGenerationException(
        'Could not record referral action (HTTP ${response.statusCode}).',
      );
    }
  }

  Future<Map<String, dynamic>> validateReferralCode(String code) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/api/v1/referrals/validate/${Uri.encodeComponent(code)}',
    );
    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['data'] is! Map) {
        throw const LinkGenerationException(
          'Invalid referral validation response.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LinkGenerationException(
          _getErrorMessage(
            response.statusCode,
            Map<String, dynamic>.from(decoded),
          ),
        );
      }
      return Map<String, dynamic>.from(decoded['data'] as Map);
    } on TimeoutException {
      throw const LinkGenerationException('Referral validation timed out.');
    } on http.ClientException {
      throw const LinkGenerationException('Unable to validate referral link.');
    } on FormatException {
      throw const LinkGenerationException(
        'Invalid referral validation response.',
      );
    }
  }

  String _getErrorMessage(int statusCode, Map<String, dynamic> body) {
    final detail = body['detail'];
    final message = body['message'];

    // Prefer the server's explanation for all failures, including auth and
    // server errors, so the UI does not replace it with a generic message.
    if (statusCode == 401 ||
        (message is String && _isAuthenticationFailure(message)) ||
        (detail is String && _isAuthenticationFailure(detail))) {
      return 'Your session has expired. Please log in again.';
    }

    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }

    if (statusCode == 401) {
      return 'Session expired. Please login again.';
    }

    if (statusCode == 403) {
      return 'You are not authorized to generate referral links.';
    }

    if (statusCode == 422) {
      if (detail is String && detail.trim().isNotEmpty) return detail;
      if (detail is List) {
        final validationMessages = detail
            .whereType<Map>()
            .map((error) {
              final location = error['loc'];
              final field = location is List ? location.skip(1).join('.') : '';
              final message = error['msg']?.toString().trim() ?? '';
              if (field.isEmpty) return message;
              if (message.isEmpty) return field;
              return '$field: $message';
            })
            .where((message) => message.isNotEmpty)
            .toList();
        if (validationMessages.isNotEmpty) {
          return validationMessages.join(' ');
        }
      }
      return 'The backend rejected the referral details. Please check the selected service and try again.';
    }

    if (statusCode >= 500) {
      return 'Backend server error. Please try again later.';
    }

    return 'Referral link generation failed. Status: $statusCode';
  }

  bool _isAuthenticationFailure(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('authentication token required') ||
        normalized.contains('token required') ||
        normalized.contains('token expired') ||
        normalized.contains('invalid token') ||
        normalized.contains('authentication required');
  }

  void dispose() {
    _client.close();
  }
}
