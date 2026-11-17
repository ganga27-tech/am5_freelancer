# Services Image Status

## 2026-11-09 image-rendering fix

**Overall: PARTIAL.** The API fields were parsed correctly; the Flutter Web renderer was the failure point. Both `Image.network` renderers use a browser XHR path. The public R2 image responses return `200 image/svg+xml` but do not include `Access-Control-Allow-Origin`, so Chrome blocked the XHR. Main category `errorBuilder`s hid the failure behind generic category icons; subcategory cards showed their broken-image fallback. The SVG format also requires an SVG decoder on native Flutter platforms.

The shared `RemoteServiceImage` now uses a browser-native `<img>` element on Flutter Web, and uses `flutter_svg` for SVGs / `Image.network` for raster images on native platforms. It retains API-provided URLs and has loading, retry, and error UI. The API model fields remain `category_image_url` and `image_url`; no image URL is hardcoded in Flutter.

| Check | Result |
|---|---|
| Local API active main categories | PASS — 38 records; image field present on all 38. |
| Local API Home Services subcategories | PASS — 20 records; 20 distinct image URLs. |
| Chrome image decode audit | PASS — a temporary audit page populated directly from both local API responses displayed `Decoded 58/58 images · Failed 0 · Loading 0`; screenshot confirmed category and service-specific artwork. This verifies the image URLs and native browser `<img>` path, not the authenticated Flutter screen. |
| Flutter Services screen after the renderer change | PARTIAL — the local Chrome session reached the login/dashboard guard and the current notification request returned 401. The Chrome Flutter test runner did not report progress for either the app-launch test or the browser image test and was stopped; therefore I cannot claim a post-change 58-card Flutter-screen run. |
| Correct one-to-one main category assignment | PARTIAL — IDs 1 (`Training & Education`) and 38 (`Driving School`) have the same backend image URL. Both load, but the API does not currently return a Driving School-specific image. |

Files changed in the Flutter app: `lib/features/sub_categories/presentation/widgets/remote_service_image.dart`, `remote_service_image_web.dart`, `remote_service_image_web_stub.dart`, `sub_category_card.dart`, and `lib/features/sub_categories/presentation/screens/sub_categories_screen.dart`. Added a Chrome-only regression test and its browser status helper under `test/`; the regular VM test command skips that browser test.

## Source and verification

Images are already served from PostgreSQL-backed API fields and public R2 URLs; no image URL is hardcoded in the category widgets. The Flutter main category grid reads `category_image_url`; subcategory cards read `image_url`, show a loading indicator, and fall back on load errors. Local API GETs were read-only.

- `GET /api/v1/service-categories?status=active`: 38 active categories, 38 image URLs present.
- `GET /api/v1/service-categories/37/subcategories?status=active`: 20 Home Services subcategories, 20 unique image URLs.
- HEAD check: 57 unique main + Home Services image URLs; 57 responded successfully, 0 failed.
- Existing storage is the public R2 CDN. No upload or database mutation was performed.

## Main categories (ID | API name)

| ID | Category | API image |
|---:|---|---|
| 1 | Training & Education | Present |
| 2 | Event & Wedding | Present |
| 3 | Healthcare & Medical | Present |
| 4 | Accommodation | Present |
| 5 | Real Estate | Present |
| 6 | Legal | Present |
| 7 | Lifestyle & Wellness | Present |
| 8 | Freelancers & Jobs | Present |
| 9 | Job | Present |
| 10 | Jobs & Recruitment | Present |
| 11 | Healthcare & Hospitals | Present |
| 12 | Medical Equipment & Emergency Support | Present |
| 13 | Used Vehicles | Present |
| 14 | Food & Beverage | Present |
| 15 | Travel & Tourism | Present |
| 16 | Shopping & Retail | Present |
| 17 | Electronics & Appliances | Present |
| 18 | Furniture & Home | Present |
| 19 | Finance | Present |
| 20 | Building Construction Material & Equipment | Present |
| 21 | Electronics & Electrical Goods & Supplies | Present |
| 22 | Medical Equipment & Devices | Present |
| 23 | Industrial Plants, Machinery & Equipment | Present |
| 24 | Food, Agriculture & Farming | Present |
| 25 | Food Products | Present |
| 26 | Wholesale & Distribution | Present |
| 27 | Footwear & Bags | Present |
| 28 | Packers & Movers | Present |
| 29 | Chemicals, Dyes, Solvents & Allied Products | Present |
| 30 | Common Available Items in Wholesale Market | Present |
| 31 | Business & Professional Services | Present |
| 32 | Security & Safety Services | Present |
| 33 | Religious & Spiritual Services | Present |
| 34 | Rental & Hire Services | Present |
| 35 | Green & Eco Services | Present |
| 36 | Hyperlocal On-Demand Services | Present |
| 37 | Home services | Present |
| 38 | Driving School | Present |

Category 38 currently shares the Training & Education image reference. No replacement asset was fabricated or uploaded. Update the backend catalog record only after a reviewed Driving School asset is placed in the existing public image storage and its real URL is confirmed.

## Home Services subcategories (ID | API name)

| ID | Subcategory | Unique API image |
|---:|---|---|
| 1 | 2 and 4 Wheeler Services | Yes |
| 3 | Pet Care Services | Yes |
| 5 | Beauty and Wellness | Yes |
| 6 | AC Repair Services | Yes |
| 7 | Plumbing Services | Yes |
| 8 | Smart and Normal Appliance Repair Services | Yes |
| 9 | Smart and Normal Electrical Services | Yes |
| 10 | Modular Works and Interior Design | Yes |
| 11 | Cleaning Services | Yes |
| 12 | Driver Services | Yes |
| 13 | Immediate Services | Yes |
| 14 | Pest Control Services | Yes |
| 15 | Caretaker services | Yes |
| 16 | Cooking services | Yes |
| 17 | Home and online classes | Yes |
| 18 | Lab test | Yes |
| 19 | Nursing service | Yes |
| 20 | Painting | Yes |
| 21 | Physiotherapy | Yes |
| 22 | Water proofing | Yes |

Other categories have subcategories without images in the local database (for example, IDs 28 and 18). The requested set of 20 Home Services subcategories is complete; additional category image gaps need real reviewed assets before upload.
