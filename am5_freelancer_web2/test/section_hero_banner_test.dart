import 'package:am5_freelancer_web/core/widgets/section_hero_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('section banner fits a mobile width and shows its content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SectionHeroBanner(
              title: 'Earnings & Wallet',
              subtitle: 'Track your earnings and wallet activity.',
              icon: Icons.account_balance_wallet_rounded,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Earnings & Wallet'), findsOneWidget);
    expect(find.text('AM5 ROYAL'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
