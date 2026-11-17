import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../presentation/widgets/dashboard_banner_section.dart';

class DashboardBannerException implements Exception {
  const DashboardBannerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DashboardBannerService {
  DashboardBannerService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  static const Duration _timeout = Duration(seconds: 20);

  Future<List<DashboardBanner>> fetchHomeBanners() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.banners}')
        .replace(
          queryParameters: const {
            'placement': 'home',
            'audience': 'freelancer',
          },
        );

    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw DashboardBannerException(_getHttpError(response.statusCode));
      }

      if (response.body.trim().isEmpty) {
        throw const DashboardBannerException(
          'The banner server returned an empty response.',
        );
      }

      final dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw const DashboardBannerException(
          'The banner server returned invalid JSON.',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw const DashboardBannerException(
          'Invalid banner API response format.',
        );
      }

      if (decoded['success'] != true) {
        throw DashboardBannerException(
          decoded['message']?.toString() ??
              'The banner request was unsuccessful.',
        );
      }

      final data = decoded['data'];

      if (data is! List) {
        throw const DashboardBannerException(
          'Invalid banner data received from the server.',
        );
      }

      final List<DashboardBanner> banners = [];

      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        try {
          final banner = DashboardBanner.fromJson(item);

          if (banner.isCurrentlyActive && banner.imageUrl.trim().isNotEmpty) {
            banners.add(banner);
          }
        } catch (error) {
          // Skip only the invalid banner.
          // Other valid banners can still be displayed.
          // Avoid logging the complete API response.
        }
      }

      banners.sort((a, b) => b.priority.compareTo(a.priority));

      return List.unmodifiable(banners);
    } on TimeoutException {
      throw const DashboardBannerException(
        'Banner request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const DashboardBannerException(
        'Unable to connect to the banner server.',
      );
    } on DashboardBannerException {
      rethrow;
    } catch (error) {
      throw const DashboardBannerException(
        'Something went wrong while loading banners.',
      );
    }
  }

  String _getHttpError(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid banner request.';
      case 401:
        return 'Authentication is required to load banners.';
      case 403:
        return 'You do not have permission to view these banners.';
      case 404:
        return 'Banner API endpoint was not found.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Banner server is temporarily unavailable.';
      default:
        return 'Unable to load banners. HTTP status: $statusCode.';
    }
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
