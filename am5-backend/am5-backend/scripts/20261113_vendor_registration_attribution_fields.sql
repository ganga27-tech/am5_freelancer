-- Add registration/install provenance to existing immutable referral rows.
-- Existing rows are retained; new columns are nullable for historical data.
ALTER TABLE vendor_referral_attributions
    ADD COLUMN IF NOT EXISTS user_id BIGINT,
    ADD COLUMN IF NOT EXISTS installation_tracking_id VARCHAR(128),
    ADD COLUMN IF NOT EXISTS registration_status VARCHAR(16),
    ADD COLUMN IF NOT EXISTS registration_source VARCHAR(32);

CREATE INDEX IF NOT EXISTS ix_vendor_referral_attributions_user_id
    ON vendor_referral_attributions (user_id);
CREATE INDEX IF NOT EXISTS ix_vendor_referral_attributions_installation_tracking_id
    ON vendor_referral_attributions (installation_tracking_id);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_vendor_referral_attributions_user_id'
    ) THEN
        ALTER TABLE vendor_referral_attributions
            ADD CONSTRAINT fk_vendor_referral_attributions_user_id
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_vendor_referral_attributions_installation_tracking_id'
    ) THEN
        ALTER TABLE vendor_referral_attributions
            ADD CONSTRAINT fk_vendor_referral_attributions_installation_tracking_id
            FOREIGN KEY (installation_tracking_id)
            REFERENCES freelancer_installation_trackings(tracking_id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_vendor_referral_attributions_registration_status'
    ) THEN
        ALTER TABLE vendor_referral_attributions
            ADD CONSTRAINT ck_vendor_referral_attributions_registration_status
            CHECK (registration_status IS NULL OR registration_status = 'success');
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_vendor_referral_attributions_registration_source'
    ) THEN
        ALTER TABLE vendor_referral_attributions
            ADD CONSTRAINT ck_vendor_referral_attributions_registration_source
            CHECK (
                registration_source IS NULL OR registration_source IN
                ('install_referrer', 'home_service_referral', 'vendor_referral')
            );
    END IF;
END $$;
