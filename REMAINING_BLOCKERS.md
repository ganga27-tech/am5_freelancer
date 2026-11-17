# Remaining Blockers

## 2026-11-09 image/navigation follow-up

- **Driving School art — PARTIAL:** local category ID 38 shares its image URL with Training & Education (ID 1). A reviewed, uploaded asset and a verified backend URL are needed before that record can be corrected.
- **Flutter Web image verification — PARTIAL:** a live Chrome image audit decoded 58/58 API images, but the authenticated Flutter Services screen could not be reopened after the session returned 401. Both simple and image-specific `flutter test --platform chrome` runs stalled during loading and were stopped. The production release build and normal Flutter tests pass.
- **Vendor destination and auth handoff — BLOCKED:** Vendor source is absent. The production Vendor splash calls an onboarding-status endpoint that returns 404, so vendor login, category routes, direct subcategory routes, session restoration, and referral expiry handling could not be tested.
- **Referral deep link — BLOCKED:** verified Vendor link contract and Vendor-side token validation/navigation implementation are required; no route/query contract was guessed.

1. **Protected integration tests:** no disposable local Freelancer user/JWT or isolated database was supplied. All protected GETs return 401 and cannot prove user payloads.
2. **Production API mismatch:** production OpenAPI has no Freelancer auth/profile/wallet/referrals/installation routes. Matching backend deployment is required before production use.
3. **Vendor application:** Vendor frontend/source and per-category destination contract are absent. Category screens cannot safely redirect into exact Vendor service screens or preserve pending navigation through login.
4. **Deep links:** no verified Android package/signature, iOS bundle/team IDs, association files, or target web/Vendor route was provided.
5. **Referral attribution/expiry at registration:** current Freelancer registration request has no referral token and no referred-user relationship. Expiration is checked by the validation API, but actual vendor/customer registration enforcement and conversion attribution are not integrated.
6. **Referral URL contract:** backend-generated `/services/{subcategoryId}?ref=...` route is not present in this Flutter app and its web/Vendor host behavior is unverified. Referral feature remains partial.
7. **Referral database relation:** current link row has target subcategory ID but no category ID or catalog FK. Safe migration/business attribution design remains needed if explicit category storage is required.
8. **Face verification:** provider SDK/liveness image submission integration is missing from Flutter.
9. **Other category imagery:** 38 main category references and 20 Home Services references pass URL checks; some non-Home subcategories have no images, and Driving School currently shares Training & Education art. Category-specific reviewed assets are needed for those rows.
10. **Credentials:** secrets were embedded in the supplied source/ZIP. Wallet and subscription payment routes now read keys from environment and fail closed; the deploy script password is also environment-sourced. Exposed credentials still require rotation and repository history/artifact cleanup.
11. **Local server refresh:** backend source edits require restarting/reloading the user's running FastAPI process before those edits take effect. It was not stopped or restarted.
12. **Support/payment writes:** no support ticket, KYC/bank/profile mutation, payout, or payment operation was created or tested.


## Continuation blockers — 2026-11-09

- Production Forgot Password remains unavailable: the live POST to `/api/v1/freelancer/auth/forgot-password` returns HTTP 404, and production OpenAPI does not list the route. The local backend on port 8000 was not running.
- Email OTP needs valid SMTP host credentials and `EMAILS_FROM_EMAIL`. SMS OTP needs gateway credentials plus the registered password-reset DLT template ID and body. None are configured locally; actual delivery must be tested after they are supplied.
- Backend API tests still require reachable Redis. The rerun produced six safe 503 failures; the API suite's SQLite fixture remained isolated.
- Chrome image runner remains blocked at test loading. Flutter's VM suite skips that browser-only test, so the live Flutter page still needs a successful browser run.
- Vendor URL strings are internally covered by a passing 20-entry mapping test. The Vendor app source/verified router contract is still absent, so end-to-end route validity and login redirect/session restoration remain blocked.
- No deployment or production account mutation occurred.

## Final-submission blockers — 2026-11-09

1. **Redis/local backend suite:** Memurai Developer installation was canceled at Windows administrator consent (MSI exit code 1602). To resume, rerun `winget install --id Memurai.MemuraiDeveloper --exact --accept-source-agreements --accept-package-agreements` and accept the Windows administrator prompt. After installation, verify `PING` on port 6379, then rerun the six API tests and full suite.
2. **Production Forgot Password:** local route is registered; production OpenAPI/route return 404. Deployment owner must publish the matching backend build and verify proxy routing; no deployment was performed here.
3. **Email OTP:** configure `SMTP_USER`, `SMTP_PASSWORD`, and `EMAILS_FROM_EMAIL`, and verify `SMTP_HOST`/`SMTP_PORT` for the chosen provider; then test receipt using a dedicated test mailbox.
4. **SMS OTP:** provide `SMS_USER_ID`, `SMS_PASSWORD`, provider-assigned `SMS_SENDER_ID`/`SMS_PEID`, approved `SMS_PASSWORD_RESET_TPID`, exact DLT-approved `SMS_PASSWORD_RESET_TEMPLATE` containing `{otp}`, and a dedicated test destination. Provider acceptance must be followed by actual phone receipt confirmation.
5. **OTP signing/storage:** set a random `SECRET_KEY` with at least 32 characters; Redis-backed OTP tests require reachable `REDIS_URL`.
6. **Vendor post-login return:** Vendor app source/route contract is not included; Vendor-side auth must preserve the requested service path after login.
7. **Section banners:** an API route exists but no per-section content/render coverage has been verified. Approve the section list/artwork and confirm banner schema before implementation; do not count catalog images as banners.
8. **End-to-end account modules:** profile, KYC, bank, wallet, payout, rewards, notifications, support writes, and role-based admin/vendor CRUD need isolated identities/disposable test database. No customer records or real payouts should be used for verification.
9. **Image follow-up:** category IDs 1 and 38 share an image; authenticated Flutter page image verification is incomplete. Supply reviewed Driving School artwork and an authenticated test identity.
10. **Credential hygiene:** exposed historic credentials in project artifacts require rotation and repository/artifact cleanup by the credential owners.

No production deploy or production account mutation was performed.
## Full navigation and section audit update — 2026-11-09

- Root cause found: the blank areas of service cards had no tap handler, so taps appeared dead. The main-domain URL seen in Chrome came from the separate generated-referral dialog, whose generic “Continue” button opened the referral landing URL. It is now labeled “Open Referral Page”; Vendor service taps remain isolated to the exact Vendor mapping.
- Home Services selection now requires the verified catalog ID 37 and slug `home-services`; it no longer falls back to an unrelated first category.
- Service card surface, image, and title invoke one mapped Vendor callback; Generate Link stays separate. Navigation logs service ID/name and expected/launcher URL and rejects invalid host/path. Mapping strings unchanged.
- Added responsive branded banners for Rewards, Wallet, Settings, and App Installation; existing Home, Services, Referral, and Profile banners remain. Banner API supports seven Freelancer placements, but only Home has a live record; no database banner rows were created.
- Current Flutter checks: analyze PASS; tests PASS (6 passed, 1 browser-only image test skipped); production-mode release build PASS (90.1 sec).
- Fresh actual 20-click Chrome verification remains BLOCKED: the current browser tool was interrupted after showing the live Services page and the referral landing dialog. The mapping test is not counted as browser proof. See `NAVIGATION_ROOT_CAUSE_REPORT.md` and `NAVIGATION_TEST_RESULTS.md`.
## Demonstration follow-up blockers — 2026-11-09

- Fresh actual Chrome navigation proof is still required for all 20 service actions, including image/title/blank-card clicks, repeats and browser-back behavior. The current source mapping and widget tests pass but do not establish the final browser URL or Vendor-rendered service. Vendor source is unavailable to verify server redirects/login return.
- The API currently has one Home banner row and no rows for Services, Refer & Earn, Installation, Rewards, Wallet or Profile. Local branded headers fill the UI; if section artwork must be centrally managed, populate reviewed section records via the existing supported API/admin flow only after approval.
- No Rewards redemption API/business rule exists in current Freelancer routes; provide eligibility, expiry, idempotency and ledger requirements before implementing redemption.
- Official Android/iOS listing URLs are absent; supply verified links before adding download actions.
- PAN-India city/service-area coverage and protected account journeys remain unverified.