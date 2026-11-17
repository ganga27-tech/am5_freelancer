import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';

class LoginException implements Exception {
  final String message;

  const LoginException(this.message);

  @override
  String toString() => message;
}

class LoginResponse {
  final String accessToken;
  final String tokenType;
  final Map<String, dynamic> user;

  const LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final dynamic dataValue = json['data'];

    if (dataValue is! Map) {
      throw const LoginException('Invalid login response from server.');
    }

    final data = Map<String, dynamic>.from(dataValue);
    final token = data['access_token'];
    final userValue = data['user'];

    if (token is! String || token.trim().isEmpty) {
      throw const LoginException('Server did not return an access token.');
    }

    if (userValue is! Map) {
      throw const LoginException('Invalid user details received.');
    }

    return LoginResponse(
      accessToken: token,
      tokenType: (data['token_type'] as String?) ?? 'bearer',
      user: Map<String, dynamic>.from(userValue),
    );
  }
}

class LoginService {
  LoginService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<LoginResponse> login({
    required String identifier,
    required String password,
  }) async {
    final cleanIdentifier = identifier.trim();

    if (cleanIdentifier.isEmpty) {
      throw const LoginException('Enter your mobile number or email.');
    }

    if (password.isEmpty) {
      throw const LoginException('Enter your password.');
    }

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}');

      final response = await _client
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'identifier': cleanIdentifier,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> responseData = {};

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          responseData = Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        throw const LoginException(
          'Invalid response received from the server.',
        );
      }

      if (response.statusCode == 200 && responseData['success'] == true) {
        return LoginResponse.fromJson(responseData);
      }

      throw LoginException(_getErrorMessage(response.statusCode, responseData));
    } on TimeoutException {
      throw const LoginException(
        'Server is taking too long to respond. Try again.',
      );
    } on http.ClientException {
      throw const LoginException(
        'Unable to connect to the server. Check your connection.',
      );
    } on LoginException {
      rethrow;
    } catch (_) {
      throw const LoginException('Something went wrong. Please try again.');
    }
  }

  String _getErrorMessage(int statusCode, Map<String, dynamic> body) {
    final dynamic detail = body['detail'];
    final dynamic message = body['message'];

    if (statusCode == 401) {
      return 'Invalid mobile/email or password.';
    }

    if (statusCode == 403) {
      return 'Your account is not allowed to log in. Contact support.';
    }

    if (statusCode == 422) {
      if (detail is List && detail.isNotEmpty) {
        final firstError = detail.first;
        if (firstError is Map && firstError['msg'] is String) {
          return firstError['msg'] as String;
        }
      }

      if (detail is String && detail.isNotEmpty) {
        return detail;
      }

      return 'Please check the entered details.';
    }

    if (statusCode >= 500) {
      return 'Server error. Please try again later.';
    }

    if (message is String && message.isNotEmpty) {
      return message;
    }

    if (detail is String && detail.isNotEmpty) {
      return detail;
    }

    return 'Login failed. Please try again.';
  }

  void dispose() {
    _client.close();
  }
}
