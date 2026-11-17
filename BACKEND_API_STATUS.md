# AM5 ROYAL Backend API Status

Updated 2026-11-09. Routes below describe the supplied local FastAPI source, not production availability. Production currently returns 404 for OpenAPI and the Freelancer Forgot Password route.

| Module | Local/source state | Integration/test evidence | Status |
|---|---|---|---|
| Freelancer auth/register/login | Routes registered | API tests blocked by Redis rate limit; no disposable account | PARTIAL |
| Forgot password / verify OTP / reset | POST route registered locally; response definitions 202/422 | Focused OTP/provider suite 18 passed; providers not configured; production POST 404 | BLOCKED |
| Profile / photo / settings | Routes and Flutter services listed in API mapping | Protected account flow not run without test identity | PARTIAL |
| KYC / face verification | Upload/session/status routes exist | Face-provider submission integration incomplete; no KYC write | PARTIAL/BLOCKED |
| Categories / subcategories / images | Public routes exist and local API image coverage documented | Read-only API/image checks passed | PASS for catalog reads |
| Vendor navigation | Freelancer URL mapping is client-side | Exact 20 routes were verified in Chrome in prior run; Vendor auth behavior unavailable | PASS client-side / Vendor-side BLOCKED |
| Wallet / rewards / subscriptions | Routes and Flutter API services exist | No payout; protected data journeys need test JWT | PARTIAL |
| Referral / installation rewards | Local routes and schemas exist | Validation tested; no persistent creation or attribution journey | PARTIAL |
| Notifications / devices | Routes exist | No user JWT/device credential for end-to-end test | PARTIAL |
| Support / FAQs / legal | Routes exist | Public FAQ/legal route coverage documented; protected creation/acceptance not run | PARTIAL |
| Banners / demo videos | Routes exist | Demo video list returned empty; banner content not verified | PARTIAL |
| Admin/vendor/employee/accounting/marketing | Routers are included by local API router | No complete role-based CRUD/security test sweep performed in this run | BLOCKED for full verification |

## Forgot Password mismatch

Local source includes `/api/v1/freelancer/auth/forgot-password` as POST with HTTP 202 and 422 response schemas. Production checks on 2026-11-09 returned 404 for `GET /openapi.json` and for an intentionally empty invalid POST to that route. No valid identifier was submitted. This is consistent with an unavailable/stale deployment or proxy route configuration; production source/version and reverse-proxy prefix must be checked by the deployment owner. No deploy was performed.

## OTP configuration required

SMTP code defaults to Gmail host/port (smtp.gmail.com:587), but real account settings are not configured. Set `SMTP_USER`, `SMTP_PASSWORD` (provider app password or SMTP credential), and `EMAILS_FROM_EMAIL`; verify `SMTP_HOST` and `SMTP_PORT` against the chosen sender. `EMAILS_FROM_NAME` is optional/defaulted.

SMS requires `SMS_USER_ID`, `SMS_PASSWORD`, provider-approved `SMS_SENDER_ID`, provider-assigned `SMS_PEID`, `SMS_PASSWORD_RESET_TPID`, and the exact approved `SMS_PASSWORD_RESET_TEMPLATE` including `{otp}`. The template ID and body must be approved/registered for the DLT principal and match provider registration. Live delivery also needs a dedicated `SMS_TEST_DESTINATION` for the opt-in integration test, followed by recipient confirmation; a gateway acceptance response alone is not proof of receipt.

`SECRET_KEY` must be set to a cryptographically random secret of at least 32 characters for safe OTP challenge storage. `REDIS_URL` must resolve to a working Redis-compatible service (default `redis://localhost:6379/0`). No credential values are included in this report.

## Data and migration notes

No migration or production database mutation was performed. Protected CRUD, foreign-key behavior, and role permissions remain unverified without isolated test data and role-specific test identities. The full backend suite currently fails six API cases due to unavailable Redis; see `TEST_RESULTS.md`.
## Full navigation and section audit update — 2026-11-09

- Root cause found: the blank areas of service cards had no tap handler, so taps appeared dead. The main-domain URL seen in Chrome came from the separate generated-referral dialog, whose generic “Continue” button opened the referral landing URL. It is now labeled “Open Referral Page”; Vendor service taps remain isolated to the exact Vendor mapping.
- Home Services selection now requires the verified catalog ID 37 and slug `home-services`; it no longer falls back to an unrelated first category.
- Service card surface, image, and title invoke one mapped Vendor callback; Generate Link stays separate. Navigation logs service ID/name and expected/launcher URL and rejects invalid host/path. Mapping strings unchanged.
- Added responsive branded banners for Rewards, Wallet, Settings, and App Installation; existing Home, Services, Referral, and Profile banners remain. Banner API supports seven Freelancer placements, but only Home has a live record; no database banner rows were created.
- Current Flutter checks: analyze PASS; tests PASS (6 passed, 1 browser-only image test skipped); production-mode release build PASS (90.1 sec).
- Fresh actual 20-click Chrome verification remains BLOCKED: the current browser tool was interrupted after showing the live Services page and the referral landing dialog. The mapping test is not counted as browser proof. See `NAVIGATION_ROOT_CAUSE_REPORT.md` and `NAVIGATION_TEST_RESULTS.md`.
## Section and navigation audit update — 2026-11-09

- `/api/v1/banners` source supports placements `home`, `services`, `refer_earn`, `installation_activation`, `rewards_cashback`, `earnings_wallet`, and `profile`; schema matches the Dashboard Flutter parser. Read-only query counts: 1 Home row, 0 for each other supported placement. No API/database banner mutation was performed.
- Rewards backend exposes summary and history reads. No redemption endpoint or server-side redemption/idempotency contract was found in the Freelancer router; redemption must not be faked in Flutter.
- Service route strings remain the exact 20-item Freelancer map. Current Chrome click destination proof is blocked; see `NAVIGATION_ROOT_CAUSE_REPORT.md`.