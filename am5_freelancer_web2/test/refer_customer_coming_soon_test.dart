import 'dart:convert';

import 'package:am5_freelancer_web/core/network/api_client.dart';
import 'package:am5_freelancer_web/core/network/freelance_api.dart';
import 'package:am5_freelancer_web/core/storage/secure_storage_service.dart';
import 'package:am5_freelancer_web/features/refer_earn/presentation/screens/refer_earn_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'customer referrals show Coming Soon and issue no create request',
    (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final isList =
            request.url.path.endsWith('/links') ||
            request.url.path.endsWith('/points/history');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': isList ? {'items': []} : {},
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final api = FreelanceApi(
        client: ApiClient(client: client, storage: _TestStorage()),
        storage: _TestStorage(),
      );
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReferEarnScreen(api: api)),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.text(
          'Customer App is coming soon. Customer referrals will be available after launch.',
        ),
        findsOneWidget,
      );
      final button = find.widgetWithText(ElevatedButton, 'Coming Soon');
      expect(button, findsOneWidget);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await tester.tap(button);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(requests.where((request) => request.method == 'POST'), isEmpty);
      expect(find.text('No Vendor referrals yet.'), findsOneWidget);
    },
  );
}

class _TestStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<String?> getTokenType() async => 'Bearer';
}
