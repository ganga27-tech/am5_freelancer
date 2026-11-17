-- Keep both Home Services catalog identifiers with each existing referral.
-- Existing records are backfilled from their selected subcategory; no data is deleted.
ALTER TABLE freelancer_referral_links
    ADD COLUMN IF NOT EXISTS target_service_category_id BIGINT;

UPDATE freelancer_referral_links AS referral
SET target_service_category_id = subcategory.main_category_id
FROM sub_categories AS subcategory
WHERE referral.target_sub_service_id = subcategory.id
  AND referral.target_service_category_id IS NULL;
