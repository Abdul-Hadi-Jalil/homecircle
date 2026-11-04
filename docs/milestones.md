# Milestone 1 current status

Implementation is complete. See [the Milestone 1 report](milestone-1-report.md) for current validation and pending external acceptance. The record below describes the earlier Milestone 0 snapshot.

# Milestone status

Milestone 0 contains the implementation foundation. External integration and platform verification are recorded separately; an implemented file is not evidence that a hosted service works.

## Verified

- Flutter 3.47.9 stable / Dart 3.13.7 generated Android and iOS projects.
- Android debug APK rebuilt with the real public project configuration and launched on Pixel 4 (Android 17). The Welcome screen rendered without app-specific Flutter/Android runtime errors. The missing-config development screen was also checked in the earlier build. Signed-in flows remain pending a real user account.
- Provider/MVVM composition, Material 3 theme and generated English localization.
- Named GoRouter routes, auth/household/admin guards and five permanent tabs.
- Auth service/repository integration code with secure SDK session and PKCE storage.
- Reusable HTTP client with bearer injection, JSON validation, all five verbs, timeouts and typed errors.
- Multi-household restoration, switching, stale-response rejection, revocation cleanup, scoped cache/draft APIs and logout cleanup in unit/widget tests.
- Python 3.13.17 dependency installation; FastAPI/Pydantic configuration and layered endpoints.
- Real asymmetric signature verification tests, legacy-mode tests, invalid token/claims rejection and protected dependency behavior.
- Pool lifecycle/role checks and transaction-local identity/rollback tests using isolated fakes.
- `flutter analyze`: clean. Flutter suite with `LIVE_API_BASE_URL`: 21 passed, including real health and unauthorized API responses.
- Ruff lint/format: clean. `pytest`: 50 passed, eight separate-project database tests skipped. The installed Starlette emits an upstream deprecation warning for its httpx-backed TestClient; tests still use the requested httpx stack.
- Both foundation migrations applied to hosted HomeCircle (PostgreSQL 17.11) with Supabase CLI 3.0.0 and verified TLS.
- Three live tables have RLS enabled; four buckets are private; authenticated clients have no direct membership-write privileges.
- Restricted `homecircle_api` pooler login, actual FastAPI pool startup/close, HTTP 200 health responses and HTTP 401 rejection of missing/malformed/forged tokens.

## Implemented; external verification pending

- The migrated SQL is deployed. Record-based isolation, self-promotion denial, last-admin protections and atomic rollback behavior still require the separate hosted test project.
- Private reserved storage buckets and membership-scoped read policy. Uploads are intentionally denied; no full upload feature exists yet.
- Real signup/login/logout, email confirmation/recovery deep links, session refresh and `/api/v1/me` against configured Supabase/FastAPI.
- Python-host deployment and iOS build/run (requires macOS/Xcode).

## Acceptance checklist

| Area | Status |
| --- | --- |
| Theme, Provider, MVVM, reusable HTTP, routing, localization | Implemented; analyzer and unit/widget tests pass |
| Auth-dependent navigation and active household isolation | Verified with isolated fake Auth and HTTP responses |
| Android emulator run | Configured Welcome screen verified on Pixel 4 / Android 17; real signed-in flow pending |
| FastAPI routes, safe errors, settings, JWT verification | API and crypto tests pass without production dependencies |
| Pool initialization and shutdown | Verified with the real hosted restricted login and explicit Selector loop |
| RLS, privileges, atomic creation and multi-household SQL | Migrations deployed; catalog/grants checked; record-based behavior suite pending separate test project |
| Mobile-to-real-API health and authenticated `/me` | Real Flutter client health/401 checks pass; valid signed-in `/me` awaits a real account |
| Missing config behavior | Mobile widget test and backend settings tests pass |
| Server secrets in mobile | None supplied; public config validator rejects server key formats |

## Historical handoff into Milestone 1

After configuring development services and passing the remaining integration checks, the project is ready for the first product UI milestone: apply approved Stitch designs to authentication and household onboarding, including reviewed invitation/join behavior. Reuse the theme, localized strings, repositories, session scope and route guards. Add real integration coverage for two users and multiple households before expanding shared records.

Inventory, shopping, task CRUD, full chat/discussions, notifications/FCM, uploads, activity history, durable structured caches and sync are later milestones. Feature forms should use the scoped draft abstraction when implemented. No offline mutation synchronization is planned for version 1. Milestone 1 was subsequently implemented at the user’s request; see the current report above.
