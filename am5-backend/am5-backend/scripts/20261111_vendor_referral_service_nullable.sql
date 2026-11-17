-- Allow Vendor app invitations to use the existing immutable attribution row
-- without assigning a Home Service. Existing service attribution rows remain
-- unchanged.
ALTER TABLE vendor_referral_attributions
    ALTER COLUMN service_id DROP NOT NULL;
