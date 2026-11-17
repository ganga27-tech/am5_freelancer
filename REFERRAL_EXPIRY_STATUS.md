# Referral Expiry Status

## Implemented in local source

- Flutter service referral requests use `POST /api/v1/referrals/links` with `referral_type=service`, the selected `target_sub_service_id`, and exactly 7 or 15 `validity_days`.
- Pydantic now rejects unsupported referral types, validity durations other than 7/15, and service referrals with no positive subcategory ID.
- Generation now uses `secrets.token_urlsafe(32)` and refuses missing/inactive subcategories.
- Server expiry is computed from UTC. The existing database record stores freelancer owner, referral code, type, subcategory ID/name, URL, validity, status, creation time and expiry time.
- Validation checks the stored link status and expiration on every call. Expired/invalid results are returned in a consistent `success=false` response with `data.status`; expired link requests are not treated as active. This API currently returns HTTP 200 for invalid/expired validation results.
- Flutter requires server token/creation/expiry fields, displays created/expiry time in IST, active/expired state and remaining validity, disables sharing after local expiry, and checks backend validity before Continue/open.

## Verified

- Pydantic schema checks: valid 7-day and 15-day service link payloads accepted; invalid duration and missing destination rejected.
- Python compile check passed.
- Local OpenAPI exposes GET validation and authenticated GET/POST links.
- No referral was created because there is no disposable test JWT/account. No DB changes were made.

## Blockers / risks

- Freelancer registration schema has no referral code input or referral attribution field. Vendor/customer signup code is not included, so expired links cannot yet be verified at actual registration and no conversion can be securely attributed end-to-end.
- Referral record stores the subcategory ID but not a main category ID or declared FK. Category can only be resolved by joining catalog data. A safe migration and product attribution model are still needed if main-category persistence is mandatory.
- Generated web URL currently uses `/services/{subcategoryId}?ref={code}`. A verified host route that validates and resolves this URL into the Vendor app was not supplied. Do not deploy this link flow as complete until that route is implemented and tested.
- A database-backed 7/15-day expiration journey was not exercised; protected POST requires a disposable local test account and authenticated DB session.
