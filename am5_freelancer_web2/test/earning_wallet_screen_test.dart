import 'dart:convert';

import 'package:am5_freelancer_web/core/network/api_client.dart';
import 'package:am5_freelancer_web/core/network/freelance_api.dart';
import 'package:am5_freelancer_web/core/storage/secure_storage_service.dart';
import 'package:am5_freelancer_web/features/earning_wallet/presentation/screens/earning_wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'zero balance still opens bank form and can save without payout',
    (tester) async {
      final requests = <http.Request>[];
      final api = _walletApi(
        availableBalance: 0,
        bankDetails: const {},
        requests: requests,
      );
      addTearDown(api.dispose);

      await tester.pumpWidget(_app(api));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // Keep the test independent of any indeterminate progress indicator.
      expect(
        requests.where(
          (request) => request.url.path.endsWith('/wallet/summary'),
        ),
        hasLength(1),
      );

      final withdraw = find.widgetWithText(ElevatedButton, 'Withdraw Funds');
      await tester.ensureVisible(withdraw);
      expect(tester.widget<ElevatedButton>(withdraw).onPressed, isNotNull);
      await tester.tap(withdraw);
      await _pumpFrames(tester);

      expect(find.text('Add bank details'), findsOneWidget);
      expect(
        find.textContaining('Minimum withdrawal amount is ₹500.00.'),
        findsOneWidget,
      );
      expect(find.text('Withdrawal Amount (₹)'), findsNothing);
      expect(find.text('Save bank details'), findsOneWidget);

      await tester.ensureVisible(find.text('Save bank details'));
      await tester.tap(find.text('Save bank details'));
      await _pumpFrames(tester);
      expect(find.text('Account holder name is required'), findsOneWidget);
      expect(find.text('Account number is required'), findsOneWidget);

      await _enterField(tester, 'Account Holder Name', 'A P Kumar');
      await _enterField(tester, 'Bank Name', 'HDFC Bank');
      await _enterField(tester, 'Account Number', '12345678');
      await _enterField(tester, 'Confirm Account Number', '12345678');
      await _enterField(tester, 'IFSC Code', 'hdfc0001234');
      await tester.ensureVisible(find.text('Save bank details'));
      await tester.tap(find.text('Save bank details'));
      await _pumpFrames(tester);

      final save = requests.singleWhere((request) => request.method == 'PUT');
      expect(save.url.path, '/api/v1/freelancer/bank-details');
      expect(jsonDecode(save.body), {
        'account_holder_name': 'A P Kumar',
        'bank_name': 'HDFC Bank',
        'account_number': '12345678',
        'ifsc_code': 'HDFC0001234',
      });
      expect(find.text('Account: XXXX5678'), findsOneWidget);
      expect(find.text('Withdrawal Amount (₹)'), findsNothing);
      expect(
        requests.where(
          (request) => request.url.path.endsWith('/payout-request'),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'saved account can be edited and payout amount is eligibility checked',
    (tester) async {
      final requests = <http.Request>[];
      final api = _walletApi(
        availableBalance: 1200,
        bankDetails: {
          'account_holder': 'A P Kumar',
          'masked_account_number': 'XXXXXXXX5678',
          'ifsc': 'HDFC0001234',
          'bank_name': 'HDFC Bank',
          'verification_status': 'PENDING',
        },
        requests: requests,
      );
      addTearDown(api.dispose);

      await tester.pumpWidget(_app(api));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final withdraw = find.widgetWithText(ElevatedButton, 'Withdraw Funds');
      await tester.ensureVisible(withdraw);
      await tester.tap(withdraw);
      await _pumpFrames(tester);

      expect(find.text('Bank account on file'), findsOneWidget);
      expect(find.text('Account: XXXXXXXX5678'), findsOneWidget);
      expect(find.text('Withdrawal Amount (₹)'), findsOneWidget);
      expect(find.text('Branch name'), findsNothing);
      expect(find.text('UPI ID'), findsNothing);

      await tester.tap(find.text('Edit'));
      await _pumpFrames(tester);
      expect(find.text('Edit bank details'), findsOneWidget);
      expect(_textField('Account Number').controller!.text, isEmpty);

      await tester.ensureVisible(find.text('Cancel edit'));
      await tester.tap(find.text('Cancel edit'));
      await _pumpFrames(tester);
      await _enterField(tester, 'Withdrawal Amount (₹)', '499');
      await tester.tap(find.text('Request payout'));
      await _pumpFrames(tester);
      expect(find.text('Minimum withdrawal is ₹500.00'), findsOneWidget);

      await _enterField(tester, 'Withdrawal Amount (₹)', '1201');
      await tester.tap(find.text('Request payout'));
      await _pumpFrames(tester);
      expect(
        find.text('Amount exceeds your available balance'),
        findsOneWidget,
      );

      await _enterField(tester, 'Withdrawal Amount (₹)', '600');
      await tester.tap(find.text('Request payout'));
      await _pumpFrames(tester);
      expect(find.text('Confirm withdrawal request'), findsOneWidget);
      expect(find.textContaining('moves funds to processing'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await _pumpFrames(tester);
      expect(
        requests.where(
          (request) => request.url.path.endsWith('/payout-request'),
        ),
        isEmpty,
      );
    },
  );

  testWidgets('below-minimum balance still allows saved bank details view', (
    tester,
  ) async {
    final api = _walletApi(
      availableBalance: 499,
      bankDetails: {
        'account_holder': 'A P Kumar',
        'masked_account_number': 'XXXXXXXX5678',
        'ifsc': 'HDFC0001234',
        'bank_name': 'HDFC Bank',
        'verification_status': 'PENDING',
      },
      requests: [],
    );
    addTearDown(api.dispose);

    await tester.pumpWidget(_app(api));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final withdraw = find.widgetWithText(ElevatedButton, 'Withdraw Funds');
    await tester.ensureVisible(withdraw);
    await tester.tap(withdraw);
    await _pumpFrames(tester);

    expect(find.text('Bank account on file'), findsOneWidget);
    expect(
      find.textContaining('Minimum withdrawal amount is ₹500.00.'),
      findsOneWidget,
    );
    expect(find.text('Withdrawal Amount (₹)'), findsNothing);
    expect(find.text('Request payout'), findsNothing);
  });
}

Finder _field(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(TextFormField))
    .first;

Future<void> _enterField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = _field(label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

TextFormField _textField(String label) =>
    _field(label).evaluate().single.widget as TextFormField;

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _app(FreelanceApi api) => MaterialApp(
  home: Scaffold(body: EarningWalletScreen(api: api)),
);

FreelanceApi _walletApi({
  required double availableBalance,
  required Map<String, dynamic> bankDetails,
  required List<http.Request> requests,
}) {
  final savedBankDetails = Map<String, dynamic>.from(bankDetails);
  final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/wallet/summary')) {
      return _response({
        'total_earnings': availableBalance,
        'available_balance': availableBalance,
        'pending_balance': 0,
        'processing_balance': 0,
        'total_withdrawn': 0,
        'currency': 'INR',
      });
    }
    if (path.endsWith('/wallet/transactions')) {
      return _response({
        'items': [],
        'page': 1,
        'limit': 10,
        'total': 0,
        'hasMore': false,
      });
    }
    if (path.endsWith('/installation-rewards/statistics')) {
      return _response({
        'customer_installs': 0,
        'vendor_installs': 0,
        'customer_eligible': 0,
        'vendor_eligible': 0,
      });
    }
    if (path.endsWith('/installation-rewards/status')) {
      return _response([]);
    }
    if (path.endsWith('/freelancer/bank-details') && request.method == 'GET') {
      return _response(savedBankDetails);
    }
    if (path.endsWith('/freelancer/bank-details') && request.method == 'PUT') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      savedBankDetails
        ..['account_holder'] = body['account_holder_name']
        ..['masked_account_number'] =
            'X' * (body['account_number'].toString().length - 4) +
            body['account_number'].toString().substring(
              body['account_number'].toString().length - 4,
            )
        ..['ifsc'] = body['ifsc_code']
        ..['bank_name'] = body['bank_name']
        ..['verification_status'] = 'PENDING';
      return _response(savedBankDetails);
    }
    return _response({'detail': 'Unexpected test request'}, status: 404);
  });
  return FreelanceApi(
    client: ApiClient(client: client, storage: _TestStorage()),
    storage: _TestStorage(),
  );
}

http.Response _response(Object data, {int status = 200}) => http.Response(
  jsonEncode({'success': status < 400, 'data': data}),
  status,
  headers: const {'content-type': 'application/json'},
);

class _TestStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<String?> getTokenType() async => 'Bearer';
}
