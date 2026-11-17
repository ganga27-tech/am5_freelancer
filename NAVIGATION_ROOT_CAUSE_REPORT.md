# Freelancer → Vendor Navigation Root Cause Report

**Updated:** 2026-11-09  
**Status:** PARTIAL — code defect fixed; fresh 20-service Chrome destination verification remains BLOCKED.

## Click path traced

1. `DashboardMenuItem.items` exposes **Services**. `DashboardScreen._openMenu()` maps it to `AppRoutes.services`.
2. `AppRoutes.services` builds `DashboardScreen(initialMenu: 'Services')`; `_buildSelectedScreen()` displays `SubCategoriesScreen`.
3. `SubCategoriesScreen._loadMainCategories()` loads the active catalog. It now selects Home Services by verified catalog ID `37` plus slug `home-services`. Previously it compared the display name and silently fell back to the first category when no match existed.
4. Subcategories load for the selected category ID. `SubCategoryCard` uses the same callback for the service image and title; it now also handles taps on the rest of the card surface.
5. `_openVendorService()` gets its URI only from `VendorNavigationService.homeService()`. That immutable 20-entry ID/slug map produces the exact HTTPS Vendor route. `_openVendorDestination()` rejects non-HTTPS, wrong-host, user-info, generic-map, and unexpected paths before calling `launchUrl(..., mode: LaunchMode.externalApplication)`.

## Root causes found

- **Clicks on blank card areas did nothing.** Before the fix, only the image and title InkWells had `onTap`; the rest of the card container had no handler. The entire card now has an outer InkWell while the Generate Link button keeps its separate callback.
- **The observed main-domain URL came from the referral workflow.** The service card's **Generate Link** action opened a referral dialog. Its generic **Continue** button launched the generated referral URL, which in the observed local screen was `https://am5royal.com/services/6?ref=…`. This is a referral landing URL, not the Vendor service URL. The button now says **Open Referral Page**. Service image/title/card taps remain a separate Vendor navigation path.
- **Home Services selection depended on display text and had an unsafe fallback.** If the target category was absent or renamed, the first unrelated category could be selected. Selection now requires the known ID/slug pair and shows an unavailable/retry state instead of choosing another category.

No Freelancer service navigation handler constructs a destination from API-provided URLs, and the 20 route strings were not changed. The Vendor route server/login behavior cannot be diagnosed without Vendor source. No Flutter request to the Vendor domain was observed in this current run; do not attribute a server redirect without its redirect chain.

## Fixes and regression coverage

- Full card area, service image, and title dispatch one callback; Generate Link remains independent.
- Navigation logs contain only catalog service ID/name and expected/launcher URL; provider credentials and personal contact details are not logged.
- Per-service in-flight guard prevents simultaneous duplicate launch calls for the same catalog ID.
- The stable Home Services category ID and slug are tested; existing 20-entry route table and ID/slug checks are unchanged.
- Widget regression test covers blank card surface, artwork, title, and separation from Generate Link.

Files changed: `am5_freelancer_web2/lib/features/sub_categories/presentation/widgets/sub_category_card.dart`, `.../screens/sub_categories_screen.dart`, `.../services/vendor_navigation_service.dart`, `.../test/sub_category_card_test.dart`, and `.../test/vendor_navigation_service_test.dart`.

## Browser evidence and remaining limit

The local Chrome page visibly rendered the Freelancer Services screen with **20 services available**. It also displayed the AC Repair referral dialog and its main-domain referral URL. After dismissing that dialog, a Pet Care image click was attempted, but no Vendor destination was captured. Browser control was then interrupted by user input. Therefore the current actual Chrome click result for each service is **BLOCKED / not verified**, even though the mapping test passes. See `NAVIGATION_TEST_RESULTS.md`.