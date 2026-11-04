# Environment configuration

## Backend `.env`

Copy `backend/.env.example` to `backend/.env`; run the API from `backend/`. Pydantic Settings also reads process environment variables. Missing required settings cause startup validation to fail. Environment input is hidden from configuration exception messages.

| Variable | Purpose / default |
| --- | --- |
| `APP_ENV` | `development`, `test`, `production`; default development |
| `APP_NAME` | Public API title |
| `DATABASE_URL` | Required restricted `homecircle_api` direct/session connection; private |
| `DATABASE_SSLMODE` | `verify-full` default; mandatory in production |
| `DATABASE_SSLROOTCERT` | Example uses `certs/supabase-root-2021.pem`; public Supabase CA, relative to backend working directory |
| `DATABASE_POOL_MIN` / `DATABASE_POOL_MAX` | 1 / 5; size per API worker |
| `DATABASE_POOL_TIMEOUT` | Pool checkout timeout, 10 seconds |
| `DATABASE_CONNECT_TIMEOUT` | Startup/connect timeout, 10 seconds |
| `SUPABASE_URL` | Required hosted project HTTPS base URL |
| `SUPABASE_PUBLISHABLE_KEY` | Optional public key reserved for future server Auth calls; JWKS verification does not need it |
| `SUPABASE_JWT_ISSUER` | Defaults to `<SUPABASE_URL>/auth/v1`; match project issuer exactly |
| `SUPABASE_JWT_AUDIENCE` | `authenticated`; match project's user access tokens |
| `SUPABASE_JWT_MODE` | `jwks` (ES256/RS256) or explicit `legacy_hs256` |
| `SUPABASE_JWT_SECRET` | Server-only legacy HS256 signing secret; required only for legacy mode, at least 32 bytes |
| `INVITATION_PEPPER` | Server-only stable random secret, at least 32 characters; required for invitation operations |
| `INVITATION_EXPIRY_DAYS` | Default 7; range 1–30; new codes only |
| `INVITATION_MAX_USES` | Default 10; range 1–1000; new codes only |
| `CORS_ALLOWED_ORIGINS` | JSON list, default `[]`; native clients do not require CORS |

For hosted Supabase select the direct database hostname when IPv6 is available, otherwise the session pooler on port 5432. The pooler user is typically `homecircle_api.<project_ref>`; the actual `current_user` must still be `homecircle_api`. Retrieve the project-specific connection details from its Connect panel. URL-encode password special characters. Never use the transaction pooler (6543). Set the pool budget across all worker replicas against the project's connection limit.

Use `DATABASE_SSLMODE=verify-full` for hosted Supabase and provide the project's TLS root certificate path when needed. Never disable certificate verification to work around a remote connection issue. No local database connection is required.

JWKS mode caches public keys for five minutes and fails closed on unknown keys until expiry. Supabase may also cache its JWKS endpoint; wait for caches to expire during planned rotation. Restart API workers to clear the application cache during urgent revocation, following the project's incident process. In legacy mode, store the real JWT secret in a server secret manager; it is not the anon/publishable key and never belongs in mobile config. A project rotating between symmetric/asymmetric modes needs coordinated backend configuration changes; this implementation does not silently accept both.

## Mobile public compile-time configuration

Copy `mobile/config.example.json` to ignored `mobile/config.local.json`. Set `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and pass `--dart-define-from-file=config.local.json` to run/build. Individual `--dart-define=KEY=VALUE` flags also work. Values compiled into a mobile binary are public. The validator rejects server secret keys and legacy service-role JWTs. Use a real publishable key or legacy anon key.

Android emulator uses `10.0.2.2` for the host computer, not its own localhost. The debug network security policy permits cleartext only to `10.0.2.2`, `127.0.0.1` and `localhost`. Use USB `adb reverse` or trusted HTTPS for physical devices. No HTTP exception ships in release builds and no TLS verification is disabled.

Supabase manages the session token lifecycle. `SecureAuthStorage` persists its serialized session in the platform vault, and `SecurePkceStorage` keeps PKCE verifiers there too. Preferences contain no auth credentials. Supabase URL/key changes require rebuilding the app; secure sessions are namespaced by project host.

Firebase config and server push credentials are not required in M0. Supply them locally in the later notification milestone, with server credentials restricted to the backend secret manager.
