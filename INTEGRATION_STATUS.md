# AM5 ROYAL Integration Status

## Summary

This is the strongest safe local integration currently possible from the supplied Freelancer Flutter client and FastAPI ZIP. Development defaults to `http://127.0.0.1:8000`; production is isolated behind `API_BASE_URL=https://api.am5royal.com`. The release build is explicitly configured for production.

| Area | Result | Evidence / limit |
|---|---|---|
| Public Freelancer content APIs | PASS | Local Swagger/OpenAPI and 9 public GET routes returned HTTP 200. |
| Protected API authorization | PARTIAL | All 22 protected Freelancer GET routes returned HTTP 401 without a test JWT. This verifies auth enforcement only; user data was not seen. |
| Main category images | PARTIAL | Local API returned 38/38 active image references and Chrome decoded them, but IDs 1 and 38 share one image and the authenticated Flutter screen could not be verified after the renderer fix. See SERVICES_IMAGE_STATUS.md. |
| Home Services subcategory images | PARTIAL | Category 37 returned 20 unique image URLs and Chrome decoded all 20, but the post-change authenticated Flutter screen could not be verified. See SERVICES_IMAGE_STATUS.md. |
| Flutter JWT and session client | PARTIAL | Shared bearer client, secure token storage, session restore and 401 clearing are wired. Login/session journey could not be exercised without a disposable account. |
| Referral creation and validity | PARTIAL | Backend validates 7/15 day inputs, service destinations and active subcategories; token entropy increased to 256 bits. No authenticated creation/DB expiry journey was run. Registration attribution and universal link resolution remain absent. |
| Vendor direct navigation / deep links | BLOCKED | Vendor/customer app source and verified per-category routes, app IDs, signing data and association files were not supplied. |
| KYC / bank / wallet / rewards / notifications / settings | PARTIAL | Frontend route/payload integration exists. Protected GETs returned 401; no sensitive writes were attempted. |
| Face verification | BLOCKED | Backend session/status API exists but provider SDK/image submission integration is missing. |
| Demo videos | PARTIAL | `/api/v1/demo-videos?audience=freelancer` returned HTTP 200 with an empty list; Flutter now loads it and shows a real empty state. |
| Production compatibility | BLOCKED | Production OpenAPI returned 200 with 259 paths but no Freelancer auth/profile/referral/installation routes. |
| Database safety | PASS | Only read-only API queries were run. No reset, delete, migration, payout or persistent test registration was performed. |
| Flutter analysis | PASS | `flutter analyze --no-pub`: no issues found after applying 59 safe lint fixes in 20 files and resolving remaining analyzer findings. |
| Flutter tests | PASS | `flutter test --no-pub`: 1 widget smoke test passed. |
| Web release build | PASS | `flutter build web --release --no-pub --dart-define=API_BASE_URL=https://api.am5royal.com` succeeded. |
| Backend tests | PARTIAL | 5 isolated service tests passed without importing the destructive DB fixture; referral schema cases and Python compile checks passed. |

See the other status documents for module details. Exposed credentials from the supplied ZIP/source must be rotated before release; Razorpay key literals were removed from local wallet/subscription sources and now come from environment variables; the deployment script password was moved to an environment variable.




## Source files changed

### Flutter (`am5_freelancer_web2/`)

- `lib/core/constants/api_constants.dart`
- `lib/core/network/api_client.dart`
- `lib/core/network/session_events.dart`
- `lib/core/network/freelance_api.dart`
- `lib/core/storage/secure_storage_service.dart`
- `lib/authentication/login/data/login_service.dart`
- `lib/authentication/register/data/register_service.dart`
- `lib/authentication/forgot_password/presentation/pages/forgot_password_page.dart`
- `lib/features/splash/presentation/pages/splash_page.dart`
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `lib/features/dashboard/presentation/widgets/demo_video_section.dart`
- `lib/features/profile/presentation/screens/freelancer_profile_screen.dart`
- `lib/features/profile/presentation/screens/bank_details_screen.dart`
- `lib/features/profile/presentation/screens/documents_kyc_screen.dart`
- `lib/features/profile/presentation/screens/face_verification_screen.dart`
- `lib/features/profile/data/services/face_verification_service.dart`
- `lib/features/earning_wallet/presentation/screens/earning_wallet_screen.dart`
- `lib/features/earning_wallet/data/services/wallet_dashboard_service.dart`
- `lib/features/earning_wallet/domain/models/wallet_dashboard_model.dart`
- `lib/features/rewards_commission/data/services/rewards_api_service.dart`
- `lib/features/rewards_commission/presentation/screens/rewards_overview_screen.dart`
- `lib/features/refer_earn/presentation/screens/refer_earn_screen.dart`
- `lib/features/sub_categories/services/link_generation_service.dart`
- `lib/features/sub_categories/services/category_service.dart`
- `lib/features/sub_categories/models/main_category_model.dart`
- `lib/features/sub_categories/models/sub_category_model.dart`
- `lib/features/sub_categories/presentation/screens/sub_categories_screen.dart`
- `lib/features/sub_categories/presentation/widgets/sub_category_card.dart`
- `lib/models/generated_link_model.dart`
- `lib/features/app_installation/presentation/screens/reward_milestone_screen.dart`
- `lib/features/settings/presentation/screens/settings_screen.dart`
- `lib/features/settings/presentation/screens/change_password_screen.dart`
- `lib/features/settings/presentation/screens/faq_screen.dart`
- `lib/features/settings/presentation/screens/privacy_settings_screen.dart`
- `lib/features/settings/presentation/screens/legal_document_screen.dart`
- `lib/features/settings/presentation/screens/contact_support_screen.dart`
- `lib/features/settings/presentation/screens/report_problem_screen.dart`
- `lib/features/settings/data/models/notification_preferences.dart`
- `lib/features/dashboard/presentation/widgets/customer_app_card.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_sidebar.dart`
- `lib/features/dashboard/presentation/widgets/vendor_app_card.dart`
- `lib/features/refer_earn/presentation/widgets/customer_how_it_works.dart`
- `lib/features/refer_earn/presentation/widgets/vendor_how_it_works.dart`
- `lib/features/settings/presentation/widgets/settings_section_card.dart`
- `lib/features/sub_categories/repositories/sub_categories_repository.dart`
- `lib/features/profile/presentation/screens/document_file_picker.dart`

The stale unused `document_file_picker_web.dart` file was removed. Safe Dart analyzer fixes were applied across the existing UI; no visual redesign was made.

### FastAPI (`am5-backend/am5-backend/`)

- `freelance_api/schemas.py`
- `freelance_api/service.py`
- `freelance_api/routers/referrals.py`
- `app/api/v1/endpoints/wallet.py`
- `app/api/v1/endpoints/subscriptions.py`
- `deploy_backend.py`
- `.gitignore`
- `.dockerignore`

No SQLAlchemy model/migration files were changed and no database migration was applied. Restart the local FastAPI process to load source edits if it is not running with reload enabled.


## 2026-11-09 image and Vendor navigation follow-up

The category/subcategory image widget was changed to render API SVG assets through a browser-native `<img>` on Flutter Web, avoiding the CDN's missing CORS header for XHR, and through SVG-aware rendering on native platforms. The actual local API image URLs decoded in Chrome (58/58), while the Flutter Chrome test runner stalled and the authenticated Flutter screen was unavailable after a 401. Treat image integration as PARTIAL until the screen test is completed and the duplicate Driving School image is corrected with an actual asset.

The deployed Vendor site is Flutter Web, but its source is absent and the onboarding-status API it requests returned 404. Bundle route strings were observed but do not establish a valid deep-link contract. Category/subcategory targeting, Vendor login restoration, and referral validation/navigation therefore remain BLOCKED and were not implemented by guessing URLs.

Latest local validation: `flutter pub get`, `flutter analyze`, and regular `flutter test` passed; `flutter build web --release` passed in 63.9 seconds. The browser-specific Flutter test and a control Chrome widget test both stalled in the test runner and were stopped. See `TEST_RESULTS.md` for exact results.

The attempted in-memory Freelancer API test module is BLOCKED in this workspace: with the project `.venv`, its test app rate limiter cannot reach the configured Redis service, and the configured exception handler raises `AttributeError` while handling that connection failure. The separate `memory://` override is not accepted by the Redis client used by security services. No PostgreSQL tests or data changes occurred. See `TEST_RESULTS.md`.
