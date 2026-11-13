# HomeCircle — current project status

Updated: 14 November 2026 (Asia/Karachi). Milestone 2 implementation and isolated verification are finished; hosted acceptance is pending. Milestone 3 has not started. Milestone 2's hosted acceptance remains pending; no hosted migration or production data changes have been made.

## Milestones

| Milestone | Status | Evidence / limits |
| --- | --- | --- |
| 0 — Foundation | Completed | Approved Flutter/FastAPI/Supabase foundation exists. Repaired environments and existing regression tests pass. |
| 1 — Authentication & Households | Partially Implemented | Auth, households, invitations, member listing, switching and admin settings exist. Real email/device callbacks, signed-in multi-user and hosted SQL acceptance remain unverified. Role/removal RPCs have no management UI. |
| 2 — Inventory | Partially Implemented — hosted acceptance pending | Backend, Flutter screens, photos, caches/drafts and isolated tests implemented. Analysis, tests and Android debug build pass. Actual migration deployment, RLS/concurrency and real Storage transfers remain unverified. Do not mark Completed yet. |
| 3 — Tasks & Repairs | Not Started | Placeholder only; inventory foundation ready for the task module after hosted acceptance. |
| 4 — Shopping | Not Started | Placeholder only. |
| 5 — Chat & Realtime | Not Started | Placeholder and channel lifecycle scaffold only; no feature subscriptions. |
| 6 — Dashboard/Notifications/Activity | Partially Implemented | Navigation and diagnostics exist; product dashboard, FCM and family activity absent. Inventory has separate activity history. |
| 7 — Testing/Polish/Release | Partially Implemented | Regression tests and debug APK pass; production signing/distribution and full hosted/device acceptance pending. |

## Implemented inventory functionality

- Real FastAPI integration for overview, item details, add/edit, name search, category/type/stock/condition/exact-location filters, sorting and pagination.
- Consumables use exact decimal strings (12 integer digits, up to 3 decimal places), supported units and optional minimum stock. Zero = Out of Stock; positive quantity <= minimum = Low Stock; otherwise Available.
- Durable items have Working/Needs Repair/Broken conditions, purchase dates and last-service dates.
- Default and household-created categories, free-text storage locations, notes, quantity update bottom sheet, condition changes, activity with actor names, archived-only browsing and restore.
- Private gallery photo upload/replace/read/remove from item details after saving the item. Pillow validates decoded JPEG/PNG/WebP, applies EXIF orientation, removes metadata and re-encodes JPEG; limits are 5 MiB and 16 MP.
- User/household-scoped cached pages, categories, summaries, item fields and visited activity. Saved overview items can open offline without a prior details visit. Only fetched pages/views are available offline; uncached searches/pages require connectivity.
- Locally saved forms restore their original edit revision. Saving is explicit; failed offline saves retain drafts. Reconnection never replays writes. Photo bytes are not persisted in preferences/drafts.
- Scope changes clear visible data, reject old-household actions and discard late responses. Reads started before writes cannot restore stale cached snapshots. Authorization failures do not use cache fallback.

Inventory screens use the established HomeCircle theme. Exact Stitch fidelity and real device appearance remain unverified.

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
| Backend pytest -q (from backend/) | 95 passed, 20 skipped; one existing Starlette/httpx deprecation warning. |
| Ruff check / format | Passed, 41 files formatted, no findings; original E402/E501 errors resolved. |
| pip check | Passed, no broken requirements. |
| flutter analyze | Passed, no issues. |
| Full flutter test --no-pub | 39 passed, 2 skipped (optional live health/invalid-token checks). |
| Dart formatting | Passed, current source formatted. |
| Android debug build | Passed with flutter build apk --debug --no-pub and the existing task-local Java trust store; TLS verification stayed enabled. No configured-user/device acceptance is implied. |
| Hosted deployment diagnostic | Read-only connection attempt failed with OperationalError; catalog/history could not be established. No migrations applied. |
| Disposable hosted test project | User confirmed it is not configured and requested implementation continue with the gap documented. No integration writes attempted. |

Baseline after environment repair: backend 70 passed/13 skipped; Flutter 24 passed/2 skipped. Current counts supersede intermediate runs. Widget tests exposed narrow-phone overflow and a disposed bottom-sheet controller; both were fixed. Inventory layout was inspected in a widget capture; device acceptance remains pending.

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

Older reports claim deployment of 1–5; not reverified. Deployment of 6–8 is unknown; none was applied during this task. Do not assume local migrations ran or rewrite deployed history. Apply pending SQL to a disposable hosted test project first using Supabase CLI, then run guarded behavior tests before app-project deployment.

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
4. Configure the API's restricted database connection, verified TLS and SUPABASE_PUBLISHABLE_KEY for its project; match the app's public configuration/issuer. No service-role key is required for inventory. Keep credentials local.
5. Configure a reverse-proxy photo JSON body limit around 8 MiB and normal request timeouts. Establish orphan retention: after confirming no in-flight upload (for example, older than one hour), finalize abandoned authorization rows and retry deleting unreferenced objects through Storage API. Retain referenced archived photos; do not remove authorization rows before objects.
6. Close M1 real-email verification/recovery, callback allowlist, session restart and signed-in two-user household acceptance. Missing role/removal UI does not confer admin permissions, but real auth/household security acceptance remains a gate.
7. Run the configured Android app with real test users to verify picker, responsive UI, photo operations and offline transitions. Debug compilation passes; device acceptance, iOS and release signing are unverified. The machine-specific Java trust-store workaround is in docs/setup.md.

## Next milestone

M2 remains Partially Implemented until hosted migrations, RLS/concurrency, Auth and
Storage acceptance pass in the separate disposable project. M1 live authentication
and household acceptance remains a prerequisite. M3 has not started in this snapshot.
Do not start shopping, chat/realtime, notifications or dashboard features automatically.

At resume, read this file and git status --short before editing. Preexisting untracked inventory backend/migrations and modified router/mobile dependency files were preserved. Git commit 4819101's message is not acceptance evidence; older reports contain historical results and do not override this file.
