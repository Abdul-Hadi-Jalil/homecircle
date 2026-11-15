# Deployment and operations

This is an operator runbook. The user authorized hosted deployment on 16 November.
The FastAPI API is live on Render and all 12 Supabase migrations are applied. Full
application release acceptance remains open in the project status.

## Current Render deployment

- API URL is `https://homecircle-api.onrender.com`.
- Service is `homecircle-api`, ID `srv-dbt235gae00c739ei3vg`, Render Free, Singapore.
- The HomeCircle Blueprint uses the root `render.yaml` from the public GitHub repo.
- Python 3.13.17 installs `backend/requirements.lock`. Uvicorn runs the existing
  application factory and Psycopg-compatible loop on Render's `$PORT`.
- Health checks use `/ready`. Deployment verification observed health/readiness 200,
  unauthenticated profile 401 and production docs/schema 404.
- Private environment settings contain the restricted database URL and existing
  invitation pepper, copied with the user's approval. Preserve that pepper across
  deployments so issued invitation codes remain usable.
- Service auto-deploy is off. Trigger a manual deploy for application updates.
  Blueprint configuration synchronization is managed separately by Render.

Render Free sleeps after 15 minutes without traffic and can take about a minute to
wake. The mobile HTTP timeout can expire during that initial wakeup, requiring a
retry once the service is ready. Always-on compute requires a separate plan choice.
[Render Free behavior](https://render.com/docs/free)

To recreate the service, use New Blueprint Instance in Render, provide the public
HomeCircle repository URL, select `main` and the root `render.yaml`, and fill the four
prompted environment values from the local backend configuration. The API uses the
existing Supabase database. The notification worker requires its separate Firebase
credentials and hosting configuration before FCM delivery can operate.

The user's 16 November migration authorization applied inventory access, tasks,
shopping, chat and household hub versions. The initial inventory-access attempt
encountered an already existing actor-name function. Its pending migration now uses
`CREATE OR REPLACE FUNCTION` with the existing signature. The retry completed, and
the CLI reports no pending versions. Migration history and catalog checks were read
through the authenticated Supabase CLI. Write-capable integration tests remain
deferred at the user's request.

## Reproduce the environment

Tested with Python 3.13.17, Flutter 3.47.9 stable, Dart 3.13.7, Temurin JDK 21.0.13,
Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0 and Android build-tools 36.0.0. APK inspection
reports min SDK 24, target/compile SDK 36. The available emulator runs API 37.
Use repository lock files. Generated SDK paths and local private configuration stay
outside version control.

```powershell
# From backend. Recreate the venv only if its interpreter is unusable.
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.lock
.\.venv\Scripts\python.exe -m pip check
.\.venv\Scripts\python.exe -m ruff check app tests
.\.venv\Scripts\python.exe -m ruff format --check app tests
.\.venv\Scripts\python.exe -m pytest -q
# From mobile.
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

## Disposable database acceptance

Create a separate disposable Supabase project, configure its direct/session connection
over verified TLS, and apply all 12 repository migrations in filename order using the
Supabase CLI. Confirm the project reference against the app project before every CLI
operation. Read the proposed migration plan before applying it. Never reset the app
project to run tests.

Set `HOMECIRCLE_TEST_DB=hosted-test`, `HOMECIRCLE_TEST_PROJECT_REF`,
`SUPABASE_TEST_DATABASE_URL` and, when required,
`SUPABASE_TEST_DATABASE_SSLROOTCERT` locally. The existing test-target validator
rejects a matching app project or production environment before write-capable tests.
Use credentials capable of creating generated test users and exercising restricted
roles only in that disposable project. Most tests roll back. Concurrency cases commit
generated fixtures and attempt cleanup, so the project must remain disposable.

Run `python -m pytest -m integration -q` from backend. Confirm there are no skips.
Inspect the five-user inventory matrix, member/admin restrictions, cross-household
foreign keys, recipient ownership, stale revisions, stock ledgers, rollback and
concurrency results. Run two signed-in clients for Storage uploads/downloads/private
Realtime, active revocation and flows A–F. Retain sanitized results and migration
history. Unit tests and parser checks alone cannot establish hosted RLS behavior.

## API deployment

1. Configure a process supervisor/container with the locked backend runtime
   dependencies, the `backend` working directory and a restricted writable temp area.
2. Provide `APP_ENV=production`, the restricted `homecircle_api` direct/session DSN,
   `DATABASE_SSLMODE=verify-full`, the appropriate public CA trust file, Supabase
   origin/JWT settings and a stable random invitation pepper of at least 32 characters.
   Retain private values in deployment secret storage.
3. Configure exact trusted browser CORS origins. Native Android traffic does not
   require browser CORS. Place the API behind an HTTPS reverse proxy with verified
   upstream trust, bounded request concurrency, ordinary request rate limits and
   upload-aware body limits. Preserve `Authorization` without logging its contents.
   Accept forwarded headers only from the trusted proxy addresses.
4. Start `python -m uvicorn app.main:create_app --factory
   --loop app.core.event_loop:create_event_loop --host 0.0.0.0 --port 8000`.
   Set worker count and pool size together against the database connection budget.
   Startup rejects a privileged database role. Production docs/schema are disabled.
5. Probe `/health` for process liveness and `/ready` for database readiness. A failing
   readiness probe returns sanitized 503 and must remove that replica from routing.
   It checks connection/query availability. Storage, Auth and FCM need separate
   external synthetic acceptance checks.
6. Default API pool settings bound checkout/connect to 10 seconds, statements to
   15 seconds, lock waits to 5 seconds and idle transactions to 30 seconds. Tune
   `DATABASE_STATEMENT_TIMEOUT_MS`, `DATABASE_LOCK_TIMEOUT_MS` and
   `DATABASE_IDLE_TRANSACTION_TIMEOUT_MS` with measured test workloads. Verify session
   pooler support for startup options before promotion. Photo JSON is bounded to
   8 MiB and other writes to 64 KiB before parsing.

TLS/proxy configuration follows FastAPI's deployment documentation.
[HTTPS deployment](https://fastapi.tiangolo.com/deployment/https/),
[Trusted proxy setup](https://fastapi.tiangolo.com/advanced/behind-a-proxy/)

Supabase documents session-level timeouts for direct/session connections. Validate
the effective values on the intended pooler during disposable-project acceptance.
[Supabase database timeouts](https://supabase.com/docs/guides/database/postgres/timeouts)

## Workers, Storage and Realtime

Provision `homecircle_worker` separately using the reviewed migration's narrow
permissions. Supply `NOTIFICATION_WORKER_DATABASE_URL`, `FIREBASE_PROJECT_ID` and
Application Default Credentials through workload identity or an external private
file. Supervise `python -m app.workers.notifications` independently of the API.
Use `--once` for controlled test batches. Verify lease expiry, stale acknowledgement,
retry exhaustion, revoked devices and invalid-target cleanup in the disposable project.

Configure the intended Firebase Android project for the confirmed application ID.
Provide ignored `mobile/android/app/google-services.json` and confirm FCM delivery on
two devices. Configure Supabase Auth callback allow-list for
`com.homecircle.homecircle://auth-callback` and test confirmation/recovery flows.

Verify buckets remain private and policies reference current household membership.
M5 chat outbox needs its reviewed Supabase Cron retry configuration and private
recipient-scoped Realtime channels. Inspect queue age and acknowledgement behavior.
Retry cleanup of finalized unreferenced Storage objects through the Storage API
after the approved retention period. Preserve active/in-flight upload references.

## Promotion, backup and rollback

Before approved production migration, capture migration history, schema/grants and
restricted-role diagnostics. Confirm a recoverable database backup and a separate
Storage-object backup/retention plan. Perform a restore drill in a separate project,
including Auth references, private objects, task/stock ledgers and notification jobs.
Database backups alone do not establish object-byte recoverability.

Apply reviewed forward-only migrations during an approved change window. M7 adds
no migration. Compare applied versions to repository filenames and verify RLS,
grants, function search paths, private buckets and restricted login startup. Run
authorized smoke tests with designated test accounts, then increase traffic gradually.
Retain the previous application image and compatible mobile release.

On a regression, stop promotion and roll back application traffic to the last
compatible image. Pause affected worker processing to prevent repeated side effects.
Preserve logs, queue identities and deduplication ledgers. Repair schema/data through
reviewed forward migrations. Restore backups only through the approved recovery
procedure after assessing newer committed data and Storage references. Avoid blind
schema resets and ledger deletion.

Monitor readiness failures, HTTP 401/403/409/429/5xx rates, pool checkout/statement
timeouts, lock waits, latency percentiles, queue age/retries, invalid tokens and
Storage cleanup failures. Keep credentials, JWTs, request bodies, device targets,
signed URLs and message contents out of logs. Redact identifiers in exported QA
evidence. Test secret rotation, worker restarts and alert delivery before production.

[Release checklist](ANDROID_RELEASE_CHECKLIST.md) · [Known issues](KNOWN_ISSUES.md)
