import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:am5_freelancer_web/features/sub_categories/presentation/screens/sub_categories_screen.dart';
import 'package:am5_freelancer_web/features/sub_categories/presentation/widgets/remote_service_image.dart';

import 'remote_service_images_browser_status_stub.dart'
    if (dart.library.js_interop) 'remote_service_images_browser_status_web.dart'
    as browser_status;

void main() {
  testWidgets('renders every live category and Home Services image in Chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SubCategoriesScreen()));

    await _waitForImageWidgets(tester, 38);
    expect(find.byType(RemoteServiceImage), findsNWidgets(38));
    await _waitForLoadedBrowserImages(tester, 38);

    final homeServicesCard = find.text('Home services');
    expect(homeServicesCard, findsOneWidget);
    await tester.ensureVisible(homeServicesCard);
    await tester.tap(homeServicesCard);

    await _waitForImageWidgets(tester, 58);
    expect(find.byType(RemoteServiceImage), findsNWidgets(58));
    await _waitForLoadedBrowserImages(tester, 58);

    final loadedServiceImages = browser_status.loadedServiceImageCount();
    expect(
      loadedServiceImages,
      58,
      reason: 'Chrome must decode 38 category and 20 subcategory SVGs.',
    );
  }, skip: !kIsWeb);
}

Future<void> _waitForImageWidgets(
  WidgetTester tester,
  int expectedCount,
) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byType(RemoteServiceImage).evaluate().length == expectedCount) {
      return;
    }
  }
}

Future<void> _waitForLoadedBrowserImages(
  WidgetTester tester,
  int expectedCount,
) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (browser_status.loadedServiceImageCount() == expectedCount) {
      return;
    }
  }
}
