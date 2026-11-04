# HomeCircle

Everything your home needs, in one place.

Milestone 0 establishes an Android-first Flutter app, FastAPI API, and Supabase SQL foundation for a household manager. It includes minimal functional authentication and household onboarding, plus placeholders for later feature screens. The Stitch screens and full product features are outside this milestone.

## Structure and architecture

```text
mobile/
  android/, ios/             Flutter-generated platform projects
  lib/main.dart, app.dart    Bootstrap and Provider composition
  lib/core/                 Config, HTTP, guards, theme, localization, local storage
  lib/features/auth/        Views → ChangeNotifier → repository → Supabase Auth
  lib/features/household/   Validated membership and active household lifecycle
  lib/features/dashboard/  Foundation screens and API connection diagnostics
  lib/shared/widgets/      Future-screen placeholder
  test/                    HTTP, routing, session, ViewModel and widget tests
backend/
  app/api/                  Thin versioned FastAPI routers
  app/services/             Business logic and authorization coordination
  app/repositories/         Parameterized async Psycopg SQL
  app/db/                   Lifespan pool and transaction-local verified identity
  app/core/                 Settings, JWT verification and safe errors
  tests/                    Unit tests and opt-in hosted test-project checks
  requirements*.lock        Exact installed dependency versions
supabase/
  migrations/               Tables, RLS, guarded RPCs, private storage buckets
  config.toml               CLI metadata for hosted migration deployment
docs/                       Setup, architecture, environment, security, milestones
```

Flutter uses feature-first MVVM, Provider, ChangeNotifier, `http`, GoRouter, the Supabase Flutter SDK and official Flutter localization. The API uses Pydantic v2, FastAPI, Psycopg 3 async connections and `psycopg_pool`. No ORM or additional use-case layer is used. Future inventory, tasks, shopping, chat, notification and profile implementations get feature folders when they contain code; their named placeholder routes already exist.

## Prerequisites

- Flutter stable 3.47.9 / Dart 3.13.7 (versions used here), Android SDK and emulator, JDK 21.
- Python 3.12–3.14; this workspace uses Python 3.13.17.
- A hosted Supabase project and Supabase CLI for remote SQL migrations.
- Xcode and macOS when validating iOS later.

See [setup](docs/setup.md) for Supabase migrations, restricted login provisioning, auth redirects, Android networking, and troubleshooting. See [environment](docs/environment.md) for all settings. Configure private credentials in local files or a deployment secret manager, never in chat or source control.

Supabase hosts PostgreSQL, Auth, Storage and Realtime. FastAPI runs as a Python service and connects to hosted PostgreSQL. The development workflow uses no Docker or local database server.

## Quick start

From the repository root, using PowerShell:

```powershell
python -m venv backend/.venv
cd backend
.venv/Scripts/python -m pip install -r requirements-dev.lock
.venv/Scripts/python -m pip install --no-deps -e .
Copy-Item .env.example .env
# Configure .env locally after applying the Supabase migrations.
.venv/Scripts/python -m uvicorn app.main:create_app --factory --loop app.core.event_loop:create_event_loop --reload --host 0.0.0.0 --no-access-log
```

On macOS/Linux use `.venv/bin/python` instead of `.venv/Scripts/python`. Do not run the API against a privileged `postgres` or service-role database connection: startup rejects it. Database configuration is required even for the running service's health endpoints; isolated unit tests override external dependencies.

In another terminal:

```powershell
cd mobile
flutter pub get
Copy-Item config.example.json config.local.json
# Configure the public Supabase URL/key and API URL locally.
flutter emulators
flutter emulators --launch YOUR_EMULATOR_ID
flutter run -d YOUR_ANDROID_DEVICE_ID --dart-define-from-file=config.local.json
```

Android emulator → host API: `http://10.0.2.2:8000`. For a physical device, prefer `adb reverse tcp:8000 tcp:8000` and `http://127.0.0.1:8000`, or a trusted HTTPS development endpoint. Debug-only HTTP exceptions cover loopback and the emulator host; release builds require HTTPS. With no public configuration, the app displays a development setup screen.

## Checks

```powershell
cd backend
.venv/Scripts/ruff check app tests
.venv/Scripts/ruff format --check app tests
.venv/Scripts/python -m pytest -q
.venv/Scripts/python -m pip check
cd ../mobile
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

With the API running, include the two read-only live client checks with `flutter test --dart-define=LIVE_API_BASE_URL=http://127.0.0.1:8000` from `mobile/`. Without that define they are skipped, so normal unit tests require no running service.

The thirteen real-database tests are optional and require a separate hosted Supabase test project with migrations applied. They check the declared project identity, refuse the app project's database and isolate test data. Most roll back; concurrency cases commit generated fixture IDs and clean up only those IDs:

```powershell
# Configure the test connection securely in your environment.
$env:HOMECIRCLE_TEST_DB = 'hosted-test'
$env:HOMECIRCLE_TEST_PROJECT_REF = 'YOUR_SEPARATE_TEST_PROJECT_REF'
$env:SUPABASE_URL = 'https://YOUR_APP_PROJECT_REF.supabase.co'
# SUPABASE_TEST_DATABASE_URL must be the test project's admin connection.
cd backend
.venv/Scripts/python -m pytest -m integration -q
```

Use the checked-in `pubspec.lock` and Python locks for repeatable installations. `pyproject.toml` records supported dependency ranges; deliberately update and regenerate locks together when upgrading.

## API

| Endpoint | Access | Purpose |
| --- | --- | --- |
| `GET /health` | Public | `{"status":"ok"}` |
| `GET /api/v1/health` | Public | API availability/version |
| `GET /api/v1/me` | Verified bearer | Own profile and memberships |
| `GET /api/v1/households` | Verified bearer | Own households only |
| `POST /api/v1/households` | Verified bearer | Household + first admin atomically |
| `GET /api/v1/households/{id}` | Verified member | Household detail |

Errors use `{"error":{"code":"...","message":"..."}}`. Request validation returns 422 without echoing input. Missing/invalid tokens return 401 with a Bearer challenge. An absent or inaccessible household returns 404; invalid access does not reveal whether another household exists. Internal failures return a generic 500. Auth key discovery outages return 503. Successful create returns 201. Interactive API docs are at `/docs` outside production.

Read [security](docs/security.md) before extending the API, [architecture](docs/architecture.md) before implementing new features, and [milestones](docs/milestones.md) for verification status. See the [Milestone 1 report](docs/milestone-1-report.md) for the implemented authentication and household flows and external acceptance checks.

See the [verification report](docs/verification.md) for actual dependency versions, command results, Android emulator evidence, and the remaining external setup checklist.

## Milestone 1

Authentication, verification/recovery, profile editing, household create/join/switching, members, admin settings and secure invitation management are implemented. Hosted migrations are applied. See the [implementation and verification report](docs/milestone-1-report.md) for API permissions, exact test results and the remaining real-email/separate-test-project acceptance checks. Milestone 2 has not started.
