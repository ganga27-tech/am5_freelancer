import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import 'session_events.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Shared JSON client for freelancer APIs. Adds the persisted bearer token,
/// applies timeouts, parses the standard {success,message,data} envelope and
/// clears a rejected session on 401.
class ApiClient {
  ApiClient({http.Client? client, SecureStorageService? storage})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _storage = storage ?? SecureStorageService();

  final http.Client _client;
  final bool _ownsClient;
  final SecureStorageService _storage;
  static const Duration timeout = Duration(seconds: 20);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);
  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);
  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Uri _uri(String path, [Map<String, String>? query]) {
    final root = Uri.parse(ApiConstants.baseUrl);
    final relative = path.startsWith('/') ? path.substring(1) : path;
    return root.resolve(relative).replace(queryParameters: query);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    try {
      final token = await _storage.getAccessToken();
      final tokenType = (await _storage.getTokenType()) ?? 'Bearer';
      final headers = <String, String>{
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty)
          'Authorization':
              '${tokenType.trim().isEmpty ? 'Bearer' : tokenType} $token',
      };
      final request = http.Request(method, _uri(path, query))
        ..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(timeout);
      dynamic decoded;
      if (response.bodyBytes.isNotEmpty) {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      }
      if (response.statusCode == 401) {
        await _storage.deleteAccessToken();
        SessionEvents.notifyExpired();
        throw const ApiException(
          'Your session has expired. Please log in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _message(decoded, response.statusCode),
          statusCode: response.statusCode,
        );
      }
      if (decoded is Map && decoded['success'] == false) {
        throw ApiException(
          decoded['message']?.toString() ??
              'The request could not be completed.',
          statusCode: response.statusCode,
        );
      }
      if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Could not connect to the server. Check your internet connection.',
      );
    } on FormatException {
      throw const ApiException('The server returned an invalid response.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  String _message(dynamic body, int status) {
    if (body is Map) {
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty && detail.first is Map) {
        return detail.first['msg']?.toString() ??
            'Please check the submitted details.';
      }
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    if (status >= 500) {
      return 'The server is temporarily unavailable. Please try again later.';
    }
    if (status == 404) {
      return 'This feature is not available on the connected server yet.';
    }
    return 'The request failed (HTTP $status). Please try again.';
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
