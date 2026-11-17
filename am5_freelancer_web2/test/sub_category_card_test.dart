import 'package:am5_freelancer_web/features/sub_categories/models/sub_category_model.dart';
import 'package:am5_freelancer_web/features/sub_categories/presentation/widgets/sub_category_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = SubCategoryModel(
    id: 6,
    name: 'AC Repair Services',
    slug: 'ac-repair-services',
    imageUrl: '',
    bannerUrl: '',
    activeStatus: true,
    referralEligibility: true,
  );

  testWidgets('card surface, artwork, and title open the service once', (
    tester,
  ) async {
    var openCount = 0;
    var referralCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 222,
              child: SubCategoryCard(
                category: service,
                onOpenVendor: () => openCount++,
                onGenerateLink: () => referralCount++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardRect = tester.getRect(find.byType(SubCategoryCard));
    await tester.tapAt(Offset(cardRect.left + 4, cardRect.center.dy));
    expect(openCount, 1);

    await tester.tap(find.byIcon(Icons.image_not_supported_outlined));
    expect(openCount, 2);

    await tester.tap(find.text('AC Repair Services'));
    expect(openCount, 3);

    await tester.tap(find.text('Generate Link'));
    expect(referralCount, 1);
    expect(openCount, 3);
  });
}
