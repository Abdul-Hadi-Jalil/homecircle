# Security boundaries

Current acceptance status is in [PROJECT_STATUS.md](PROJECT_STATUS.md). The M2/M3
security properties below have isolated tests; actual hosted RLS, transactions and
Storage behavior still require the separate disposable project.

## Identity and database roles

| Principal | Authority |
| --- | --- |
| Flutter publishable/anon key | Identifies the public project; grants no household authority |
| Supabase user access token | Verified user identity; uses `authenticated` for authorized client access |
| `anon` | No application table access and no household RPC execution |
| `authenticated` | RLS-scoped reads; own profile field updates; admin-only household settings/deletion via RLS; guarded RPC execution |
| `homecircle_api` | Restricted LOGIN, NOBYPASSRLS, no role creation/schema ownership; same scoped policies and guarded RPCs |
| Hosted migration owner | Privileged DDL and hardened security-definer owner; never used by the running API |
| Supabase service role | Privileged platform role, not used by mobile or this API; never a substitute for user authorization |

FastAPI validates Bearer signatures, expiration, issued-at time, issuer, audience, UUID subject and `authenticated` role on every protected request. Asymmetric algorithms are explicitly allowlisted and use project JWKS. Legacy HS256 requires explicit configuration and the real server-only signing secret. Header inspection only selects a verification key; unverified claims never authenticate a user. No user ID from request bodies becomes the actor.

Every repository operation sets identity only inside a database transaction. RLS uses that identity, while SQL also filters the verified user. The API refuses a privileged connection at startup. A stolen database login could set arbitrary transaction claims, so protecting that password remains essential; RLS is an additional boundary against missing query filters, not protection against compromised API credentials.

Profile metadata cannot set roles. Membership privileges are held in `household_members`, with no direct client writes. Security-definer functions use an empty search path, fully qualified relations, explicit execute grants and a small controlled surface. Membership helpers derive the actor from `auth.uid()` and avoid recursive policies. Only admins may change roles or remove members. Serialized household locks prevent concurrent last-admin demotions/removals. An Auth account cannot be deleted while it is a household's only admin. Household creation atomically installs the first admin; failed writes roll back together. A member cannot delete a household or change its destructive settings.

Supabase may create broad default grants on public-schema objects. The migration revokes application table privileges and function PUBLIC/anon execution explicitly, then adds only required grants. When adding a table, apply RLS and grants in the same migration. Never assume a privileged Psycopg connection obeys RLS. Do not add a permissive `using (true)` household policy.

## Sessions, caching and transport

Do not log passwords, bearer tokens, request bodies, SQL exception strings or connection URLs. Production error responses are generic; validation errors do not echo input. The backend logs only the exception class for unhandled requests; the documented Uvicorn commands disable access logging. Platform infrastructure and reverse proxies need equivalent redaction. JWKS caching makes urgent revocation subject to a short propagation window; see environment documentation.

Use HTTPS for API/Auth traffic and verified TLS for remote PostgreSQL. Debug Android cleartext exceptions are destination-limited and separate from release configuration. Android app backup is disabled. Session/PKCE data lives in the platform vault. Small nonsensitive household caches and drafts are partitioned by user plus household, erased after discovered revocation and on logout, and never accepted as membership proof. Offline logout removes local state; server revocation may require connectivity, and existing access tokens can remain valid until expiry.

The four storage buckets are private. Reserved uploads are denied until validation is built. Signed URLs are bearer capabilities that can outlive membership changes until expiry. Realtime sends no events in M0; enabling future channels requires private-channel policies and server-side revocation handling, as detailed in architecture documentation.

## Verification and deployment responsibilities

Unit tests verify real cryptographic signatures and invalid claims, dependency behavior, pool identity checks, transaction rollback, and service authorization. Eight opt-in tests exercise actual RLS, self-promotion denial, last-admin guards, multi-household isolation, atomic creation, profile identity restrictions and storage denial in a separate hosted Supabase test project. Guards require verified TLS, check the expected test project identity and reject the app project's connection. They are skipped unless explicitly configured; mock transaction tests do not establish that database policies work on a live project.

Before deployment, run those integration tests, review Supabase database advisors, test two real users in different households, confirm redirects and email delivery, verify the actual signing mode, and use a restricted login with verified TLS. Rate limiting and abuse controls belong at the API gateway/Supabase Auth settings before exposing a public deployment. Configure release signing and push credentials in their deployment milestones. No production project is modified automatically.

Primary references: [Supabase JWT signing keys](https://supabase.com/docs/guides/auth/signing-keys), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [database connections](https://supabase.com/docs/guides/database/connecting-to-postgres), [Storage policies](https://supabase.com/docs/guides/storage/security/access-control), [Realtime authorization](https://supabase.com/docs/guides/realtime/authorization), [Psycopg pools](https://www.psycopg.org/psycopg3/docs/advanced/pool.html).

## Milestone 1 invitations

Codes contain 80 random bits and use server-peppered HMAC-SHA256 hashes. The API role has metadata-only column grants, not hash reads. Fixed definer RPCs enforce verified transaction identity, administrator management, member-only redemption, parent-first row locks and usage quotas. A separate committed per-user attempt transaction limits preview/redeem to twenty attempts per five-minute bucket. Plaintext codes live only in the issuance response and current UI, with user-requested clipboard/share export. Keep the pepper in server secrets. Private.current_actor exposes only the transaction actor UUID so profile RLS works without Auth schema grants or broad role inheritance. See the Milestone 1 report for external SQL verification still required.

## Inventory and task boundaries

The M2 member lock helper validates transaction identity and locks the household
without requiring household settings UPDATE permission. Task writes lock the task,
compare the expected revision and record activity atomically. Concurrent claims
must have a single winner; actual PostgreSQL behavior is covered by guarded tests
that have not run. Composite foreign keys constrain assignees, linked inventory,
comments and photos to their household/task. Member removal unassigns tasks through
a trusted trigger. Actor fields, timestamps and revisions cannot be supplied by API
callers. Direct authenticated task mutations are denied. Author/admin comment and
uploader/admin photo rules are checked both by services and RLS. No service-role
credential or privileged runtime database connection is introduced.

Inventory and task photos use validated, normalized metadata-free JPEG, generated
object names, user-JWT Storage calls and expiring upload permits. Task photos use
the private repair bucket with 60-second signed URLs; inventory photos retain their
authenticated no-store byte endpoint. URL responses are no-store and URLs are not
persisted in task caches. An issued URL can outlive membership revocation for its
remaining lifetime. Task/comment archival/deletion blocks new active-photo signing;
archived referenced objects remain available for restoration.

Finalization and reference checks prevent cleanup from deleting in-flight/referenced
objects. Task cleanup additionally requires uploader/admin authority. Failed cleanup
needs an operational retention retry via Storage API; do not delete Storage metadata
directly in SQL. Photo request bodies are bounded to 8 MiB before JSON parsing,
including chunked requests; retain a reverse-proxy limit and normal request timeouts.

Task caches/drafts are keyed by user and household, cleared on authorization failure,
and never used as authorization. Scope generations reject late responses and old
actions. Cached reads remain available offline but cannot learn about remote
revocation until connectivity returns; preferences are not an encrypted vault. No
offline mutation replay is implemented. A completed repair cannot silently mark
inventory Working; the optional inventory write requires explicit user confirmation
and its own current inventory revision.

See [the M3 report](milestone-3-report.md) for policy/lifecycle details and remaining
SQL, real-user and Storage acceptance. No production mutations were made for tests.

## Shopping purchase and stock boundaries

Shopping details and inventory applications use member-scoped RLS and restricted
API writes. Composite household keys bind parent, detail and inventory. Deferred
triggers require a Shopping parent/detail pair and matching completion metadata.
The verified transaction actor supplies purchaser/application identity. Current
purchase metadata is immutable until reopened. Inputs reject client purchaser IDs.

Task/detail locks and revisions serialize edits, claims, purchases and undo. The
stock operation additionally locks current inventory and checks active consumable
type, exact unit and final quantity bounds. The purchase ledger has a unique UUID,
so stock, ledger and both activity records commit together at most once per purchase.
Retry checks the same purchase UUID before treating an old revision as a conflict.
A reopened or later purchase cannot be affected by an earlier UUID. Undo preserves
stock and audit history, requiring explicit inventory correction when appropriate.

Creation and updates use typed inputs, parameterized SQL, bounded pagination and
allowlisted filters/sorts. Quantities/prices use exact decimals and string responses.
Task cache guards are reused with a shopping namespace. Scope changes and auth
failures clear visible/private state, and offline reads never authorize writes.

Seven guarded SQL shopping cases remain skipped without the disposable project.
Actual triggers/RLS/concurrency and real-user acceptance remain unverified. The
forward migration preserves outstanding/cancelled legacy Shopping parents with empty
details. Completed legacy parents require reviewed purchase attribution before
deployment. Manual/pull/resume refresh is implemented. Secure private realtime
publication and subscription acceptance remain pending.
