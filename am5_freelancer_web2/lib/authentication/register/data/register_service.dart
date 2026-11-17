import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';

/// Custom exception for registration-related errors.
class RegisterException implements Exception {
  final String message;

  const RegisterException(this.message);

  @override
  String toString() => message;
}

class RegisterService {
  final http.Client _client;

  RegisterService({http.Client? client}) : _client = client ?? http.Client();

  static const Duration _requestTimeout = Duration(seconds: 20);

  // ------------------------------------------------------------
  // 1. FULL NAME VALIDATION
  // ------------------------------------------------------------

  static String? validateFullName(String value) {
    final name = value.trim();

    if (name.isEmpty) {
      return 'Full name is required.';
    }

    if (name.length < 3) {
      return 'Name must contain at least 3 characters.';
    }

    if (name.length > 60) {
      return 'Name cannot exceed 60 characters.';
    }

    if (!RegExp(r"^[A-Za-z][A-Za-z .'-]*$").hasMatch(name)) {
      return 'Enter a valid name using English letters.';
    }

    return null;
  }

  // ------------------------------------------------------------
  // 2. MOBILE NUMBER VALIDATION
  // ------------------------------------------------------------

  static String? validateMobileNumber(String value) {
    final mobile = value.trim();

    if (mobile.isEmpty) {
      return 'Mobile number is required.';
    }

    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobile)) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }

    return null;
  }

  // ------------------------------------------------------------
  // 3. EMAIL VALIDATION
  // ------------------------------------------------------------

  static String? validateEmail(String value) {
    final email = value.trim();

    if (email.isEmpty) {
      return 'Email address is required.';
    }

    if (email.length > 254) {
      return 'Email address is too long.';
    }

    final emailPattern = RegExp(
      r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+"
      r"(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*"
      r"@"
      r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?"
      r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$",
    );

    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  // ------------------------------------------------------------
  // 4. PASSWORD VALIDATION
  // ------------------------------------------------------------

  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required.';
    }

    if (password.length < 8) {
      return 'Password must contain at least 8 characters.';
    }

    if (password.length > 64) {
      return 'Password cannot exceed 64 characters.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain an uppercase letter.';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain a lowercase letter.';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain a number.';
    }

    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Password must contain a special character.';
    }

    return null;
  }

  // ------------------------------------------------------------
  // 5. CONFIRM PASSWORD VALIDATION
  // ------------------------------------------------------------

  static String? validateConfirmPassword({
    required String password,
    required String confirmPassword,
  }) {
    if (confirmPassword.isEmpty) {
      return 'Please confirm your password.';
    }

    if (password != confirmPassword) {
      return 'Passwords do not match.';
    }

    return null;
  }

  // ------------------------------------------------------------
  // 6. REGISTER API
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String mobileNumber,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    // Client-side validation before sending the request.

    final validations = <String?>[
      validateFullName(fullName),
      validateMobileNumber(mobileNumber),
      validateEmail(email),
      validatePassword(password),
      validateConfirmPassword(
        password: password,
        confirmPassword: confirmPassword,
      ),
    ];

    for (final error in validations) {
      if (error != null) {
        throw RegisterException(error);
      }
    }

    final Uri url = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.register}',
    );

    // Request fields match the backend Swagger schema.

    final Map<String, dynamic> requestBody = {
      'full_name': fullName.trim(),
      'mobile_number': mobileNumber.trim(),
      'email': email.trim(),
      'password': password,
      'confirm_password': confirmPassword,
    };

    try {
      final http.Response response = await _client
          .post(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_requestTimeout);

      // Decode the backend response.

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const RegisterException(
          'Invalid response received from the server.',
        );
      }

      // Registration success: HTTP 201 + success true.

      if (response.statusCode == 201 && decoded['success'] == true) {
        return decoded;
      }

      // Handle backend validation and API errors.

      throw RegisterException(
        _extractErrorMessage(decoded) ??
            'Registration failed. Please try again.',
      );
    } on RegisterException {
      rethrow;
    } on TimeoutException {
      throw const RegisterException(
        'Request timed out. Please check your connection and try again.',
      );
    } on http.ClientException {
      throw const RegisterException(
        'Unable to connect to the server. Please check your network.',
      );
    } on FormatException {
      throw const RegisterException('The server returned an invalid response.');
    } catch (_) {
      throw const RegisterException('Something went wrong. Please try again.');
    }
  }

  // ------------------------------------------------------------
  // 7. BACKEND ERROR MESSAGE EXTRACTION
  // ------------------------------------------------------------

  String? _extractErrorMessage(Map<String, dynamic> response) {
    final message = response['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    final detail = response['detail'];

    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }

    // FastAPI validation errors can return a list of objects.

    if (detail is List && detail.isNotEmpty) {
      final messages = <String>[];

      for (final item in detail) {
        if (item is Map<String, dynamic>) {
          final errorMessage = item['msg'];

          if (errorMessage is String && errorMessage.trim().isNotEmpty) {
            messages.add(errorMessage);
          }
        }
      }

      if (messages.isNotEmpty) {
        return messages.join('\n');
      }
    }

    return null;
  }

  // ------------------------------------------------------------
  // 8. RELEASE HTTP CLIENT
  // ------------------------------------------------------------

  void dispose() {
    _client.close();
  }
}
