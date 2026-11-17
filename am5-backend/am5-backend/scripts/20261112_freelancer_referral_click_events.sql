-- Store first-party Vendor referral click events without rewriting referral rows.
-- visitor_id and event_id are SHA-256 hashes of random first-party cookie values.
CREATE TABLE IF NOT EXISTS freelancer_referral_click_events (
    id BIGSERIAL PRIMARY KEY,
    event_id VARCHAR(64) NOT NULL UNIQUE,
    referral_id BIGINT NOT NULL
        REFERENCES freelancer_referral_links(id),
    freelancer_id BIGINT NOT NULL
        REFERENCES freelancers(id),
    visitor_id VARCHAR(64) NOT NULL,
    clicked_at TIMESTAMPTZ NOT NULL,
    redirect_status VARCHAR(24) NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_freelancer_referral_click_events_referral_id
    ON freelancer_referral_click_events (referral_id);
CREATE INDEX IF NOT EXISTS ix_freelancer_referral_click_events_freelancer_id
    ON freelancer_referral_click_events (freelancer_id);
CREATE INDEX IF NOT EXISTS ix_freelancer_referral_click_events_visitor_id
    ON freelancer_referral_click_events (visitor_id);
