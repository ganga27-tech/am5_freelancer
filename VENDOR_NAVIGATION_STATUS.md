# Vendor Navigation Status

## 2026-11-09 live inspection

**Result: BLOCKED.** The vendor site is a deployed Flutter Web application. No Vendor app source is present in `C:\Users\pc\AM5_ROYAL` alongside the Freelancer Flutter project and backend. The deployed bundle contains strings for `/login`, `/map`, `/select-service`, `/select-subcategory`, and `/vendor-dashboard`, plus `mainCategoryId` and `subCategoryId` names. These bundle strings do not establish a supported public URL/query contract, so the Freelancer app does not emit guessed Vendor URLs.

Chrome DevTools on `https://vendor.am5royal.com/` showed the Vendor app remaining on its splash while `GET https://api.am5royal.com/api/v1/vendors/me/onboarding-status` returned 404. The page also logged Firebase web-config 404 and Firebase Messaging service-worker MIME errors. No login was attempted, no credentials were entered, and the Vendor authenticated navigation flow could not be reached.

Required Vendor-side work before Freelancer can safely link into it: provide the Vendor source/repository and verified router/auth code; define one deep-link contract that resolves the service from a validated backend referral token; persist the pending destination through login and refresh; restore it only after successful vendor authentication; and handle invalid/expired tokens before navigation. Then update the Freelancer action to use that verified contract and test both auth states. No application IDs, signing data, query names, or route shapes were invented.

**Result: BLOCKED / PARTIAL.** The supplied Flutter source is the Freelancer web/mobile application. The Vendor frontend/source is not present in this workspace. The backend has vendor routers, and Freelancer API responses construct vendor-domain URLs, but no verified per-category Vendor route or application deep link contract was supplied.

The Freelancer services screen now uses the selected category ID to fetch that category's subcategories for every category; it no longer sends only Home Services to a generic vendor map URL. This preserves correct category selection in the current app, but does not satisfy direct routing into the separate Vendor application.

Not safely implementable without the Vendor app contract:

- category-specific Vendor screen/slug route and vendor/session check;
- preserving pending service navigation through Vendor login;
- Vendor login failure and expired referral handling;
- direct referral service navigation after login.

No application IDs, signing certificate fingerprints, or target route paths were invented. No production route was modified.

## Mapping test follow-up — 2026-11-09

The current Freelancer source now contains 20 Home Services subcategory-to-URL entries. `flutter test --no-pub` passes the test asserting 20 distinct URLs, expected ID/slug pairs, and rejection of inactive or mismatched services. This verifies the local mapping table only. The Vendor app source is still unavailable, so those route strings could not be cross-checked against its router, and login/session return behavior remains blocked. No login redirect was added or inferred.
