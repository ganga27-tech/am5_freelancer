# AM5 ROYAL Section Checklist

Updated 2026-11-09. Status reflects evidence in the current source checkout and prior verification notes; screen existence alone is not treated as completion.

| Existing section/module | Frontend state | API state | Data safety / verification | Status |
|---|---|---|---|---|
| Login, secure token storage, session restore | Wired through shared client | Local login route exists; production deployment is mismatched | No disposable account for end-to-end session test | PARTIAL |
| Registration | Form and service wired | Local registration route exists | Current API test is blocked before request handling by Redis | PARTIAL |
| Forgot password / OTP | Form and request/verify/reset flow wired | Local POST route exists; production route returns 404 | Delivery provider credentials missing; no actual delivery test | BLOCKED |
| Profile | Read/update and photo flows wired | Routes listed | No JWT/account supplied; no writes performed | PARTIAL |
| KYC and document upload | Screens and API services wired | Routes listed | Sensitive writes not exercised; face provider flow incomplete | PARTIAL/BLOCKED |
| Wallet and payout | Summary/history UI wired | Routes listed | No payout operation attempted; protected response unverified | PARTIAL |
| Rewards and installation rewards | Screens wired | Routes listed | Protected account flows unverified | PARTIAL |
| Referrals | Link/validation UI wired | Local routes/schema documented | No persistent link creation; attribution and deep link handling incomplete | PARTIAL |
| Home Services categories | Dynamic category and subcategory screens | Local public catalog APIs | 38 category references and 20 unique Home Service images checked | PARTIAL (image issue noted below) |
| Freelancer to Vendor navigation | Exact 20-item URL map | External Vendor web destinations | Prior actual Chrome validation: 20/20; current mapping test: PASS | PASS for Freelancer link behavior |
| Dashboard and demo videos | Dashboard and empty state wired | Demo videos API returns empty list | Local GET 200, no content available | PARTIAL |
| Notifications and device registration | UI/service paths present | Routes listed | Protected flows need test identity | PARTIAL |
| Settings, privacy, security, password | Screens and requests present | Routes listed | No account-backed writes run | PARTIAL |
| FAQ, legal, contact support, problem report | Screens/forms present | Routes listed | Protected submission routes unverified | PARTIAL |
| Vendor app and post-login destination preservation | No Vendor source in supplied project | No verifiable route/auth contract | Cannot verify login continuation | BLOCKED |
| Face verification | Freelancer screen exists | Backend session/status endpoints exist | Provider SDK/liveness image submission missing | BLOCKED |

## Global data/security checks

- No production deployment was performed.
- No production customer/account rows were changed.
- Current backend tests use a temporary in-memory database where applicable; the unsafe autouse database fixture was removed from `app/tests/conftest.py`.
- Provider integration tests are opt-in and do not run without dedicated test-recipient configuration.
- Existing credential material found in the supplied project needs rotation outside this work; secrets are not repeated here.
## Full navigation and section audit update — 2026-11-09

- Root cause found: the blank areas of service cards had no tap handler, so taps appeared dead. The main-domain URL seen in Chrome came from the separate generated-referral dialog, whose generic “Continue” button opened the referral landing URL. It is now labeled “Open Referral Page”; Vendor service taps remain isolated to the exact Vendor mapping.
- Home Services selection now requires the verified catalog ID 37 and slug `home-services`; it no longer falls back to an unrelated first category.
- Service card surface, image, and title invoke one mapped Vendor callback; Generate Link stays separate. Navigation logs service ID/name and expected/launcher URL and rejects invalid host/path. Mapping strings unchanged.
- Added responsive branded banners for Rewards, Wallet, Settings, and App Installation; existing Home, Services, Referral, and Profile banners remain. Banner API supports seven Freelancer placements, but only Home has a live record; no database banner rows were created.
- Current Flutter checks: analyze PASS; tests PASS (6 passed, 1 browser-only image test skipped); production-mode release build PASS (90.1 sec).
- Fresh actual 20-click Chrome verification remains BLOCKED: the current browser tool was interrupted after showing the live Services page and the referral landing dialog. The mapping test is not counted as browser proof. See `NAVIGATION_ROOT_CAUSE_REPORT.md` and `NAVIGATION_TEST_RESULTS.md`.
## Navigation/banner implementation update — 2026-11-09

- Services: complete click flow traced. Full card area, image, and title now activate the Vendor service path; referral generation remains a separate named action. Stable Home Services ID/slug check added. Fresh actual Chrome target verification is blocked; see navigation reports.
- Rewards, Earnings & Wallet, Settings, and App Installation now have section-specific responsive AM5 ROYAL hero headers. Home, Services, Refer & Earn, and Profile already had branded/dynamic section headers.
- Current verification: Flutter analyze PASS; 6 tests PASS and 1 browser-only image test skipped; release web build PASS. Protected APIs and writes remain unverified without disposable accounts.