# AM5 ROYAL Banner Coverage

Updated 2026-11-09. A section-specific banner is counted as covered only when a related asset or dynamic banner record is actually displayed and verified. Category icons/images are not counted as banners.

| Section/group | Banner coverage | Evidence / remaining work | Status |
|---|---|---|---|
| Dashboard | Not verified | Banner API is present in local route mapping; no section-specific content/render audit recorded | BLOCKED |
| Authentication and OTP | Not verified | No login/registration/forgot-password banner coverage audit | BLOCKED |
| Home Services / category catalog | No confirmed section banner | 38 main-category image references exist; 20 Home Service subcategories use 20 unique images. These are catalog artwork, not banners. | PARTIAL |
| Profile / KYC | Not verified | No verified section banner record or render test | BLOCKED |
| Wallet / rewards / payouts | Not verified | No verified section banner record or render test | BLOCKED |
| Referrals / installation rewards | Not verified | No verified section banner record or render test | BLOCKED |
| Notifications / settings / support | Not verified | No verified section banner record or render test | BLOCKED |
| Demo videos | No banner verified | API returned an empty list; this is video content, not a banner | PARTIAL |

## Existing image coverage (separate from banners)

- Main categories: 38/38 API image references present and prior Chrome decode check succeeded; category IDs 1 and 38 share an image, so unique category art is incomplete.
- Home Services: 20/20 subcategory image references are unique and prior remote image decode audit succeeded.
- The Flutter authenticated page-level Chrome image run remains unverified because the browser test runner stalled and app auth returned 401.
- The banner API route exists locally, but no banner records/content, per-section mapping fields, responsive behavior, loading/error states, or mobile/web display have been verified in this audit.

## Completion needed

1. Agree on the set of sections that should display promotional/section banners and the intended copy/art for each.
2. Confirm whether the existing `/api/v1/banners` schema supports per-section targeting and image metadata.
3. Supply/approve section artwork or use reviewed existing brand assets; do not substitute catalog thumbnails or unrelated art.
4. Add/test section-specific rendering with responsive dimensions, loading, and error states.
5. Verify actual mobile and web views against the approved section list.
## Full navigation and section audit update — 2026-11-09

- Root cause found: the blank areas of service cards had no tap handler, so taps appeared dead. The main-domain URL seen in Chrome came from the separate generated-referral dialog, whose generic “Continue” button opened the referral landing URL. It is now labeled “Open Referral Page”; Vendor service taps remain isolated to the exact Vendor mapping.
- Home Services selection now requires the verified catalog ID 37 and slug `home-services`; it no longer falls back to an unrelated first category.
- Service card surface, image, and title invoke one mapped Vendor callback; Generate Link stays separate. Navigation logs service ID/name and expected/launcher URL and rejects invalid host/path. Mapping strings unchanged.
- Added responsive branded banners for Rewards, Wallet, Settings, and App Installation; existing Home, Services, Referral, and Profile banners remain. Banner API supports seven Freelancer placements, but only Home has a live record; no database banner rows were created.
- Current Flutter checks: analyze PASS; tests PASS (6 passed, 1 browser-only image test skipped); production-mode release build PASS (90.1 sec).
- Fresh actual 20-click Chrome verification remains BLOCKED: the current browser tool was interrupted after showing the live Services page and the referral landing dialog. The mapping test is not counted as browser proof. See `NAVIGATION_ROOT_CAUSE_REPORT.md` and `NAVIGATION_TEST_RESULTS.md`.
## Current section banner implementation and backend content — 2026-11-09

Read-only `GET /api/v1/banners?placement={placement}&audience=freelancer` results:

| Placement | Live API rows | Section treatment |
|---|---:|---|
| home | 1 | Dynamic server banner with responsive carousel/image loading and fallback |
| services | 0 | Branded Services hero; catalog artwork remains service-specific |
| refer_earn | 0 | Existing branded Refer & Earn hero |
| installation_activation | 0 | Branded hero with local one-time-installation illustration |
| rewards_cashback | 0 | Branded Rewards hero with local gifts/rewards illustration |
| earnings_wallet | 0 | Branded Wallet hero with local online-earning illustration |
| profile | 0 | Existing profile-specific gradient header and account photo |
| settings | Not a supported API placement | Branded Settings hero with settings icon |

`SectionHeroBanner` uses responsive sizing, an image progress indicator, and an error fallback. The layout test passed at 360px and the release web build passed. The current banner test did not exercise the remote image route in a mobile browser; page-level real-device banner rendering remains unverified. No banner rows were inserted or changed.