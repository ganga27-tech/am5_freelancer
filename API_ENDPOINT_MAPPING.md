# API Endpoint Mapping

All routes below are from local `http://127.0.0.1:8000/docs` / `/api/v1/openapi.json`. Requests use the shared Flutter API client except the public category and referral-link helper clients. Bearer JWT is required where noted.

| Feature | Method and path | Request / response mapping | Auth |
|---|---|---|---|
| Register | POST `/api/v1/freelancer/auth/register` | full_name, mobile_number, email, password, confirm_password -> registration result | Public |
| Login | POST `/api/v1/freelancer/auth/login` | identifier, password -> access_token, token_type, user | Public |
| Forgot password | POST `/api/v1/freelancer/auth/forgot-password` | identifier, preferred_channel -> challenge_id, expiry_seconds | Public |
| Verify OTP | POST `/api/v1/freelancer/auth/verify-otp` | challenge_id, otp, purpose -> reset token | Public |
| Reset password | POST `/api/v1/freelancer/auth/reset-password` | reset_token, new_password, confirm_new_password | Public |
| Change password | POST `/api/v1/freelancer/auth/change-password` | current_password, new_password, confirm_new_password | JWT |
| Profile | GET/PATCH `/api/v1/freelancer/profile` | profile fields supported by backend: full_name, first_name, last_name, city, state, address, pincode, bio | JWT |
| Profile completion | GET `/api/v1/freelancer/profile/completion` | completion response | JWT |
| Profile photo | POST `/api/v1/freelancer/profile/photo` | multipart image | JWT |
| Bank details | GET/PUT `/api/v1/freelancer/bank-details` | account_holder_name, account_number, ifsc_code, bank_name | JWT |
| KYC | GET `/api/v1/freelancer/kyc/status`; POST `/api/v1/freelancer/kyc/documents`, `/api/v1/freelancer/kyc/submissions` | multipart document upload; submission: aadhaar_number, pan_number, gst_number, document_ids | JWT |
| Face verification | POST/GET `/api/v1/freelancer/kyc/face-verification`; GET `/api/v1/freelancer/kyc/face-verification/status` | backend session/provider configuration and status | JWT |
| Wallet | GET `/api/v1/wallet/summary`, `/api/v1/wallet/transactions` | summary and paginated transaction data | JWT |
| Payout | POST `/api/v1/wallet/payout-request` | amount -> request status | JWT; not called |
| Rewards | GET `/api/v1/rewards/summary`, `/api/v1/rewards/history` | summary and paginated reward history | JWT |
| Referral links | POST/GET `/api/v1/referrals/links` | create: referral_type, target_sub_service_id, validity_days; list: type/status/page/limit | JWT |
| Referral validation | GET `/api/v1/referrals/validate/{code}` | returns valid/status/type/target/expiry/referrer | Public |
| Referral progress | GET `/api/v1/referrals/level-progress`, `/api/v1/referrals/rewards/summary`, `/api/v1/referrals/points/history`, `/api/v1/referrals/rules` | progress, reward totals, points history, public rules | JWT except rules |
| Installation rewards | GET `/api/v1/installation-rewards/rules`, `/statistics`, `/tracking`, `/status`, `/eligibility` | app_type/page/limit filters as declared by OpenAPI | Rules public; account data JWT |
| Settings | GET `/api/v1/freelancer/settings`; PATCH `/api/v1/freelancer/settings/notifications`, `/privacy`, `/security` | backend snake_case preference fields | JWT |
| Notifications | GET `/api/v1/freelancer/notifications`, `/unread-count`; PATCH `/api/v1/freelancer/notifications/{id}/read`, `/read-all` | list/unread and read actions | JWT |
| Devices | POST `/api/v1/freelancer/notifications/devices`; DELETE `/api/v1/freelancer/notifications/devices/{deviceId}` | device token add/remove | JWT |
| Support | POST `/api/v1/support/tickets`, `/api/v1/support/problem-reports`; GET `/api/v1/faqs` | ticket fields; problem fields; FAQ list | POST JWT; FAQs public |
| Legal | GET `/api/v1/legal-pages`; POST `/api/v1/freelancer/legal-acceptances` | slug/page content; acceptance payload | Public GET; POST JWT |
| Categories and images | GET `/api/v1/service-categories?status=active`; GET `/api/v1/service-categories/{categoryId}/subcategories?status=active` | main `category_image_url`; subcategory `image_url`; dynamic category/subcategory IDs and relationships | Public |
| Banners | GET `/api/v1/banners` | banner list | Public |
| Demo videos | GET `/api/v1/demo-videos` | `audience=freelancer` -> active video list | Public |

Local OpenAPI exposes demo-videos. The local GET returned HTTP 200 with an empty `data` list. The general Vendor catalog routes are separate from the Freelancer API routes. Protected read routes were probed without a JWT and returned 401, so their user-data response schemas were not represented as end-to-end verified. Confirm request/response schema details in local Swagger before production changes.


