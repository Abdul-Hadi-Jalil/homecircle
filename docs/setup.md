# Development setup with hosted Supabase

## Supabase

Use a hosted Supabase project. PostgreSQL, Auth, Storage and Realtime run on Supabase; FastAPI runs as a Python service on your computer during development. No Docker or local database installation is needed. No hosted project has been modified by this implementation.

1. Create/select the HomeCircle project in the Supabase Dashboard and install the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) for remote migration commands.
2. From the repository root, authenticate and link the intended project, preview the pending SQL, then apply it using the commands below. Keep migration credentials distinct from the running API's login. The minimal `supabase/config.toml` tracks CLI migration settings; hosted service settings are configured in the Dashboard.
3. Set a strong unique password for the `homecircle_api` login using a secure SQL administration session or interactive `psql` `\password homecircle_api`. Do not put that password into a migration, terminal history or chat. The migration deliberately creates no committed password. The running API role must not own tables or inherit privileged roles.
4. Select the project's direct or session-pooler connection and use the custom role in `backend/.env`, on port 5432. Confirm IPv4/IPv6 support and provision the project's TLS root certificate if needed. Keep `DATABASE_SSLMODE=verify-full`.
5. In the hosted Auth settings, enable email/password, configure confirmation/email delivery, and allow `com.homecircle.homecircle://auth-callback` in URL Configuration. Use verified app/universal links and project-specific application IDs in the release hardening milestone.
6. Check the project's JWT signing settings. For asymmetric ES256/RS256 keys use `SUPABASE_JWT_MODE=jwks`. For legacy HS256 configure `legacy_hs256` and the server-only secret locally. Match issuer and audience exactly.
7. The migrations install profile creation/backfill, household/membership RLS, atomic/admin RPCs and private reserved buckets. Registration through Supabase Auth creates profiles. Create households through the API/app; no seed data is required.
8. Keep public Realtime access disabled before introducing private channels. M0 has no live subscriptions or publication changes. FCM registration, notification permissions and push credentials are deferred.

```powershell
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push --linked --dry-run
supabase db push --linked
```

The thirteen optional database tests use a separate hosted Supabase test project with the same migrations. Set `HOMECIRCLE_TEST_DB=hosted-test`, `HOMECIRCLE_TEST_PROJECT_REF` to its project ref, `SUPABASE_URL` to the app project's standard HTTPS URL, and `SUPABASE_TEST_DATABASE_URL` to the test project's admin direct/session connection. If needed, set `SUPABASE_TEST_DATABASE_SSLROOTCERT` to its TLS root certificate path. Run `pytest -m integration`. The guard checks project identity, verified TLS and port 5432, and rejects the app project and production application mode. Most tests roll back their transactions, including temporary test triggers. Concurrency tests commit generated fixture IDs and delete those exact IDs afterward; they never reset or drop a database. Unit tests need no database connection or hosted credentials.

## Backend

From the repository root:

```powershell
python -m venv backend/.venv
cd backend
.venv/Scripts/python -m pip install -r requirements-dev.lock
.venv/Scripts/python -m pip install --no-deps -e .
Copy-Item .env.example .env
# Edit .env locally with the development configuration.
.venv/Scripts/python -m uvicorn app.main:create_app --factory --loop app.core.event_loop:create_event_loop --reload --host 0.0.0.0 --port 8000 --no-access-log
```

On Unix use `.venv/bin/python`. The entry point is a factory, so `--factory` is required. Keep the explicit `--loop app.core.event_loop:create_event_loop`: it selects the Selector loop required by async Psycopg on Windows before Uvicorn starts running the app. Setting a global policy during app import happens too late in current Uvicorn. The pool opens during startup and must connect using `homecircle_api`; an unavailable database or wrong role fails startup rather than serving partially initialized endpoints. `GET /health` is a process availability endpoint after successful startup, not a continuous database readiness probe. `backend/certs/supabase-root-2021.pem` contains Supabase's public database CA; the example environment points to it for verified TLS.

Check `http://127.0.0.1:8000/health` and development API docs at `/docs`. `GET /api/v1/me` requires a real Supabase user access token; the publishable key alone does not authenticate a user. Avoid pasting tokens into shell history or logs. The mobile Home screen has public-health and authenticated-profile connection actions.

For deployment, use a Python application host: install `backend/requirements.lock`, deploy `backend/app` and `backend/certs`, inject environment settings through the host's secret manager, and run `python -m uvicorn app.main:create_app --factory --loop app.core.event_loop:create_event_loop --host 0.0.0.0 --port 8000 --no-access-log` from `backend/`. Configure the port to match the host's requirements. Supabase supplies the managed database and platform services; the FastAPI process runs on your chosen Python host. Use HTTPS and request rate limits for a public API.

## Android

```powershell
flutter doctor -v
flutter emulators
cd mobile
flutter pub get
Copy-Item config.example.json config.local.json
# Set only public values in config.local.json.
flutter emulators --launch YOUR_EMULATOR_ID
flutter devices
flutter run -d YOUR_EMULATOR_DEVICE_ID --dart-define-from-file=config.local.json
```

Use the hosted `https://YOUR_PROJECT_REF.supabase.co` URL and public key in both application configurations. For FastAPI running on your computer, use `API_BASE_URL=http://10.0.2.2:8000` on Android's standard emulator. A physical USB-connected device can run `adb -s DEVICE_ID reverse tcp:8000 tcp:8000` and use `http://127.0.0.1:8000`. For a deployed API, use its trusted HTTPS URL. Native API requests do not need CORS origins.

Only debug builds allow HTTP to the emulator gateway/loopback. The release manifest denies cleartext, and Supabase/API URLs should be HTTPS in releases. The native manifests disable the Flutter built-in deep-link handler so Supabase can handle the registered auth callback. The callback registration is also present for iOS, whose build/run still needs macOS/Xcode. Supply proper Android/iOS release signing before distributing the app; Android release signing is deliberately unconfigured.

Without configuration, run `flutter run` to verify the development configuration screen. Unit/widget tests do not initialize a production Supabase connection.

## Troubleshooting

- Missing configuration: inspect local `.env` and compile-time config. Restart the API/rebuild the app after changes. The app never prints raw initialization exceptions.
- Emulator connection refused: use `10.0.2.2`, make the backend listen on `0.0.0.0`, and check the computer's firewall. Device localhost is not the computer's localhost unless using `adb reverse`.
- API rejects database identity: provision/use the exact restricted `homecircle_api` login; do not substitute `postgres` to bypass the check.
- API 401: verify that the bearer is a current user access token, and check signing mode, issuer, audience and key rotation. Auth discovery failure returns 503, not a fabricated authenticated session.
- Household access cannot be verified: reconnect and retry. Stale cached memberships cannot authorize routes. A user with multiple memberships must select one.
- Signup profile trigger failure: confirm migrations were applied by their owner and use Auth signup. Display-name metadata is bounded; never add roles to metadata-based authorization.
- Account deletion blocked: transfer household administration or delete administered households first. The last-admin guard deliberately prevents orphaning.
- Gradle `PKIX path building failed`: this machine's antivirus scans HTTPS using a Windows-trusted private root that the JDK may not trust. Configure a task-local Java trust store containing the administrator-approved Windows root, keeping TLS checks enabled. Do not disable verification or change global trust without deliberate administration. The ignored `.tmp` trust store used for local verification is machine-specific and is not part of the project.
- Kotlin "different roots" cache errors: the project is on `A:` while the Pub cache is on `C:`. `android/gradle.properties` disables Kotlin incremental compilation for this layout. It can be re-enabled after placing both on the same drive and clearing the affected generated build caches.
- Windows Python test execution may need permission outside the restricted Codex process sandbox. This is separate from application behavior.
- iOS plugin/secure-storage configuration: validate with Xcode and apply the selected `flutter_secure_storage` version's platform requirements before iOS distribution.

Primary references: [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup), [Supabase CLI remote migration reference](https://supabase.com/docs/reference/cli/supabase-db-push), [Supabase database connections](https://supabase.com/docs/guides/database/connecting-to-postgres).

## Milestone 1 setup

The [Milestone 1 report](milestone-1-report.md#manual-setup-and-external-acceptance) covers Auth callbacks/email templates, the server invitation pepper, separate-project integration tests and device acceptance. Apply all migrations in order; the final profile actor helper supports hosted Auth schema ownership while retaining the API role’s NOINHERIT setting. No broad role inheritance is required.
