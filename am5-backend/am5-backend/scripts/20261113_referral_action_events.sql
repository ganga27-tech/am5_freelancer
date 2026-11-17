-- Referral interaction events are limited to an authenticated Freelancer's
-- explicit copy/share button actions. No recipient/device identifiers are stored.
CREATE TABLE IF NOT EXISTS freelancer_referral_action_events (
    id BIGSERIAL PRIMARY KEY,
    event_id VARCHAR(64) NOT NULL UNIQUE,
    referral_id BIGINT NOT NULL REFERENCES freelancer_referral_links(id) ON DELETE CASCADE,
    freelancer_id BIGINT NOT NULL REFERENCES freelancers(id) ON DELETE CASCADE,
    event_type VARCHAR(24) NOT NULL CHECK (event_type IN ('copy', 'share_initiated')),
    platform VARCHAR(16) NULL CHECK (
        platform IS NULL OR platform IN ('android', 'ios', 'web', 'windows', 'macos', 'linux', 'unknown')
    ),
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_freelancer_referral_action_events_referral_time
    ON freelancer_referral_action_events (referral_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS ix_freelancer_referral_action_events_freelancer_time
    ON freelancer_referral_action_events (freelancer_id, occurred_at DESC);