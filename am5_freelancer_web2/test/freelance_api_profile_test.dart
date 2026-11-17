import 'dart:convert';

import 'package:am5_freelancer_web/core/network/api_client.dart';
import 'package:am5_freelancer_web/core/network/freelance_api.dart';
import 'package:am5_freelancer_web/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemoryStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<String?> getTokenType() async => 'Bearer';
}

void main() {
  test('profile update maps the API envelope and reads back persisted values',
      () async {
    final persistedProfile = <String, dynamic>{
      'user_id': 42,
      'full_name': 'Ravi Updated',
      'mobile': '9876543210',
      'email': 'ravi@example.com',
      'address': '12 Test Road',
      'city': 'Vijayawada',
      'state': 'Andhra Pradesh',
      'pincode': '520001',
      'completion_percentage': 50,
    };
    Map<String, dynamic>? sentFields;
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        sentFields = jsonDecode(request.body) as Map<String, dynamic>;
        persistedProfile.addAll(sentFields!);
      }

      return http.Response(
        jsonEncode({
          'success': true,
          'message': 'Profile retrieved',
          'data': persistedProfile,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = FreelanceApi(
      client: ApiClient(client: client, storage: _MemoryStorage()),
      storage: _MemoryStorage(),
    );
    addTearDown(client.close);

    final updated = await api.updateProfile({
      'full_name': 'Ravi Updated',
      'address': '12 Test Road',
      'city': 'Vijayawada',
      'state': 'Andhra Pradesh',
      'pincode': '520001',
    });
    final afterRefresh = await api.profile();

    expect(sentFields, {
      'full_name': 'Ravi Updated',
      'address': '12 Test Road',
      'city': 'Vijayawada',
      'state': 'Andhra Pradesh',
      'pincode': '520001',
    });
    expect(sentFields!.containsKey('mobile'), isFalse);
    expect(sentFields!.containsKey('email'), isFalse);
    expect(updated['full_name'], 'Ravi Updated');
    expect(updated['city'], 'Vijayawada');
    expect(afterRefresh['address'], '12 Test Road');
    expect(afterRefresh['pincode'], '520001');
  });
}
