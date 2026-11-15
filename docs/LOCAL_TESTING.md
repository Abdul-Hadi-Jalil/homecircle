# Local Supabase testing

Use a dedicated local Supabase stack for disposable test accounts and data. This
setup uses the existing account-independent Supabase CLI workflow on this computer.
It has PostgreSQL, Auth, private Storage and Realtime services. The repository's
hosted connection file is not used by the local runner.

## Current setup status

Prepared on 15 November 2026. The isolated workspace contains all 12 repository
migrations. Supabase CLI 3.1.0 is pinned by the runner. WSL 3.0.5 and its Linux kernel
are installed. Windows enabled Virtual Machine Platform and explicitly requires a
restart before WSL 2 can run. Docker Desktop 4.99.0 and Docker CLI 29.9.3 are installed.
Docker Desktop starts but shows the Virtual Machine Platform prerequisite and an
engine-stopped state until that Windows feature takes effect. The local stack and
SQL integration tests have not run yet.

Backend preflight results are 239 passed and 58 integration skips. The 22 target-guard
tests and two port-binding safety cases pass. These results verify the new safeguards.
They do not establish actual PostgreSQL RLS, locking or migration behavior.

## Start and run tests

After the Windows restart, open Docker Desktop and let its Linux engine reach the
running state. Docker/WSL installation and their required terms were approved by
the user. If Windows still reports unavailable virtualization after restarting,
check WSL's reported prerequisite before retrying.

From `backend`, using its repaired virtual environment, run the following commands.

```powershell
.\.venv\Scripts\python.exe -m tools.run_local_integration --prepare-only
.\.venv\Scripts\python.exe -m tools.run_local_integration
```

The second command starts the dedicated local stack, applies migrations to that
local workspace, checks its connection identity and sets a disposable database
marker. It then runs `pytest -m integration -q` against that database. The first
startup downloads Supabase container images and needs Internet access.

| Service | Local address |
| --- | --- |
| API, Auth and Storage gateway | `http://127.0.0.1:55421` |
| Disposable PostgreSQL | `127.0.0.1:55422`, database `postgres` |
| Supabase Studio | `http://127.0.0.1:55423` |
| Test email inbox | `http://127.0.0.1:55424` |

The local database uses the standard local-only `postgres` development credential.
CLI status can provide the local public API key when app-level test acceptance is
needed. Keep generated credentials and captured status output in ignored local files.
The runner does not configure Android Firebase or prove hosted FCM delivery.

## Isolation and safeguards

- The CLI workspace is `.tmp/homecircle-local-test`. Its project ID is
  `homecircle-test`. Only the test TOML and repository SQL migrations are copied there.
- The CLI version is checked before local operations. CLI 3.1 defaults `db push` to
  the local workspace. The runner supplies no remote target or hosted connection.
- Docker uses a dedicated bridge network with its default published-port address
  restricted to loopback. The runner checks actual published bindings after startup
  and stops the test stack if a port is exposed beyond loopback.
- Test processes explicitly select `HOMECIRCLE_TEST_DB=local-test` and `APP_ENV=test`.
  They accept only the dedicated `127.0.0.1:55422/postgres` connection as `postgres`.
  Connection options pin the actual socket address, overriding `PGHOSTADDR`.
- The database must carry the runner's disposable-instance marker before fixture
  writes. Remote hosts, other local database ports, ambiguous services/addresses and
  `APP_ENV=production` are rejected.
- Existing hosted-test mode remains available for a separate project or preview
  branch, with its project-reference checks and verified TLS.
- Most SQL tests roll back. Concurrency tests commit generated fixtures and clean up
  those generated IDs. This database is dedicated to testing.

After the first successful startup, run the tests again with the following command.

```powershell
.\.venv\Scripts\python.exe -m tools.run_local_integration --test-only
```

Stop the local test containers while retaining their data volumes with this command.

```powershell
.\.venv\Scripts\python.exe -m tools.run_local_integration --stop
```

The runner does not reset databases. Unexpected migration files in its workspace
cause a reviewable error. Startup/CLI diagnostics are written to ignored
`.tmp/local-supabase-start.log`. Save actual SQL and service acceptance results in
the project status after running them. A passing local suite still leaves hosted
deployment and platform acceptance to verify.

## Why the same hosted project was unavailable

On 15 November the existing HomeCircle project's Free-plan branch dialog displayed
“Upgrade to unlock branching” and disabled creation. A preview branch requires Pro
plus branch compute charges. The user selected local testing. An additional manually
created database in a hosted project does not get its own Supabase Auth, Storage or
Data API services. Supabase documents these platform constraints.
[Multiple hosted databases](https://supabase.com/kb/troubleshooting/manually-created-databases-are-not-visible-in-the-supabase-dashboard-4415aa),
[Local development](https://supabase.com/docs/guides/local-development)
