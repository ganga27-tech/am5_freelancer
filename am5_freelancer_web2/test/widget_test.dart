import 'package:flutter_test/flutter_test.dart';

import 'package:am5_freelancer_web/app/app.dart';

void main() {
  testWidgets('AM5 ROYAL Freelancer app launches successfully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AM5FreelancerApp());

    expect(find.byType(AM5FreelancerApp), findsOneWidget);
  });
}
