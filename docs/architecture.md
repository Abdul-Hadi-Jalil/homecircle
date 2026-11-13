# Architecture

## Mobile

Views render state and trigger actions. ChangeNotifier ViewModels handle loading, errors and user actions. Shared repositories return typed immutable models and coordinate data policies. Services wrap HTTP, Supabase Auth and local storage. Provider composes shared instances at the application root. No widget sends HTTP requests.

`main.dart` initializes bindings, reads public compile-time configuration and initializes Supabase with platform-vault session persistence. Missing/invalid configuration and initialization failure render a localized development configuration screen without exposing exception details. `SessionViewModel` keeps routing at `/bootstrap` until session restoration and backend membership validation finish. The Supabase SDK restores and refreshes sessions; the API client obtains the current access token immediately before each protected request. It never automatically retries a mutation or queues writes.

Auth forms provide registration, login, reset email and password update after a recovery deep link. Email confirmation behavior is controlled by Supabase. Confirmation/recovery links use PKCE and the native callback scheme. Real email delivery and callback handling need validation against the configured development project.

GoRouter defines all requested named routes. The permanent tabs are Home, Inventory, Tasks, Chat and Profile; Shopping is secondary. Guard order is restoration → authentication → password recovery → validated active household → admin-only settings/invitations. Users with multiple memberships choose a household; a valid preference is restored, and a sole membership is selected automatically. Invitations and joining are implemented; role management and member removal still have SQL RPCs without app management screens.

`SessionViewModel` obtains memberships from the API on startup, foreground resume, explicit refresh and household selection. The preference is a convenience, never authorization. Switching clears visible active state immediately, increments `scopeRevision`, disconnects the old realtime scope, revalidates memberships, persists the selected ID and initializes the new scope. Generation counters discard stale responses after logout or identity changes. The navigation subtree is keyed by the scope revision. Future feature ViewModels must also reset on this revision and reject responses for old `(userId, householdId, revision)` scopes.

New household-scoped endpoints must include the household ID and check membership on the server. A mobile route guard is not an authorization boundary. Membership revocation is discovered at the next validation/API response, not instantly while a device is disconnected. Before adding live feature subscriptions, implement server-side revocation handling and the policies described below.

## Backend and database

PostgreSQL, Auth, Storage and Realtime use hosted Supabase. FastAPI runs independently as a Python service, locally during development or on a Python application host for deployment. SQL migrations are pushed directly to the linked hosted project using the Supabase CLI.

Routers validate Pydantic request bodies and verified bearer identity, then call services. Services coordinate business rules and ask repositories for authorized records. Repositories run parameterized SQL through an async Psycopg pool. Pool startup/shutdown uses FastAPI lifespan. The explicit Uvicorn loop factory selects a Psycopg-compatible Selector loop before startup, including on Windows. Auth HTTPS requests use the operating system's trusted certificate authorities with verification enabled. Database TLS uses the public Supabase CA in `backend/certs`. Connections use bounded pool/connect/request timeouts and health checks. Prepared statements are disabled to keep operational behavior predictable across supported direct/session connections. Transaction-pooler port 6543 is rejected.

`homecircle_api` is a restricted login with NOBYPASSRLS. Startup checks the actual database identity and rejects privileged roles. Each repository operation opens a transaction and sets verified JWT identity with transaction-local `set_config`. Every read filters by the verified actor and is additionally constrained by RLS. Local settings disappear on commit/rollback before a pooled connection is reused. The database login password is assigned outside migrations.

Profiles are created by a hardened `auth.users` insert trigger, including a backfill for preexisting users. Metadata supplies only a bounded display name, never authorization. Households and memberships use UUIDs, timestamptz defaults, foreign keys, a unique household/user pair and constrained roles. `create_household` inserts the household and initial admin in one database transaction. Direct client inserts into either table are denied. Membership changes use admin-only RPCs with a household-row lock and last-admin checks. Account deletion is blocked when it would orphan an administered household; transfer administration or delete that household first.

## Offline and local storage

SharedPreferences holds small preferences, JSON drafts and small cached snapshots. Cache/draft keys contain both user and household IDs. Household snapshots are cached on successful activation; in-memory validated data remains readable during a subsequent connection loss. `LocalStore.readCache` and draft APIs are ready for feature repositories. Feature-specific cache readers and form draft UIs are deferred until those forms/data exist. Large structured inventory/task caches should use SQLite via a maintained Flutter adapter in their feature milestone, after measuring query requirements.

Startup never grants access from stale cached membership. When membership cannot be validated, the household selection screen asks the user to reconnect. Revoked household cache/drafts are removed after validation; logout or identity replacement clears all private preferences/cache/drafts for the previous user. Content is not encrypted by SharedPreferences, so store only nonsensitive lightweight drafts and snapshots, not passwords, tokens or attachments. Sensitive future caches require encrypted storage. Supabase session and PKCE data use `flutter_secure_storage`; Android backup is disabled. There is no offline sync engine, mutation queue, conflict resolution or offline chat delivery.

The offline banner reflects actual failed API network requests/timeouts. HTTP 4xx/5xx prove reachability and do not imply the device is offline. It is not a radio/connectivity monitor. Successful requests clear the indicator. Home's connection actions exercise public health and authenticated `/me` through the normal repository/service stack.

## Localization and theme

Material 3 uses the supplied HomeCircle palette, 8-point spacing, common radii and centralized component themes. The UI uses English ARB resources generated by `flutter gen-l10n`/`flutter pub get`. To add Urdu, translate a complete `app_ur.arb`, regenerate and test with `Locale('ur')`. Do not advertise an untranslated Urdu locale. Directional padding and framework locale direction support future RTL layouts.

## Storage and realtime

Four private buckets are reserved with MIME/size limits. Client uploads, mutations and deletions are denied until upload validation and lifecycle rules exist. The read policy checks membership using the first path segment. Future writes must validate membership, uploader identity, file size, magic bytes and MIME server-side, generate object IDs, and normalize filenames. Do not trust MIME headers alone.

Use `<household_uuid>/<uploader_uuid>/<object_uuid>.<extension>` in every bucket. Household/inventory images allow JPEG, PNG or WebP up to 5 MiB; repair/chat attachments additionally allow PDF up to 10 MiB. Reject SVG/HTML/executable content. Issue short-lived signed download URLs (target maximum 60 seconds) only after membership authorization. Revocation prevents new reads/signatures; an already issued signed URL remains usable until expiry, so never promise instantaneous URL revocation. Deletion and retention jobs belong to the upload feature.

`RealtimeScope` owns cancellation/reset boundaries but subscribes to no channels in M0. Before adding events, disable public Realtime access in the project, use private `household:<uuid>` topics, and add `realtime.messages` RLS policies derived from current membership for Broadcast/Presence. Postgres Changes separately needs RLS and an explicit publication allowlist; a client filter is not authorization. Topics and event payloads must not expose other households. Include household/entity IDs and event versions, then refetch authoritative data. Do not broadcast full private records unnecessarily.

Household activity, inventory and task events should share the active scope; chat and task discussions can add narrower private topics only with corresponding membership policies. Cancel channels on logout/switch, reject old callbacks using the scope revision, and enforce revocation on the server. Realtime join authorization alone is not a guarantee that existing sockets immediately lose access when membership changes. No permissive topic policies or publication changes are shipped prematurely.

Firebase Cloud Messaging is reserved for a later notification milestone: platform app registration, device-token ownership, delivery permissions and server-side credentials are deliberately not fabricated or initialized here.

## Milestone 2 inventory implementation

The earlier storage/offline descriptions record the foundation baseline. Inventory
now implements feature-specific API services, repositories, ChangeNotifier state,
scoped cached reading and local form drafts. Cached list rows also seed offline
item details. Only fetched views/pages are cached; photos remain in memory and
require connectivity. There is no queued or automatic offline mutation replay.

Inventory reads and mutations go through the backend service layer. A narrowly
granted owner-executed function locks the household parent and validates the
transaction actor's membership; ordinary members do not need household settings
UPDATE privileges. Item locks, expected revisions and activity writes preserve
transaction boundaries. Absolute quantity replacement requires a revision;
relative adjustments use the locked current value.

Inventory photos use the existing item's UUID as the second path segment:
`<household_uuid>/<item_uuid>/<random_object_uuid>.jpg`. This is an inventory-specific
exception to the foundation's proposed uploader-directory convention. The API
normalizes validated images and uses the user's JWT against private Storage.
Expiring upload authorizations, attachment revisions and finalized-orphan cleanup
policies govern the lifecycle. Download returns authenticated, no-store bytes in
JSON; no signed URL is issued. Referenced archived photos are retained for restore.
Failed cleanup requires an operational retention retry through Storage API, not
direct deletion of Storage metadata. Other feature buckets remain reserved.

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for current test results, unverified
hosted migrations/RLS/Storage acceptance and required disposable-project setup.
