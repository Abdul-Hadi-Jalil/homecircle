# Milestone 1 — Authentication & Household Onboarding

Implementation completed on 2026-11-05. External acceptance checks remain explicitly pending below. No Docker or local database is used. Milestone 2 was not started.

## Implementation summary

Flutter now provides persistent three-page onboarding, registration with confirmation, email verification/resend with cooldown, login, logout to login, neutral password-reset feedback, recovery password confirmation, invalid-link handling, and session/membership restoration. The hosted Supabase SDK owns Auth and vault-backed session/PKCE persistence. The API profile and memberships are loaded after sign-in. Recovery, pending verification, loading, no-household and ready states are explicit.

Native screens follow the supplied Stitch layouts using the existing HomeCircle palette, rounded cards, home/avatar icons, lavender fields, segmented authentication tabs, and responsive scrolling. All product copy is in the English ARB. Exported demo users and role selectors are not authorization controls.

Profile supports viewing email, editing the display name, a default avatar, household selection and logout. Household onboarding supports create with name/description and atomic creator-admin membership, authenticated invitation preview/confirmation/redemption, avatar/count/role selection, member listing with pagination, and admin name/description settings. Creation leads to Invite Family. Scope changes invalidate household views, caches and realtime subscriptions.

Invitation administration includes generation/rotation, metadata listing, expiry/usage/status, confirmation before replacing/revoking, copy, and the native share sheet. Plaintext is displayed only in the current issuance view and is never saved in preferences or PostgreSQL. Returning to the screen shows metadata and permits generating a replacement.

## Important modified files

- `mobile/lib/features/auth/`: Auth service/repository, form validation, operation ViewModel, onboarding, authentication and verification/recovery screens.
- `mobile/lib/features/household/`: typed household/invitation models, API service/repository, session and action ViewModels, selection/create/join/invitation/member/settings/profile screens.
- `mobile/lib/core/router/`: GoRouter destinations and verification/recovery/admin/household guards.
- `mobile/lib/core/config/app_runtime.dart`: authoritative profile loading during session restoration.
- `mobile/lib/core/localization/app_en.arb`: generated localized strings.
- `mobile/pubspec.yaml` and lock: `share_plus` for native sharing.
- `backend/app/{api/v1,repositories,services,schemas}/`: profile, household, member and invitation layers.
- `backend/app/db/pool.py`: transaction-local actor claims explicitly cast to text for PostgreSQL set_config.
- `backend/tests/` and `mobile/test/milestone_one_test.dart`: permission, input, invitation, state, layout, recovery and guarded database coverage.

## Database changes

Applied to the hosted HomeCircle project with Supabase CLI 3.0.0, verified TLS, and dry-run previews:

1. `20261105000000_household_invitations.sql`: invitation table, RLS, metadata-only API SELECT, unique HMAC hashes, expiry/usage constraints, member-list RPC, admin-only issue/revoke RPCs, atomic member-only redemption and persistent attempt accounting. Parent-first row locks serialize rotation, revocation and redemption; existing membership does not consume a second use. Default expiry is seven days and ten uses.
2. `20261105000001_api_auth_schema_access.sql`: explicit Auth grants. Hosted Auth is owned by supabase_admin, so the postgres migration role could not confer new schema privileges; live checks caught this limitation.
3. `20261105000002_profile_actor_helper.sql`: narrowly scoped argument-free definer helper for the current actor UUID and replacement profile policy expressions. The API retains NOINHERIT and no Auth schema access. No broad authenticated-role membership was granted.

Codes contain 80 random bits and are normalized before HMAC-SHA256 with a server-only pepper. Hashes are unreadable to the API login; only fixed definer functions access them. Preview/redeem share a persistent quota of twenty attempts per authenticated user per five-minute bucket, committed before code validation so failures count. Database rate limits are authoritative; resend cooldown also has a client timer and Supabase rate limiting. Request bodies and codes are not written to application logs.

## API endpoints

All `/api/v1` product routes require a verified Supabase user bearer token; a publishable key alone is insufficient.

| Endpoint | Permission |
| --- | --- |
| GET/PATCH `/me` | Own profile; PATCH display_name only |
| GET `/households` | Own memberships |
| POST `/households` | Authenticated; creator becomes admin atomically |
| GET `/households/{id}` | Member |
| PATCH `/households/{id}` | Admin; name and description |
| GET `/households/{id}/members` | Member; limit 1–100, offset >= 0 |
| POST `/households/{id}/invites` | Admin; issue/rotate, 201, no-store |
| GET `/households/{id}/invites` | Admin; metadata only, paginated |
| DELETE `/households/{id}/invites/{invite_id}` | Admin; revoke, 204 |
| POST `/invites/preview` | Authenticated, rate limited; minimal household metadata |
| POST `/invites/redeem` | Authenticated, rate limited; atomic member-only join |

Unauthorized or missing household details share a 404 response. Existing members cannot use invitations to promote themselves. Error envelopes do not echo secrets or untrusted input.

## Testing results

Executed from `backend/`:

- `.venv/Scripts/python -m ruff check app tests`: passed.
- `.venv/Scripts/python -m ruff format --check app tests`: passed (final formatting was also applied).
- `.venv/Scripts/python -m pytest -q`: **70 passed, 13 skipped**. Skips are the separate hosted database suite, including duplicate-user and competing-user concurrent redemption tests. One upstream Starlette/httpx TestClient deprecation warning remains.
- `.venv/Scripts/python -m pip check`: no broken requirements.

Executed from `mobile/`:

- `dart format lib test`: passed.
- `flutter analyze`: no issues.
- `flutter test --dart-define=LIVE_API_BASE_URL=http://127.0.0.1:8001`: **26 passed**, including real API health and invalid-token handling.
- `flutter build apk --debug --dart-define-from-file=config.local.json`: succeeded; installed and launched on Pixel_4 emulator.

Live hosted read-only checks verified RLS on four public tables, denied API hash reads, denied direct authenticated invitation RPC execution, allowed API member-list execution, and verified the corrected transaction actor binding plus empty outsider household reads. The updated FastAPI process started successfully using the restricted hosted pooler login.

Android onboarding and login were visually inspected: `images/milestone-1-onboarding.png` and `images/milestone-1-login.png`. Narrow-phone registration is covered by a widget test. These checks do not prove real email or signed-in household flows end to end.

The source secret audit passed: the API database password and invitation pepper are absent from publishable files. The temporary privileged migration credential was removed.

## Manual setup and external acceptance

1. In HomeCircle Supabase Auth → URL Configuration, allow `com.homecircle.homecircle://auth-callback`. Confirm email signup/confirmation settings, SMTP/delivery, password policy, email template links and any desired Site URL. Use Supabase confirmation/recovery links that preserve the SDK PKCE flow. Native Android/iOS callbacks are already registered in the project.
2. Use a real mailbox to verify signup → email confirmation → login, resend cooldown, password recovery on the device that requested it, expired/reused links, session restart and logout. No mailbox credentials were supplied, so no real user email was sent during this work.
3. Configure a **separate** hosted Supabase test project, apply all migrations, and set `HOMECIRCLE_TEST_DB=hosted-test`, `HOMECIRCLE_TEST_PROJECT_REF`, `SUPABASE_URL` (app project), `SUPABASE_TEST_DATABASE_URL` (test admin), and optional `SUPABASE_TEST_DATABASE_SSLROOTCERT`. Run `pytest -m integration -q`. The target guard refuses the app project. Most tests roll back; concurrency tests commit only generated fixture records and delete those exact IDs afterward. No schema reset is used.
4. Local `.env` and `config.local.json` are configured and ignored. Keep the generated `INVITATION_PEPPER` stable in the server secret manager. Changing it invalidates existing codes; revoke/rotate when doing so. Optional `INVITATION_EXPIRY_DAYS=7` (1–30) and `INVITATION_MAX_USES=10` (1–1000) configure new codes only.
5. Run FastAPI from `backend/` with the explicit Selector loop and restricted verified-TLS pooler connection. Android emulator API URL is `http://10.0.2.2:8000`; start the API on `0.0.0.0:8000` for emulator access. Use HTTPS for release. No local DB setup is required.
6. iOS build/device testing and native share completion need platform validation; iOS requires macOS/Xcode. Android debug APK is not a signed production distribution.

## Known limitations and acceptance status

Implementation, lint, isolated unit/widget tests, Android build/rendering and hosted catalog/actor checks are validated. Real signup/confirmation/recovery, valid-user API round trips, record-based SQL authorization and concurrent redemption remain pending the external setup above. Therefore full end-to-end acceptance is not claimed.

Image uploads, custom avatars, role management UI and later product CRUD are deferred; default avatars are provided. Invitation metadata UI shows the latest 50 entries; older entries are already revoked by rotation, and API pagination remains available. Member listing loads pages of 50. Invitation rate-limit rows retain one bucket per attempted user and should receive a retention cleanup policy at operational scale.

## Milestone 2 readiness

The implementation provides the intended identity, household scope and invitation foundation. Complete the real-email and separate-project integration acceptance checks before relying on it for production inventory data. Inventory, shopping, tasks, chat and notifications retain their existing later-milestone placeholders. No Milestone 2 work was started.
