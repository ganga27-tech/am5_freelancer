-- Allow the existing re_verification_pending status (23 characters).
-- Safe and repeatable: this widens the type without updating existing rows.
ALTER TABLE vendors
    ALTER COLUMN status TYPE VARCHAR(32);