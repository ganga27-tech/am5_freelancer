# Database Changes

## Changes made

**No database schema or data changes were executed.** No migration ran, no tables were reset/dropped, no rows were deleted/seeded, and no test account was created. Read-only Freelancer category/subcategory GETs exercised the local PostgreSQL-backed API.

Existing local catalog data:

- 38 active main categories; all 38 return `category_image_url` from the API.
- Home Services category ID 37 has 20 active subcategories; all 20 return unique `image_url` values.
- Main categories and subcategories are already represented by `main_categories` / `sub_categories`; images are referenced by existing `icon` / `icon_url` fields and public R2 references.
- `FreelancerReferralLink` has owner, subcategory ID/name, token, validity, status, created_at and expires_at columns, but no stored main-category column and no declared FK to the catalog row.

## Backend source-only changes

Referral validation/creation behavior and Pydantic request validation were changed in local source; no schema change was needed. Payment provider literals were removed from `app/api/v1/endpoints/wallet.py` and `subscriptions.py` and are now read from environment variables. If unset, vendor payment endpoints fail closed with HTTP 503. The deployment script password was also moved to an environment variable.

A future category-attribution column or registration-attribution relationship requires a reviewed forward-only migration and backup plan. It was not fabricated or applied.

