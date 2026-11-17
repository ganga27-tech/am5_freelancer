import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/wallet_dashboard_model.dart';

class WalletDashboardService {
  final String baseUrl;
  final Future<String?> Function() getAccessToken;
  final http.Client _client;

  WalletDashboardService({
    required this.baseUrl,
    required this.getAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<WalletDashboardModel> fetchDashboard() async {
    final token = await getAccessToken();

    if (token == null || token.trim().isEmpty) {
      throw const WalletApiException(
        'Authentication token is missing. Please log in again.',
      );
    }

    final normalizedBaseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

    final uri = Uri.parse('$normalizedBaseUrl/api/freelancer/wallet/dashboard');

    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const WalletApiException(
          'Your session may have expired. Please log in again.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WalletApiException(
          'Unable to load wallet information '
          '(HTTP ${response.statusCode}).',
        );
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const WalletApiException(
          'Invalid wallet dashboard response from server.',
        );
      }

      return WalletDashboardModel.fromJson(decoded);
    } on WalletApiException {
      rethrow;
    } on FormatException {
      throw const WalletApiException('The server returned invalid JSON.');
    } on http.ClientException {
      throw const WalletApiException(
        'Unable to connect to the server. Please try again.',
      );
    } on Exception catch (error) {
      if (error.toString().contains('TimeoutException')) {
        throw const WalletApiException(
          'The request timed out. Please try again.',
        );
      }

      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}

class WalletApiException implements Exception {
  final String message;

  const WalletApiException(this.message);

  @override
  String toString() => message;
}
