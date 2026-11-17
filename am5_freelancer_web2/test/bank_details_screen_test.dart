import 'package:am5_freelancer_web/features/profile/presentation/screens/bank_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not show a bank branch field the API cannot save', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: BankDetailsScreen()),
    );

    expect(find.text('Branch name'), findsNothing);
    expect(find.text('Bank name'), findsOneWidget);
  });
}
