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
direct deletion of Storage metadata. The task implementation below activates the
repair bucket; household and chat buckets remain reserved.

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for current test results, unverified
hosted migrations/RLS/Storage acceptance and required disposable-project setup.

## Milestone 3 tasks, requests and repairs

`features/tasks` follows the same service → repository → ChangeNotifier → view
structure, using the shared `ApiClient`, `LocalStore`, session scope and Provider
runtime. GoRouter mounts overview, create, detail and edit routes. Inventory details
reuse the tasks view-model for related repairs and prelinked creation. Views do not
make HTTP calls directly. The task-specific widgets adapt the supplied Stitch
exports in `UI/`, retaining the shared HomeCircle theme and navigation.

FastAPI task routes delegate to Pydantic inputs, `TaskService`/`TaskPhotos` and the
Psycopg `TaskRepository`. Household parent membership locks precede task row locks;
optimistic revisions and activity changes share transactions. Comment writes also
check their own revision. Explicit terminal-state reopening preserves old state in
activity. Task completion never updates inventory within its transaction; an optional
confirmed inventory operation happens separately and cannot undo completion.

Tasks, comments, attachment metadata and activity use composite household foreign
keys and RLS. Ordinary members can write through the API. The assignee must remain a
member; membership deletion clears the assignment, increments revision and records
the system change. A repair's inventory link must belong to its household.

Task/comment photos use private `repair-attachments` with paths
`<household_uuid>/<task_uuid>/<attachment_uuid>.jpg`. The shared image normalizer
accepts valid JPEG/PNG/WebP input up to 5 MiB/16 MP, strips metadata and stores JPEG.
The photo middleware bounds base64 JSON requests to 8 MiB before parsing. Expiring
user-bound upload permits and finalization control lifecycle/cleanup. Authorized
downloads use 60-second signed URLs; the URL stays only in memory. Archived task
objects remain for restore. Deleted-comment objects lose active read access and
need retention cleanup. Signed URLs already issued remain usable until expiration.

Fetched task pages/details, comments, activity and attachment metadata are cached
by user and household. Only fetched views are available offline. Drafts preserve
original revisions; explicit failed saves do not claim success and reconnect never
replays writes. Late responses and old-scope actions are rejected. Auth errors clear
caches rather than invoking network fallback. Photos are not persisted locally.

See [the M3 report](milestone-3-report.md) for the complete API/model, status rules,
design sources, tests and remaining live acceptance gates. No shopping, chat/realtime,
FCM or family dashboard implementation was added.

## Milestone 4 shared shopping

`household_tasks` remains the authoritative task parent. One-to-one
`shopping_item_details` contains quantities/units, an optional inventory link and
current purchase metadata. Each completion has a new UUID. Deferred consistency
triggers enforce parent/detail type and completion agreement. Existing generic task
status operations delegate shopping transitions to `ShoppingService`.

`ShoppingRepository` extends the task repository transaction boundary. Parent/detail
locks, expected revisions and task events govern writes. A separate explicit
`apply-inventory` transaction locks current inventory, reuses inventory adjustment
logic and writes stock/activity plus `shopping_inventory_applications`. Its unique
purchase UUID makes successful retries idempotent. Undo clears active purchase
metadata and retains the ledger, stock and historical purchase events.

The Flutter shopping feature reuses task priority/status/member/inventory widgets,
the session scope and the existing cache repository with a distinct namespace.
Views cover list/progress/filter/search, compact create/edit, purchase sheet,
responsibility/details, explicit stock update and purchase history. The secondary
shopping route is reached from Home, task creation/listing and inventory details.

Cached list/details/summary/history and original-revision drafts are partitioned by
user and household. Scope generations reject late responses. Offline saves retain
drafts, and reconnect never replays writes. Collaboration currently refreshes on
resume/manual/pull actions. Private realtime delivery remains unconfigured.

All UI export folders now sit directly under `UI/`; the shared design reference is
`UI/warm_household_modern/DESIGN.md`. See [the M4 report](milestone-4-report.md)
for API contracts, quantity/currency strategy, consistency rules and test limits.

## Milestone 5 family chat

Messages live in `household_messages`, with scoped reactions, attachments and task
conversion relations. FastAPI validates typed Pydantic inputs and verified JWT actors;
Psycopg repositories set transaction-local claims under the restricted API role.
Composite household keys prevent foreign replies, attachments and task links.
`(household, sender, client_message_id)` and a canonical request hash provide
idempotency. Expected revisions protect edits/deletes. A household advisory transaction
lock serializes chat writes and reads so committed event cursors cannot skip an
earlier uncommitted change. This favors correctness over high-volume throughput.

Chat invalidations are inserted with each mutation in `chat_events`. An owner-only
dispatcher queues private `chat_changed` broadcasts to `chat:<household>:<user>`
for current members. Realtime receives only entity IDs, sequence, kind and revision.
Failed queue acknowledgement leaves the event pending for the owner Cron retry job.
Messages, events and conversion relations roll back together. Realtime observes the
committed queue; clients tolerate duplicate/out-of-order broadcasts and refetch via
`/changes`. History uses `(created_at, id)` cursors; change cursors include tombstones.
This supersedes the M0 topic proposal above for chat. No publication change or raw
Postgres Changes subscription is needed. Existing task/shopping live sync is unchanged.

Flutter keeps Provider/ChangeNotifier MVVM, Dart HTTP and GoRouter. Chat services
handle HTTP/Realtime; repository validates scope; ViewModel owns reconciliation,
drafts, pending UUIDs, cursor catch-up, reconnect and teardown. The family chat screen
adapts `UI/family_chat`; its action sheets/dialogs use the existing HomeCircle theme.
Visible shared task cards refresh authoritative status every 30 seconds and on entry.
Message conversion navigates with an in-memory source object to the existing reviewed
forms, then calls existing business services inside the chat transaction.

Secure storage holds up to 100 recently loaded messages, one composer draft and up to
20 failed sends per user/household. Source-form drafts also use secure storage.
Photo bytes and signed URLs are not persisted. Restored sends are failed/manual-retry;
reconnection never sends automatically. A reviewed task becomes ordinary task data
and follows the existing task/shopping cache policy. Chat data stays out of preferences.
Vault failure shows a warning while online operations remain available. Logout,
identity/scope change and known revocation clear or isolate private state; cached
membership never authorizes app entry. App/device secure-storage acceptance is pending.

Chat images accept decoded JPEG/PNG/WebP, at most configured 5 MiB/16 MP, and are
normalized to metadata-free JPEG. The earlier generic PDF proposal is not enabled
for chat. Upload permits bind actor, household, client message UUID, random attachment
UUID and exact bytes. Storage uses the user's JWT, without service-role credentials.
Finalized objects are verified before message attachment. Authorized reads issue
60-second signed URLs; deletion tombstones the image message and attempts object
cleanup. A reviewed operator retention workflow is still required for stranded objects.

See [the M5 report](milestone-5-report.md) for API, migration, retry-job setup and
explicit hosted acceptance gaps. No M6 implementation is included.
