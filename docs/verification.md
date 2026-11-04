# Implementation and verification report

Initial verification: 4 November 2026. Hosted HomeCircle setup and integration checks: 5 November 2026. Both foundation migrations are applied to project `rsezpwxhjecwienchdfm`. Ignored local configuration contains the public client settings and a generated restricted backend login; the app does not use the administrator login.

## Implemented foundation

The Android-first Flutter/iOS monorepo has feature-first MVVM with Provider/ChangeNotifier, a reusable tested `http` client, guarded GoRouter navigation, Material 3 HomeCircle theme, generated English localization and reusable components. Supabase Auth integration covers signup/login/logout, session restoration/refresh and password recovery. Active household selection is validated against membership and the protected household-detail API, stored as a preference and isolated across switching/logout. Small cache/draft storage and private realtime lifecycle boundaries are prepared.

FastAPI provides the six requested endpoints with Pydantic validation, generic safe error envelopes, verified Supabase JWT identity and a lifecycle-managed async Psycopg pool. SQL migrations define profiles, households, memberships, constraints, indexes, RLS, profile creation, atomic household creation, admin-only membership RPCs and last-admin protections. Reserved storage buckets are private and client writes are disabled.

The full feature screens and Stitch designs have not been implemented. The [root README](../README.md) shows the important directory/file structure and exact startup/check commands.

## Actual local versions

| Technology | Version |
| --- | --- |
| Flutter / Dart | 3.47.9 stable / 3.13.7 |
| Python | 3.13.17 |
| Provider | 6.1.5+1 |
| Dart `http` | 1.6.0 |
| GoRouter | 18.1.2 |
| Supabase Flutter | 2.18.3 |
| SharedPreferences | 2.5.6 |
| Flutter Secure Storage | 11.2.0 |
| Intl | 0.20.3 |
| FastAPI / Starlette | 0.162.0 / 1.10.0 |
| Pydantic / Pydantic Settings | 2.14.2 / 2.16.2 |
| Psycopg / Psycopg Pool | 3.3.7 / 3.3.3 |
| Uvicorn | 0.54.0 |
| PyJWT / Cryptography | 2.15.1 / 50.0.2 |
| pytest / pytest-asyncio | 9.2.0 / 1.4.1.post1 |
| httpx / Ruff | 0.28.1 / 0.17.3 |
| JDK / Gradle | 21.0.13.9 / 9.3.1 |
| Android Gradle plugin / Kotlin plugin | 9.1.0 / 2.4.0 |
| PostgreSQL | 17.11, verified on hosted HomeCircle |
| Supabase CLI | 3.0.0, pinned npm CLI used for hosted migration preview and apply |

`mobile/pubspec.lock` and `backend/requirements*.lock` record exact dependency versions. Python's supported range is 3.12–3.14; only 3.13.17 was exercised here.

## Checks and results

| Command | Result |
| --- | --- |
| `flutter pub get` | Passed; localization generated |
| `dart format lib test` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test --dart-define=LIVE_API_BASE_URL=http://127.0.0.1:8000` | 21 passed, including two real API client checks |
| `flutter build apk --debug --dart-define-from-file=config.local.json` | Passed; configured 208,087,476-byte debug APK |
| Emulator install and launch | Passed on Pixel 4 / Android 17; configured Welcome screen visually checked with no app runtime errors |
| Backend dependency installation | Passed in project `.venv` |
| `ruff check app tests` | Passed |
| `ruff format --check app tests` | Passed |
| `pytest -q` | 50 passed, 8 separate-project database tests skipped |
| `pip check` | No broken requirements |
| Hosted migration preview/apply | Both migrations applied using Supabase CLI with verified TLS |
| Hosted schema inspection | Three tables with RLS enabled; four private buckets; direct authenticated membership writes denied |
| Restricted database login | `homecircle_api` verified through the session pooler; no household rows visible without user context |
| Real FastAPI pool lifecycle | Startup, restricted identity check and shutdown/connection-pool close verified |
| Running API health | `/health` and `/api/v1/health`: HTTP 200 |
| Running API authentication failures | `/api/v1/me`: HTTP 401 for missing, malformed and forged ES256 tokens |

The skipped tests require a separate hosted Supabase test project and cover RLS behavior with test records, self-promotion denial, multi-household access, last-admin restrictions, atomic creation rollback and storage privacy. They were not run against the app project. Read-only live checks verified deployed policies/grants and storage settings without creating users or households. Unit tests cover API, crypto, dependencies and transaction boundaries. Flutter's two optional live tests exercised the real API client against health and a real 401 response; they are skipped without `LIVE_API_BASE_URL`. Other Flutter tests use mocked Auth/HTTP. Starlette emits one upstream TestClient deprecation warning for the mandated httpx test stack.

Live startup exposed Uvicorn's default Proactor loop incompatibility with async Psycopg on Windows. The documented explicit `app.core.event_loop:create_event_loop` factory fixes that before app startup, and a regression test verifies Uvicorn selects it. Auth HTTPS uses verified OS certificate trust. Database TLS verifies both the Supabase CA and pooler hostname with `sslmode=verify-full`.

The administrator and generated application passwords were checked against all publishable Git source paths; neither was present. Temporary administrator/password copies were removed after configuration. The backend credential remains only in ignored `backend/.env`; mobile configuration contains only public values. Rotate the administrator password shared during setup through the Supabase Dashboard.

The configured APK is at `mobile/build/app/outputs/flutter-apk/app-debug.apk`. It was installed with `adb -s emulator-5554 install -r`, launched with `am start -n com.homecircle.homecircle/.MainActivity` and checked for app-specific Flutter/Android runtime errors (none found). It reached the [Welcome screen](images/android-welcome.png) with the real public project configuration. The earlier build without configuration rendered the intended [development setup screen](images/android-configuration.png). The emulator was stopped after verification. The APK uses `http://10.0.2.2:8000` for a host-running API; use the physical-device configuration described in setup when building for a phone.

The build required a task-local trust store because antivirus HTTPS scanning uses a Windows-trusted root absent from Java's default store. The Gradle distribution was verified against its official SHA-256 checksum. TLS verification remains enabled, and system trust settings were not modified. Kotlin incremental compilation is disabled because the project and Pub cache are on different Windows drives. The configured APK rebuild took 117.4 seconds. Initial attempts exposed the TLS and cross-drive cache issues documented in setup; the corrected builds succeeded.

## Manual configuration and remaining verification

1. Completed: hosted project, verified public key, email provider enabled, ES256 signing mode/issuer configured, two SQL migrations applied, restricted database credential generated, and local backend/mobile configuration saved.
2. In Supabase Authentication → URL Configuration, allow `com.homecircle.homecircle://auth-callback`. Dashboard configuration still requires the project's management access; the current Supabase connector is scoped to another project.
3. Create/sign in to a real user account and validate email confirmation/recovery, session renewal, authenticated `/api/v1/me`, household creation and two-user isolation. No test accounts or household data were inserted into the app project during these checks.
4. Run the eight database behavior tests against a separate hosted test project.
5. Validate Python-host deployment and the iOS build; configure release signing before distribution. FCM setup belongs to the later notification milestone.

Do not paste private credentials into chat. Full sign-in/session behavior, the record-based isolation suite, Python-host deployment and iOS remain unverified. Hosted HomeCircle changes used the explicitly targeted CLI database connection; the other project's connector was not used for mutations. Feature-specific offline cache readers/draft forms, uploads, realtime event subscriptions and invitation/join behavior remain deferred. Milestone 1 has not been started.

## Hosted workflow update — 5 November 2026

The project now targets hosted Supabase throughout. Docker deployment files, local database ports/service settings and the local seed file were removed. Migration deployment uses the linked hosted project. Integration tests target a separate hosted test project, with project-identity and TLS checks before connecting. FastAPI can run directly in Python during development and deployment.
