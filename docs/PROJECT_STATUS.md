# HomeCircle — current project status

Updated 16 November 2026 (Asia/Karachi). Milestone 7 local hardening, regression
verification and unsigned Android release builds are implemented. **Not Release
Ready. M7 remains partially implemented.** M1–6 hosted/device acceptance remains
pending. The FastAPI service is live on Render, all 13 Supabase migrations are applied,
and the current debug APK uses the hosted HTTPS API. Firebase and release signing
remain unconfigured. [Final QA report](FINAL_QA_REPORT.md),
[Known issues](KNOWN_ISSUES.md), [M6 report](milestone-6-report.md)

## Branding and signed release APK, 20 November

- Launcher icon: an original white house inside a ring on HomeCircle primary blue
  (`#2248D1`) with a secondary-green door. It ships as legacy square/round icons,
  an adaptive icon with a monochrome layer for Android 13 themed icons, and a 512 px
  Play icon at `docs/images/homecircle-play-icon-512.png`. Regenerate with
  `mobile/tool/generate_launcher_icons.py`.
- Splash: brand-blue background with the mark (classic splash and Android 12+
  system splash, light and dark).
- Release signing: a new owner-approved keystore (alias `homecircle`, RSA 4096,
  valid to 2054) is stored outside the repo at
  `C:/Users/abdul/.homecircle-signing/homecircle-release.jks`. Its passwords are in
  the ignored `mobile/android/key.properties`. **Back up both; losing the key means
  no future updates.** Certificate SHA-256
  `31:BE:6C:EB:26:6E:6F:D3:18:91:CA:2C:04:49:CD:C0:40:10:21:49:A0:9D:C5:3D:01:BD:B5:C8:53:DE:67:E4`.
- Signed release APK `1.0.0` (code 2), built with `config.release.local.json`
  (Render API, HTTPS): `mobile/build/app/outputs/flutter-apk/app-release.apk`,
  62,868,753 bytes, SHA-256
  `e7095195037a21b81d059bb78e7d3db40cd473644637a6100c8a48a091718a18`. `apksigner`
  verifies it with the certificate above. Emulator installation timed out under host
  memory pressure; install on a physical device is still to be confirmed.

## Local database acceptance, 20 November

The guarded SQL integration suite ran for the first time, against the dedicated
local Supabase stack (PostgreSQL 17, all migrations applied from scratch).
**Result: 58 passed, 0 skipped.** This covers household/member/outsider RLS,
invitations and concurrent redemption, inventory/task/shopping/chat/hub writes,
revocation, rollback and real concurrent claims, edits and stock application.
Regular suites: backend 239 passed / 58 deselected, Flutter 115 passed / 2 skipped,
Ruff check and format clean. Live API smoke: `/health` and `/ready` 200, missing or
invalid bearer 401, docs/schema 404.

The first run found seven failures. Fixed:

- Task comments: another member changing someone else's comment returned 404
  instead of 403, because `FOR UPDATE` applies the comment UPDATE policy and hid
  the row. The permission check now reads unlocked first, then locks
  (`backend/app/repositories/tasks.py`, `services/tasks.py`, `services/task_photos.py`).
  Access was always denied; only the error was wrong.
- New migration `20261120000000_shopping_inventory_link_delete.sql`: deleting a
  household with shopping items linked to inventory failed on the immediate
  inventory foreign keys of `shopping_item_details` and
  `shopping_inventory_applications`. Both are now checked at commit, so a household
  cascade completes while a lone referenced inventory delete is still refused.
  Applied to the hosted `homecircle` project on 20 November at the user's request,
  after a dry run showed it as the only pending version. The CLI now reports the
  remote database up to date (13 versions), a read-only catalog check confirms both
  constraints are deferrable and initially deferred, and the API `/ready` returns 200.
- Tests: the five-actor matrix now stamps `updated_by` as the app does, and direct
  Storage deletion checks accept the newer `storage.protect_delete()` error.
- Local runner: tags the database and grants `SET` on the app roles through the
  container's local admin role, because current local images do not make
  `postgres` a superuser. Docker Desktop was set to bind published ports to
  loopback by default so the runner's exposure guard passes.

Still open: real email/Auth and
two-device acceptance (flows A–F), Firebase worker delivery and release signing.
Other intra-household `NO ACTION` links (chat replies/linked tasks, chat
conversions, comment attachments) have not been exercised by a household delete.

## Hosted deployment and APK, 16 November

The user authorized Render hosting and applying the pending Supabase migrations,
and requested that full testing continue later. The API is live at
`https://homecircle-api.onrender.com` on Render Free in Singapore, deployed from
commit `49e5d71`. Service ID is `srv-dbt235gae00c739ei3vg`, managed by the HomeCircle
Blueprint `exs-dbt21off3r2c73bn0kgg`. Repository `render.yaml` defines the locked
Python build, database readiness probe and manually triggered service deploys.

The existing database URL and invitation pepper were copied to Render environment
settings with explicit user approval. Supabase public settings were also supplied.
The configured JWT mode is JWKS and the issuer matches the project default.

Five pending migrations applied successfully after correcting the unapplied inventory
access migration to replace an existing manually created actor-name helper. All 12
migration versions are now in hosted history and a subsequent CLI dry run reports
up to date. The restricted API connection sees all inspected inventory, task, shopping,
chat, activity and notification tables, plus the access-lock helper. Selected module
tables have RLS enabled, all four Storage buckets remain private, and API/worker roles
have neither superuser nor BYPASSRLS privileges. Full multi-user and concurrency
acceptance remains pending.

Deployment verification returned HTTP 200 for `/health` and `/ready`, HTTP 401 for
unauthenticated `/api/v1/me`, and HTTP 404 for production docs/schema endpoints.
The installable development-signed APK rebuilt successfully with the Render URL and
passed APK signature verification. It is at
`mobile/build/app/outputs/flutter-apk/app-debug.apk`, size 210,800,767 bytes, SHA-256
`3265cc6952b541a0dd8b85641fc76921d7fbfbf7e8a734c822a8360ae60b19b8`.
Ignored local/release public configuration files now use the fixed HTTPS address.
Release signing and signed-in/device workflow acceptance remain pending. Firebase
setup requires the Android configuration and server worker credentials described in
the setup guide. Render Free can sleep after inactivity and needs time to wake.
[Deployment guide](DEPLOYMENT_GUIDE.md), [Firebase setup](setup.md#firebase-android)

## Local Supabase follow-up, 15 November

This dated setup record precedes the hosted deployment above. The user deferred
executing the local database tests on 16 November.

The user approved local Supabase testing after the existing project's Free-plan
dashboard blocked preview branch creation. WSL 3.0.5 is installed and Windows has
enabled Virtual Machine Platform. Windows explicitly requires a restart before the
WSL 2 engine can run. Docker Desktop 4.99.0 and CLI 29.9.3 are installed, but Docker
shows an engine-stopped state until the Windows feature takes effect. The dedicated local
workspace and runner are prepared with all 12 migrations, project ID `homecircle-test`,
PostgreSQL port 55422 and API port 55421. [Local testing](LOCAL_TESTING.md)

Backend preflight passes with 239 tests and 58 integration skips. The new local-target
guards require an explicit local-test mode, loopback socket, dedicated port and
disposable database marker. All concurrency cases use the same connection checks.
Actual SQL tests, local Auth/Storage and two-client acceptance remain pending the
running local stack. M7 and QA-01 remain open.

Read-only checks against the hosted app database now succeed through `homecircle_api`.
The role has no CREATE DATABASE, CREATE ROLE or superuser privilege. Inventory tables
exist, but the `lock_inventory_household` helper and inspected task, shopping, chat,
activity and notification tables are absent. The dashboard identifies `inventory_photos`
as its last migration. The restricted API role cannot read migration history. This
confirms a deployed schema gap for M2 access fixes and M3–6, with owner migration
history verification still required. No hosted schema changes were made in this check.

## Milestones

UI reference organization (14 November 2026): all 25 screen export folders now sit
directly under `UI/`. The four identical design-system copies were consolidated at
`UI/warm_household_modern/DESIGN.md`; original content hashes were verified. The
numbered `home circle screens` wrapper folders were removed and report links updated.

| Milestone | Status | Evidence / limits |
| --- | --- | --- |
| 0 — Foundation | Completed | Approved Flutter/FastAPI/Supabase foundation exists. Repaired environments and existing regression tests pass. |
| 1 — Authentication & Households | Partially Implemented | Auth, households, invitations, member listing, switching and admin settings exist. Real email/device callbacks, signed-in multi-user and hosted SQL acceptance remain unverified. Role/removal RPCs have no management UI. |
| 2 — Inventory | Partially Implemented — hosted acceptance pending | Backend, Flutter screens, photos, caches/drafts and isolated tests implemented. Analysis, tests and Android debug build pass. Migrations deployed on 16 November. RLS/concurrency behavior and real Storage transfers remain unverified. |
| 3 — Tasks & Repairs | Partially Implemented — hosted acceptance pending | Repair/Chore/General requests, assignment/claims, status/reopen, discussions/photos/activity, inventory links and offline caches/drafts implemented. Stitch exports in UI/ reviewed and adapted. Isolated tests, analysis and debug build pass. Migration deployed. Real Auth/API/Storage acceptance remains pending. |
| 4 — Shopping | Partially Implemented — hosted acceptance pending | Shared shopping uses household_tasks plus one-to-one details, purchase history and an idempotent inventory ledger. API, localized Flutter UI, offline drafts and isolated tests implemented. Migration deployed. Realtime and database behavior acceptance remain pending. |
| 5 — Chat & Realtime | Partially Implemented — hosted acceptance pending | Backend-connected chat, private Realtime invalidation/outbox, images, replies/reactions, ownership, task sharing/conversion and secure offline reading/drafts implemented. Migration deployed. RLS/Storage behavior and two-client Realtime acceptance remain unverified. |
| 6 — Dashboard/Notifications/Activity | Partially Implemented — external acceptance pending | Real-data dashboard, unified activity, persistent notifications, preferences, Android FCM transport and durable worker implemented. Migration deployed. RLS behavior, Firebase configuration, hosted worker, live FCM and device acceptance remain pending. Dedicated dashboard/activity Realtime remains incomplete with refresh fallbacks. |
| 7 — Testing/Polish/Release | Partially Implemented — Not Release Ready | Backend preflight 239 passed/58 skipped. Flutter M7 run 115 passed/2 skipped. Analysis/lint pass. API live on Render and all 12 migrations deployed. A development-signed APK rebuilt with the hosted URL passes signature verification. Full SQL/device testing is deferred by the user. Hosted security behavior, Firebase, branding and production signing remain open. |

## Milestone 7 verification summary

The following records the 14 November milestone run. The 15 November local test
preparation and latest backend results are recorded above.

Final local backend checks pass with 226 tests and 58 guarded database skips. Flutter
passes 115 tests with two optional live API skips. Analysis, Ruff, formatting and
dependency checks pass. All 85 protected API operations reject absent bearer identity.
All 12 migration files, containing 371 top-level statements, pass a parser-only check.
The hosted migration history and actual RLS semantics remain unverified.

Unsigned release APK/AAB and a locally configured development-signed debug APK build.
The debug APK installed and reached onboarding on the API 37 emulator. Emulator
System UI/launcher ANRs occurred during host memory pressure, so device/performance
acceptance remains open. Current release artifacts omit runtime defines and display
configuration feedback. Release signing, HTTPS runtime configuration, Firebase and
approved Android branding remain required.

M7 adds no database migration. Existing migrations remain pending verified deployment
history and disposable-project acceptance. Candidate `1.0.0+2` retains the existing
application ID pending owner confirmation. Detailed fixes, changed files, artifact
hashes, test commands, five-user/flows A–F coverage and release blockers are recorded
in the final QA report. [Final QA report](FINAL_QA_REPORT.md),
[Release checklist](ANDROID_RELEASE_CHECKLIST.md), [Deployment guide](DEPLOYMENT_GUIDE.md)

## Implemented inventory functionality

- Real FastAPI integration for overview, item details, add/edit, name search, category/type/stock/condition/exact-location filters, sorting and pagination.
- Consumables use exact decimal strings (12 integer digits, up to 3 decimal places), supported units and optional minimum stock. Zero = Out of Stock; positive quantity <= minimum = Low Stock; otherwise Available.
- Durable items have Working/Needs Repair/Broken conditions, purchase dates and last-service dates.
- Default and household-created categories, free-text storage locations, notes, quantity update bottom sheet, condition changes, activity with actor names, archived-only browsing and restore.
- Private gallery photo upload/replace/read/remove from item details after saving the item. Pillow validates decoded JPEG/PNG/WebP, applies EXIF orientation, removes metadata and re-encodes JPEG; limits are 5 MiB and 16 MP.
- User/household-scoped cached pages, categories, summaries, item fields and visited activity. Saved overview items can open offline without a prior details visit. Only fetched pages/views are available offline; uncached searches/pages require connectivity.
- Locally saved forms restore their original edit revision. Saving is explicit; failed offline saves retain drafts. Reconnection never replays writes. Photo bytes are not persisted in preferences/drafts.
- Scope changes clear visible data, reject old-household actions and discard late responses. Reads started before writes cannot restore stale cached snapshots. Authorization failures do not use cache fallback.

The earlier M2 audit did not recover Stitch exports. The user subsequently identified them in `UI/` during M3; the initial default search missed that folder. M3 screens were reviewed against the supplied task designs and adapted to the shared HomeCircle theme. M2 exact-reference fidelity has not been re-audited; real device appearance remains unverified. Inventory/task UI is English; Urdu remains future work.

## Inventory security and concurrency

- Retained FastAPI -> Pydantic -> service -> parameterized async Psycopg repository architecture, psycopg_pool, restricted homecircle_api role and transaction-local verified actor claims. Retained Flutter Provider/ChangeNotifier, http and GoRouter. No ORM, Riverpod or Dio.
- New owner-executed lock_inventory_household(uuid) acquires the parent FOR SHARE lock and checks current membership. This avoids admin-only household UPDATE RLS affecting ordinary-member inventory operations. Execution is restricted to the API role; caller identity is never accepted as input.
- Edit, condition, archive/restore and photo writes compare expected revisions under item locks. Absolute quantity SET now requires a revision; relative adjustments use locked current quantities and reject underflow/overflow. Item/activity changes share one transaction.
- A household-scoped actor-name helper supports current/former participants without broadening profile RLS or limiting names to the first 100 members.
- Storage uses the verified user's bearer token and optional public project key; no service-role credential. Object paths are <household>/<item>/<random-object>.jpg. Upload authorization expires after 60 seconds; overwrites are denied.
- Authenticated API photo reads return Cache-Control: no-store; no public/signed URLs are issued. Archived references retain their photo for restore and are excluded from active-photo reads.
- An upload finalization flag prevents cleanup from deleting an in-flight attachment. Storage cleanup is limited to finalized, unreferenced objects. Uploaders can temporarily read their authorized object to allow Storage insertion to finish.
- Replace/remove and failed attachments attempt Storage API cleanup. Crashes, revocation or outages can leave private orphans; operational retention must retry them. Never delete Storage object metadata directly in SQL.

These are implementation/isolated-test findings. Actual PostgreSQL RLS, locking and hosted Storage behavior are not proven by mocks.

## Tests actually executed

| Check | Latest result |
| --- | --- |
| Python virtualenv | Repaired in place using installed Python 3.13 and venv --upgrade; existing packages retained. |
| flutter pub get --enforce-lockfile | Passed; regenerated old-user SDK/Pub paths without upgrading locked mobile versions. |
| Backend pytest -q (from backend/) | 173 passed, 36 skipped; one existing Starlette/httpx deprecation warning. |
| Ruff check / format | Passed, 55 files formatted, no findings; original E402/E501 errors resolved. |
| pip check | Passed, no broken requirements. |
| flutter analyze | Passed, no issues. |
| Full flutter test --no-pub --dart-define=CAPTURE_TASKS=true | 73 passed, 2 skipped (optional live health/invalid-token checks). |
| Dart formatting | Passed, current source formatted. |
| Android debug build | Passed with flutter build apk --debug --no-pub and the existing task-local Java trust store; TLS verification stayed enabled. No configured-user/device acceptance is implied. |
| Hosted deployment diagnostic | Read-only connection attempt failed with OperationalError; catalog/history could not be established. No migrations applied. |
| Disposable hosted test project | User confirmed it is not configured and requested implementation continue with the gap documented. No integration writes attempted. |

Baseline after environment repair: backend 70 passed/13 skipped; Flutter 24 passed/2 skipped. Current counts supersede intermediate runs. Widget tests exposed narrow-phone overflow and a disposed bottom-sheet controller; both were fixed. M3 overview/form/details captures with real test-loaded fonts at 360 × 800 were inspected for layout against supplied designs; this does not replace device or accessibility acceptance. Task-only suite: 19 passed.

Test evidence:

- backend/tests/test_inventory.py: stock/type/decimal boundaries, stale conflicts, relative quantities, conditions, archive/restore, simulated activity rollback, image validation/EXIF/metadata, user-token Storage requests/failures, authenticated API dispatch/filters/schema validation and no-store reads.
- backend/tests/test_inventory_integration.py: seven guarded cases, including ordinary-member writes/outsider denial, categories/names, repository revisions/archive/restore/activity, actual rollback on event failure, Storage metadata policies/revocation and two concurrent quantity cases. All seven remain skipped.
- mobile/test/inventory_test.dart: 15 tests covering overview/filters, quantity sheet, durable payloads, photo revisions, drafts, offline details, no write replay, household switching, old-action rejection, late search responses and stale-cache suppression.
- Existing Milestone 0–1 regression tests still pass. Fixtures are confined to tests; production UI uses real HTTP.

## Migrations and files

Preserved existing migration order:

1. 20261104000000_foundation.sql — profiles/households/memberships/RLS/RPCs.
2. 20261104000001_private_storage.sql — private buckets.
3. 20261105000000_household_invitations.sql — invitations/member-list support.
4. 20261105000001_api_auth_schema_access.sql — Auth grants; historical hosted limitations are in the M1 report.
5. 20261105000002_profile_actor_helper.sql — narrow actor helper.
6. 20261105000003_inventory.sql — existing categories/items/activity, constraints and policies.
7. 20261105000004_inventory_photos.sql — existing expiring authorization/Storage policies.
8. NEW 20261113000000_inventory_access.sql — ordinary-member parent lock, actor names, upload finalization and orphan cleanup policies.
9. NEW 20261114000000_tasks.sql — task/comment/attachment/activity tables, constraints, revisions, member-removal assignment, scoped actor names, RLS, upload permits and private repair-photo policies.
10. NEW 20261114000001_shopping.sql — shopping details, per-purchase inventory application ledger, exact quantities/prices, deferred consistency/actor constraints and member-scoped RLS. No earlier migration was changed.

Older reports claim deployment of 1–5; not reverified. Deployment of 6–10 is unknown; none was applied during this task. Do not assume local migrations ran or rewrite deployed history. Apply pending SQL to a disposable hosted test project first using Supabase CLI, then run guarded behavior tests before app-project deployment.

Implementation changes:

- Extended existing backend/app/{api/v1,repositories,schemas,services}/inventory.py and router registration.
- Added backend/app/services/inventory_photos.py, inventory backend tests, backend/tools/inspect_inventory_deployment.py and the new migration. The diagnostic is read-only and never prints connection strings or raw exceptions.
- Added mobile/lib/features/inventory/{models,services,repositories,viewmodels,views}/ and inventory tests; wired runtime/Provider/GoRouter and LocalStore draft removal.
- Added iOS photo-library usage text; iOS still needs macOS/Xcode validation.
- Added Pillow >=12,<13 to backend metadata, pinned 12.3.0 in both locks. Existing mobile decimal/image_picker dependency changes predated this task and were preserved. No other dependency upgrades were intentionally made.
- Updated README/architecture/status documentation. Generated environments/caches/logs remain ignored; credentials were not added to source.

## Required manual setup and remaining acceptance

1. Configure a separate disposable hosted project with all migrations. Set HOMECIRCLE_TEST_DB=hosted-test, HOMECIRCLE_TEST_PROJECT_REF, SUPABASE_TEST_DATABASE_URL, optional SUPABASE_TEST_DATABASE_SSLROOTCERT, and SUPABASE_URL identifying the different app project. Run python -m pytest -m integration -q from backend/. The guard rejects app-project/production/unsafe targets. Most tests roll back; concurrency tests commit generated IDs and clean only those IDs.
2. Prove actual ordinary-member writes, outsider isolation, revocation, concurrent quantities, stale conflicts, archived discovery/restore, names and activity rollback. SQL source and skipped tests are not passing database evidence.
3. Perform real test-project Auth -> FastAPI -> PostgreSQL -> Storage acceptance: create consumable/durable items, upload/replace/read/remove photos, archive/restore, switch households and repeat as outsider/revoked user. SQL metadata fixtures do not test real Storage byte transfer.
4. Configure the API's restricted database connection, verified TLS and SUPABASE_PUBLISHABLE_KEY for its project; match the app's public configuration/issuer. No service-role key is required for inventory or tasks. Keep credentials local.
5. The API now bounds inventory/task photo JSON bodies to 8 MiB before parsing, including chunked input. Also configure the reverse-proxy body limit/timeouts. Establish orphan retention: after confirming no in-flight upload (for example, older than one hour), finalize abandoned authorization rows and retry deleting unreferenced objects through Storage API. Retain referenced archived photos; do not remove authorization rows before objects.
6. Close M1 real-email verification/recovery, callback allowlist, session restart and signed-in two-user household acceptance. Missing role/removal UI does not confer admin permissions, but real auth/household security acceptance remains a gate.
7. Run the configured Android app with real test users to verify picker, responsive UI, photo operations and offline transitions. Debug compilation passes; device acceptance, iOS and release signing are unverified. The machine-specific Java trust-store workaround is in docs/setup.md.

## Milestone 3 implementation and acceptance

The [M3 implementation report](milestone-3-report.md) records the task model, full
API table, UI design references/adaptations, security boundaries, files changed,
test evidence and manual gates. Implemented:

- Repair, Chore and General CRUD, archive/restore, assignment/unassignment and atomic claims.
- Low/Normal/High/Urgent priorities; Open/In Progress/Blocked/Completed/Cancelled; explicit reopen, dates/overdue, search/filter/sort/pagination and real summary counts.
- Author/admin comments, task/comment private photos, actor names and activity. Photo requests use user JWTs, normalized JPEG and 60-second no-store signed URLs kept only in memory. Already issued URLs remain usable until expiration after revocation.
- Same-household inventory links and related repairs in inventory details. Completion never changes inventory automatically. A separate explicit confirmation may mark a durable item Working; failure leaves the repair completed.
- User/household-scoped cached pages/details/discussions and local drafts, original edit revisions, no automatic offline write synchronization, stale-response/scope rejection and no cache fallback on authorization errors.
- Flutter task screens adapt the supplied Stitch exports: summary cards, request tiles, member initials, priority pills, information grid, section cards, discussion bubbles and fixed save controls. Shared theme/navigation are retained. Demo data, unavailable shopping and future notification promises are excluded. Exact pixel fidelity and device/text-scaling acceptance are not claimed.

Important new files: backend/app/api/v1/tasks.py, backend/app/repositories/tasks.py,
backend/app/schemas/task.py, backend/app/services/{tasks,task_photos}.py,
backend/app/core/photo_body_limit.py, backend/tests/test_tasks{,_integration}.py,
mobile/lib/features/tasks/ and mobile/test/tasks_test.dart. Router/runtime/provider,
localization, inventory related repairs, Storage transport and deployment diagnostic
integration were extended. README, architecture, security and milestones are updated.
No M3 dependency upgrades were introduced.

Security evidence: isolated tests cover typed input/actor rejection, revision conflicts,
claim serialization, rollback, comment authorization, photo lifecycle and scoped client
state. Nine new task SQL integration cases are skipped, including ordinary-member RLS,
cross-household references, actual concurrent claims/edits, member removal, rollback
and private Storage metadata. Actual PostgreSQL policy/concurrency behavior and real
Storage bytes therefore remain unverified. The catalog diagnostic returned
`connection_unavailable`; no production/database deployment changes were made.

Next: configure the disposable test project and apply migrations there, run all guarded
SQL cases, then exercise real users and photo transfer/expiry/cleanup in the
configured app. Close M1 email/deep-link/session/multi-user household acceptance and
M2 hosted inventory RLS/quantity/photo gates. Review Android picker/offline/switching
and text scaling; iOS needs macOS/Xcode. Do not treat skipped tests or the debug APK
as live acceptance. Retention cleanup remains operational work; no worker is shipped.

M2 and M3 remain **Partially Implemented — hosted acceptance pending**.
M4 was subsequently implemented at the user’s request, as recorded below.
Chat/realtime remains M5 and FCM/product dashboard/activity remains M6.

Retain approved decisions: multiple households/account, email/password, member
inventory/task writes, admin-only sensitive management, scoped cached reading/drafts
without offline synchronization, English then Urdu, Android then iOS, hosted Supabase
plus a separate FastAPI service.

## Milestone 4 implementation and acceptance

See [the M4 report](milestone-4-report.md) for the model, API table, status rules,
design adaptations, files changed and deployment requirements. Implemented and
covered by isolated tests:

- One Shopping household task per request with one shopping detail. Shared priorities,
  assignment/claim, revision and task activity are reused. Optional exact quantities,
  supported units, notes, links, prices and currency codes are validated.
- List/search/filters/sort/pagination, consistent progress counts, combined details,
  edit, responsibility, purchase, explicit undo/reopen/cancel and purchase history.
- Purchase records the verified user and a fresh purchase UUID. Generic task status
  requests use shopping-aware transitions. Closed purchase fields require reopening.
- Inventory entry opens a prefilled form. Duplicate awareness offers View Existing
  or Add Another. Purchasing leaves stock for a separate explicit confirmation.
- The stock operation locks current task/detail/inventory, reuses inventory quantity
  logic, and commits stock/activity/ledger/application metadata atomically. Retrying
  the same purchase UUID cannot add stock twice. Undo retains physical stock and
  original purchase events. Failed application keeps the purchase saved and allows retry.
- User/household-scoped cached list/details/summary/history and local form drafts,
  retained original edit revisions, rejected late/foreign responses and no write replay.
- Stitch-based list/form, purchase sheet, responsibility/details/history, localized
  states and keyboard-safe save controls. Shopping remains a secondary route. Real-font
  list/form/purchase captures were inspected. Device/text scaling/iOS remain unverified.

M4 added 27 passing backend cases and 15 passing Flutter cases. Seven guarded SQL
cases cover ordinary members/RLS/isolation, constraints, purchases/undo/history,
actual rollback and concurrent claim/purchase/stock application. These seven are
among the 36 skipped integration cases because the disposable project is still not
configured. No SQL migration was validated or applied. Actual database triggers,
RLS, locking and multi-user end-to-end behavior remain acceptance gaps.

Realtime remains incomplete. Manual/pull refresh and refresh on app resume are
implemented, and the UI makes no live-sync claim. Configure and test private channels
before reporting realtime acceptance. M1 email/session/household and M2–3 hosted
gates remain prerequisites for secure acceptance. Apply all migrations to the separate
test project and run the guarded suite before app-project deployment. M4's migration
backfills empty details for outstanding/cancelled legacy Shopping parents while
preserving task IDs/revisions. Completed legacy Shopping parents require purchase
attribution review. No production records were changed.

M4 remains **Partially Implemented — hosted acceptance pending**. M5 was subsequently
implemented at the user's request, as recorded below. M6 notifications/dashboard
product work was not started.

## Milestone 5 implementation and acceptance

See [the M5 report](milestone-5-report.md) for the complete 13-part implementation
report: changed files, schemas, API table, Flutter components, Realtime mechanism,
authorization, retries/concurrency, checks, manual setup and remaining limits.

- Implemented household chat with real API history, text, replies, six reactions,
  own edits/deletion, normalized private images, task sharing and reviewed conversion
  through existing Repair/Chore/General/Shopping forms and services.
- Stable client UUIDs deduplicate sends and conversion retries. Revisions reject stale
  edits. Composite household keys, actor claims and API-role RLS protect data scope.
  Chat operations serialize per household to preserve committed change-cursor order.
- Transactional invalidations/outbox and private, per-current-member Realtime topics
  are implemented. Owner-only dispatch attempts immediate publication; an operator
  Cron job retries pending events every minute. Clients refetch, deduplicate and catch
  up on reconnect, with periodic/manual/resume refresh. No raw body is broadcast.
- Secure storage holds bounded history, composer/pending/source-form drafts, partitioned
  by account and household. Logout/known revocation clears private state. Images and
  signed URLs are not persisted. Restored failed sends require manual retry; no
  automatic offline sending. Reviewed task data follows the existing task cache policy.
- `UI/family_chat` was reviewed and adapted to HomeCircle. Rendered chat was inspected
  with real fonts at 390×844; reply/reaction/edit/delete interaction passed. Exact
  pixel/device/accessibility and platform secure-storage/image-picker acceptance remain pending.

Verified 14 November 2026:

| Check | Actual result |
| --- | --- |
| Backend Ruff format/check | Clean |
| Backend pytest | **195 passed, 46 skipped**; existing upstream TestClient deprecation warning |
| Python dependency consistency | No broken requirements |
| Flutter package restoration | Succeeded; dependency lock unchanged |
| Dart formatting / Flutter analysis | Clean |
| Flutter full tests | **90 passed, 2 skipped** |
| Real-font chat widget capture/interaction | Passed |
| Android debug APK | Passed; physical-device/iOS acceptance pending |
| Read-only deployment diagnostic | Separate test project false; connection unavailable |
| Hosted SQL/RLS/Storage/two-client Realtime | **Unverified**; no test project configured |

The 46 skipped backend cases include ten new chat SQL cases for ordinary-member
access, revocation, cross-household references, direct grants, image finalization,
private topic helpers, outbox rollback, conversions and real concurrent duplicate
sends/stale edits. Two optional Flutter live API cases were skipped. Isolated tests
do not prove actual PostgreSQL triggers/policies or Supabase transport behavior.

Migration `20261114000002_chat.sql` and owner job
`supabase/operations/chat_realtime_jobs.sql` are **not applied**. The existing hosted
workflow must apply and validate migrations in order on the separate disposable
project first. No production records, private credentials or locked dependency
versions were changed. Configure private channels/public-access restrictions,
Storage and owner Cron, then run guarded integration and two-real-user acceptance.
Stranded private objects need a reviewed operator retention workflow; failed cleanup
is best effort. Signed URLs may remain usable for up to 60 seconds after revocation.

M1 real authentication/email/callback/session/member-removal acceptance and M2–4
hosted SQL/Storage/transaction gates remain open. **M5 is Partially Implemented —
hosted acceptance pending.** M6 was subsequently implemented as recorded below.
M5 completion still requires its live acceptance checks.

## Milestone 6 implementation and acceptance

Dashboard aggregation, unified family activity, persistent notifications, household
preferences, Android Firebase Messaging and the standalone delivery worker are
implemented. The report contains the requested 15-part implementation record with
files, schemas, endpoints, metric definitions, delivery semantics and setup steps.
[M6 report](milestone-6-report.md)

- The dashboard uses one backend aggregation statement. Summary cards link to active
  tasks, urgent requests, Shopping and low-stock inventory. Quick actions reuse existing
  forms/chat. Attention includes overdue/priority requests, stock shortages and durable
  condition issues. Upcoming and recent lists are bounded.
- Family activity projects persisted inventory/task/shopping events and new membership
  events. Source/revision identities collapse duplicate derived audit rows. Existing
  histories continue to work. Chat text and invitation codes stay out of the feed.
- Notifications persist recipient/read/dismiss state. Category preferences and own-action
  suppression govern generation. Stock alerts follow meaningful transitions. Explicit
  member mentions are supported in chat while preserving pre-M6 retry hashes.
- Private delivery jobs use leases, retry limits, exponential backoff, authorization
  checks and permanent/invalid-target outcomes. Worker credentials use a separately
  restricted database login and backend-only Firebase Admin credentials.
- Device target rotation, authenticated installation revocation, logout tombstones and
  serialized native registration cleanup are implemented. Foreground banners appear
  above nested navigators. Notification taps validate the recipient, restored session,
  destination household and target before routing.
- Secure caches partition dashboard, activity and notifications by user/household and
  show offline/last-refresh state. Read/preference mutations require server confirmation.
  Scope changes reject late responses and clear visible data. Logout clears private cache.

Verified on 14 November 2026 in Asia/Karachi.

| Check | Actual result |
| --- | --- |
| Backend baseline | 195 passed, 46 skipped |
| Flutter baseline | 90 passed, 2 skipped |
| Backend full suite | **219 passed, 56 skipped**, one upstream TestClient warning |
| Flutter full suite | **107 passed, 2 skipped** |
| Ruff format/check | Passed |
| Flutter formatting/analysis | Passed |
| Python dependency consistency | Passed |
| Firebase dependency restoration | Passed with existing locked versions preserved |
| Android debug build | Passed with Firebase packages and configuration-disabled runtime |
| SQL static parser | 71 top-level statements, 12 PL/pgSQL bodies and dashboard query parsed |
| Read-only deployment diagnostic | Test project unconfigured, connection unavailable |
| Hosted migration/RLS and FCM/device acceptance | Unverified |

The final Android build passed in 85.8 seconds. Flutter reports a nonblocking
`firebase_core` Kotlin Gradle Plugin migration warning for future Flutter compatibility.

Ten new guarded database cases contribute to the skipped total. They cover real metric
calculations, local dates, activity projection/pagination, recipient RLS, preferences,
stock alerts, mentions, device rotation/leases, logout replay, member removal and rollback.
The two optional Flutter live API cases remain skipped. Static parsing used placeholder
catalog row types and establishes syntax evidence. Database semantics require the
separate disposable project. Migration deployment remains pending.

The supplied Dashboard, Family Activity and Notifications designs were reviewed and
adapted to the shared HomeCircle theme. Real-font captures use API test fixtures.
Device visual fidelity, text scaling, secure storage and OS interaction remain open.
[Dashboard capture](images/milestone-6-dashboard.png) ·
[Activity capture](images/milestone-6-activity.png) ·
[Notifications capture](images/milestone-6-notifications.png)

The user confirmed that the intended Firebase project is unconfigured. Manual setup
requires the Android app configuration for `com.homecircle.homecircle`, backend ADC,
the restricted worker login/process and a Google Play-enabled test device. The setup
guide provides those steps and the controlled acceptance scenarios.
[Setup](setup.md)

The household time zone defaults to UTC and supports administrator configuration
through dashboard settings. Dedicated dashboard/activity Supabase Realtime remains
incomplete. Periodic/pull/resume reads and foreground push invalidation are implemented.
M1–5 hosted acceptance remains open. Production database records were untouched.

**M6 is Partially Implemented — external acceptance pending.** Hosted SQL/RLS, configured
push delivery, Android app-state navigation and operational acceptance remain required.
Milestone 7 remains unstarted.

At resume, read this file and git status --short before editing. Preexisting untracked inventory backend/migrations and modified router/mobile dependency files were preserved. Git commit 4819101's message is not acceptance evidence; older reports contain historical results and do not override this file.
