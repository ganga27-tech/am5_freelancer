# Production Deployment Guide

## Current compatibility

- Local: `http://127.0.0.1:8000`; local Swagger: `/docs`; local OpenAPI: `/api/v1/openapi.json` (277 paths).
- Production: `https://api.am5royal.com`; production OpenAPI returned HTTP 200 with 259 paths, but exposes no Freelancer auth/profile/referral/installation endpoints (the only Freelancer-named paths are accounting APIs).
- Do not point Freelancer builds at production until the matching Freelancer backend is deployed and production OpenAPI plus authenticated journeys are verified.

## Build configuration

- Development web: default local API (`flutter run -d chrome`).
- Android emulator: `flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000`.
- Production web: `flutter build web --release --dart-define=API_BASE_URL=https://api.am5royal.com`.
- Production Android/iOS builds must explicitly define the production URL; never use localhost in production.

## Backend release requirements

1. Deploy the source version containing `freelance_api` routers and environment-only payment credentials.
2. Set required runtime credentials through the secret manager/environment. Vendor wallet/subscription payment operations return 503 when payment settings are absent. Deployment SSH scripts require `DEPLOY_SSH_PASSWORD` or key-based access as configured.
3. Confirm production CORS allows the exact frontend origin and `Authorization` header.
4. Review production database schema and apply only forward migrations after backup; no migration is included or applied here.
5. Revoke/rotate credentials exposed in the supplied ZIP/source, including payment/provider/deployment credentials. Remove any copies from repositories, artifacts, and logs.
6. Verify production OpenAPI contains all required Freelancer paths, then run read-only route checks and authenticated tests using a disposable production-like account. Do not use real payout rails.
7. Obtain verified app IDs/signing fingerprints and implement Android/iOS domain association files before publishing app links.

No production deployment, secret-manager change, database migration, payout, or infrastructure operation was performed.

