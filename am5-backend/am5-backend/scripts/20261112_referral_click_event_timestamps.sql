-- Base declares created_at and updated_at on every SQLAlchemy model.
-- Add their server defaults to click-event tables created by the initial migration.
ALTER TABLE freelancer_referral_click_events
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE freelancer_referral_click_events
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
