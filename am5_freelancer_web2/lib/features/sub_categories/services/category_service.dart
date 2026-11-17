import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../models/main_category_model.dart';
import '../models/sub_category_model.dart';

class CategoryServiceException implements Exception {
  final String message;

  const CategoryServiceException(this.message);

  @override
  String toString() => message;
}

class CategoryService {
  final http.Client _client;
  final bool _ownsClient;

  CategoryService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const Duration _timeout = Duration(seconds: 20);

  Future<List<MainCategoryModel>> fetchMainCategories() async {
    final data = await _getList(
      ApiConstants.serviceCategories,
      queryParameters: const {'status': 'active'},
    );

    final categories = <MainCategoryModel>[];
    final seenIds = <int>{};

    for (final item in data) {
      try {
        final category = MainCategoryModel.fromJson(item);

        if (category.activeStatus && seenIds.add(category.id)) {
          categories.add(category);
        }
      } on FormatException {
        continue;
      }
    }

    categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return categories;
  }

  Future<List<SubCategoryModel>> fetchSubCategories(int categoryId) async {
    if (categoryId <= 0) {
      throw const CategoryServiceException('Invalid category ID');
    }

    final data = await _getList(
      ApiConstants.subCategories(categoryId),
      queryParameters: const {'status': 'active'},
    );

    final subCategories = <SubCategoryModel>[];
    final seenIds = <int>{};

    for (final item in data) {
      try {
        final subCategory = SubCategoryModel.fromJson(item);

        if (subCategory.activeStatus && seenIds.add(subCategory.id)) {
          subCategories.add(subCategory);
        }
      } on FormatException {
        continue;
      }
    }

    return subCategories;
  }

  Future<List<Map<String, dynamic>>> _getList(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint')
          .replace(queryParameters: queryParameters);

      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CategoryServiceException(
          'Server request failed (${response.statusCode})',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        throw const CategoryServiceException('Invalid server response format');
      }

      if (decoded['success'] != true) {
        throw CategoryServiceException(
          decoded['message']?.toString() ?? 'API request failed',
        );
      }

      final rawData = decoded['data'];

      if (rawData is! List) {
        throw const CategoryServiceException('Invalid API data format');
      }

      return rawData.whereType<Map<String, dynamic>>().toList();
    } on TimeoutException {
      throw const CategoryServiceException(
        'Request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const CategoryServiceException(
        'Unable to connect to server. Check your internet connection.',
      );
    } on FormatException {
      throw const CategoryServiceException(
        'Invalid JSON response from server.',
      );
    } on CategoryServiceException {
      rethrow;
    } catch (_) {
      throw const CategoryServiceException(
        'Something went wrong. Please try again.',
      );
    }
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
