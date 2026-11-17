-- Store successful Vendor OTP authentication events only.
-- Repeated application is safe; no existing user/vendor records are rewritten.
CREATE TABLE IF NOT EXISTS vendor_login_events (
    id BIGSERIAL PRIMARY KEY,
    event_id VARCHAR(64) NOT NULL,
    user_id BIGINT NOT NULL,
    vendor_id BIGINT NOT NULL,
    referral_attribution_id BIGINT NULL,
    login_at TIMESTAMPTZ NOT NULL,
    login_method VARCHAR(20) NOT NULL,
    session_event_id VARCHAR(64) NOT NULL,
    login_result VARCHAR(16) NOT NULL,
    is_first_login BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_vendor_login_events_event_id UNIQUE (event_id),
    CONSTRAINT uq_vendor_login_events_session_event_id UNIQUE (session_event_id),
    CONSTRAINT ck_vendor_login_events_success_only CHECK (login_result = 'success'),
    CONSTRAINT fk_vendor_login_events_user_id
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_vendor_login_events_vendor_id
        FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE,
    CONSTRAINT fk_vendor_login_events_referral_attribution_id
        FOREIGN KEY (referral_attribution_id)
        REFERENCES vendor_referral_attributions(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_vendor_login_events_user_id
    ON vendor_login_events (user_id);
CREATE INDEX IF NOT EXISTS ix_vendor_login_events_vendor_id
    ON vendor_login_events (vendor_id);
CREATE INDEX IF NOT EXISTS ix_vendor_login_events_referral_attribution_id
    ON vendor_login_events (referral_attribution_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_vendor_login_events_first_login_per_vendor
    ON vendor_login_events (vendor_id)
    WHERE is_first_login;
