# PAN-India Readiness

Updated 2026-11-09 — **PARTIAL; nationwide coverage not established**.

| Area | Source evidence | Status |
|---|---|---|
| Indian mobile format | Flutter UI checks 10 digits starting 6–9; backend has normalization and Indian mobile variants | PARTIAL; registration API tests blocked by Redis |
| Email | Client syntax validator and backend schemas exist | PARTIAL; SMTP missing |
| States/cities | Profile fields and location/city models/routes exist | PARTIAL; no statewide operational coverage audit |
| PIN code | Vendor registration schema has six-digit Indian PIN pattern; Freelancer profile fields are optional strings without the same observed constraint | PARTIAL |
| Service availability/location | Catalog and location APIs/data models exist | PARTIAL; city-wise availability and coverage were not exhaustively verified |
| Currency | Backend reward/wallet schemas default to INR; Flutter formats rupees | PASS for currency conventions only |
| Booking time/time zone | Referral code uses UTC-aware operations in some paths; mixed legacy naive timestamps remain, and booking flows were not tested | PARTIAL |
| Scalable configuration | API base URL is build-configurable; Redis/provider config is environment-driven | PARTIAL; Redis and delivery credentials absent |
| Nationwide operations | City/service-area and provider supply coverage not proven | BLOCKED / not claimed |

Do not describe the service as operational across India until verified service-area data, active provider coverage, dispatch capacity, and state/city test cases are supplied.