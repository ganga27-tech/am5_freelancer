-- Add destination metadata for service and Play Store click reporting.
-- Existing click rows remain valid; newly introduced columns are nullable.
ALTER TABLE freelancer_referral_click_events
    ADD COLUMN IF NOT EXISTS destination_type VARCHAR(16),
    ADD COLUMN IF NOT EXISTS service_id BIGINT,
    ADD COLUMN IF NOT EXISTS destination_url VARCHAR(2048),
    ADD COLUMN IF NOT EXISTS vendor_id BIGINT,
    ADD COLUMN IF NOT EXISTS event_token_hash VARCHAR(64);

CREATE INDEX IF NOT EXISTS ix_freelancer_referral_click_events_service_id
    ON freelancer_referral_click_events (service_id);
CREATE INDEX IF NOT EXISTS ix_freelancer_referral_click_events_vendor_id
    ON freelancer_referral_click_events (vendor_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_freelancer_referral_click_events_event_token_hash
    ON freelancer_referral_click_events (event_token_hash)
    WHERE event_token_hash IS NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_freelancer_referral_click_events_destination_type'
    ) THEN
        ALTER TABLE freelancer_referral_click_events
            ADD CONSTRAINT ck_freelancer_referral_click_events_destination_type
            CHECK (destination_type IS NULL OR destination_type IN ('SERVICE', 'PLAY_STORE'));
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_freelancer_referral_click_events_service_id'
    ) THEN
        ALTER TABLE freelancer_referral_click_events
            ADD CONSTRAINT fk_freelancer_referral_click_events_service_id
            FOREIGN KEY (service_id) REFERENCES sub_categories(id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_freelancer_referral_click_events_vendor_id'
    ) THEN
        ALTER TABLE freelancer_referral_click_events
            ADD CONSTRAINT fk_freelancer_referral_click_events_vendor_id
            FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE SET NULL;
    END IF;
END $$;
