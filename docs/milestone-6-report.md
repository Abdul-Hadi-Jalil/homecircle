# Milestone 6 — Dashboard, Notifications & Family Activity

14 November 2026, Asia/Karachi. **Partially Implemented — external acceptance pending.**
The user confirmed that Firebase is unconfigured and authorized implementation with
documented setup. The disposable Supabase test project also remains unconfigured.

## 1. Implementation summary

The Home Dashboard reads a dedicated aggregation endpoint. It displays household
counts, prioritized attention cards, upcoming tasks, recent activity, a notification
badge, empty states and existing feature quick actions. The Family Activity timeline
supports category/date filters and cursor pagination. The Notifications Center
supports unread filtering, read/dismiss actions and household preferences.

PostgreSQL persists notifications and delivery jobs transactionally with trusted
feature events. A separate Firebase Admin worker handles leases, retries, revocation
and delivery outcomes. Android integrates Firebase Messaging, permission handling,
foreground updates and authorized notification navigation after session restoration.
Secure caches support offline reading with refresh timestamps. All production data
comes from the existing FastAPI endpoints and new household aggregation APIs.

## 2. Files created or modified

| Area | Files and changes |
| --- | --- |
| Backend API | `app/api/v1/hub.py`, router registration, task filters |
| Backend model and access | `schemas/hub.py`, `services/hub.py`, `repositories/hub.py` |
| Trusted event integration | Migration below, chat mention schema/hash compatibility, deleted-message redaction |
| Delivery worker | `app/workers/notifications.py`, worker package |
| Backend safeguards | Body limits, deployment diagnostic, environment example, Firebase Admin dependency and locks |
| Backend tests | `test_hub.py`, `test_hub_integration.py`, shared async cursor test adapter |
| Flutter dashboard | `features/dashboard/models/household_hub.dart`, `services/household_hub_api.dart`, `repositories/hub_repository.dart`, scoped/dashboard ViewModels, dashboard screen and shared widgets |
| Flutter activity | `features/activity/viewmodels/activity_viewmodel.dart`, `views/family_activity_screen.dart` |
| Flutter notifications | `features/notifications/services/push_service.dart`, notification ViewModel, center/settings screens |
| Flutter integration | Runtime, providers, app lifecycle/navigation, Home/Profile, task filters, authenticated DELETE body support, chat mention selection/drafts |
| Android | Conditional Google Services plugin, permission/channel/icon, Firebase Core/Messaging dependencies |
| Flutter tests | `hub_test.dart`, chat mention regression, runtime fakes |
| Documentation | PROJECT_STATUS, architecture, security, milestones, setup, README and this report |

Firebase Core 5.1.0, Messaging 17.0.1 and Admin 7.8.0 were added with their dependencies.
Existing dependency versions were preserved. Ignored Firebase configuration/service
account filename patterns were added. Private credentials remain outside tracked files.

## 3. Database migrations and RLS

`supabase/migrations/20261114000003_household_hub.sql` requires all preceding migrations.

| Object | Purpose and authorization |
| --- | --- |
| `household_activity_events` | Immutable projection, household-member API reads, trusted trigger writes |
| `user_notifications` | Recipient state, current membership RLS, recipient-only read/dismiss updates |
| `notification_preferences` | User/household key, own-member API access, category/push switches |
| `user_device_tokens` | Protected direct-send target, SHA-256 identity, installation session, revocation |
| `private.device_revocations` | Logout tombstones preventing late registration from reviving a revoked session |
| `private.notification_push_jobs` | Unique notification/device pair, lease, attempts, retry and outcome |
| `households.time_zone` | Validated IANA zone, UTC default, administrator API configuration |
| `household_messages.mentioned_user_ids` | Up to 20 explicit current-household members, immutable after creation |

A separate restricted `homecircle_worker` role receives execute permission on claim,
authorize and completion functions. Raw notification/token/job generation remains
restricted to trusted functions and triggers. API callers receive identifiers for
device registration. Private targets stay inside protected database/worker paths.

The migration backfills existing inventory/task activity before installing notification
generation. Historical actions/times come from persisted events. Backfilled labels
use the current record name and carry explicit metadata. Membership events begin at
deployment. Historical notification generation starts with new operations.

Static parsing passed for 71 top-level statements, 12 PL/pgSQL bodies and the dashboard
query. The parser used substitute record declarations because its standalone catalog
lacks project row types. Actual schema resolution, grants, triggers, RLS and execution
remain unverified. Migration deployment remains pending. Production data was untouched.

## 4. New API endpoints

All paths use `/api/v1` and verified bearer identity. Responses use `Cache-Control`
with `no-store`. Mutation inputs reject client actor/recipient fields.

| Method/path | Behavior |
| --- | --- |
| GET `/households/{id}/dashboard` | Household aggregation and unread count |
| PATCH `/households/{id}/dashboard-settings` | Administrator updates `time_zone` |
| GET `/households/{id}/activity` | Category, event type, timezone-aware start/end, cursor, page size |
| GET `/notifications` | Own current-member records, optional household/unread filter and cursor |
| GET `/notifications/unread-count` | Own unread, undismissed count in the requested scope |
| GET `/notifications/{id}` | Authorized lookup for a notification tap |
| PATCH `/notifications/{id}/read` | Idempotent recipient read timestamp |
| POST `/notifications/mark-all-read` | Recipient update with optional household filter |
| PATCH `/notifications/{id}/dismiss` | Idempotent recipient dismissal |
| POST `/devices/fcm-token` | Register/rotate authenticated installation target |
| DELETE `/devices/fcm-token` | Revoke authenticated installation session |
| GET/PATCH `/households/{id}/notification-preferences` | Own household preferences |

Activity uses inclusive `start` and exclusive `end`, both timezone-aware. Page size is
1–100. Cursors bind household, recipient where applicable, filters and date range.
Ordering uses descending creation time and UUID. Task lists gained active/non-shopping
filters so dashboard summary links show the corresponding records.

## 5. Flutter screens and reusable widgets

Screens adapt `UI/home_dashboard`, `UI/family_activity_history`,
`UI/notifications_center` and the shared HomeCircle theme. Dashboard cards navigate to
filtered existing modules. Add Item, Request Something, Repair and Send Message
reuse existing flows. Profile exposes household notification settings.

Activity groups events by local date and displays actor/action summaries, related
records and timestamps. Notification sections use Today, Yesterday and Earlier.
Unread cards have a blue tint. Permission explanations distinguish OS alerts from
persistent in-app notifications. English strings use the existing localization system.

Initial avatars/icons replace sample photographs. Chat content and invitation codes
are omitted from general activity and lock-screen copy. Refresh status represents
actual fetched or cached data. Device accessibility, text scaling and exact Stitch
fidelity still require device acceptance. Rendered fixture-based screen captures are
linked from the project status after visual inspection.

## 6. Dashboard aggregation strategy

One SQL statement provides a consistent record snapshot with bounded card lists.
Counts use current household records and existing statuses.

| Metric | Definition |
| --- | --- |
| Pending Tasks | Active, non-shopping, non-archived tasks |
| Urgent Issues | Pending tasks with Urgent priority |
| Shopping Items | Active, non-archived shopping requests |
| Low Stock | Positive consumable quantity at or below its minimum |
| Out of Stock | Consumables with zero quantity |
| Overdue Tasks | Active tasks, including shopping, due before household-local today |
| My Tasks | Active tasks, including shopping, assigned to the verified user |

Active means Open, In Progress or Blocked. The empty-household check also recognizes
completed/cancelled records. Upcoming cards cover today through seven days ahead,
limited to five. Needs Attention is limited to eight unique entities.

Attention ranks urgent overdue tasks first, then other urgent tasks, high-priority
overdue tasks, other overdue tasks, high-priority tasks, stock/condition shortages,
normal tasks and low-priority tasks. Broken/Needs Repair durable inventory also
appears. Due date, update time and UUID provide stable tie ordering.

The household zone defaults to UTC. An administrator can PATCH dashboard settings
with `{"time_zone":"Asia/Karachi"}` or another valid IANA zone. The dashboard displays
the configured zone. Greeting and activity/notification display times use device time.

## 7. Unified activity strategy

A central projection reuses existing inventory/task activity inserts. Existing
feature histories continue to work. A unique source identity handles replay, and a
revision uniqueness index collapses derived assignment/priority audit rows from one
task update into one family event. Shopping uses its existing task activity.

Membership triggers record join/add, leave/remove and role-change actions with the
actual actor. Source-time names are retained for current household members viewing
history. Deleted profiles fall back to a former-member label. Membership revocation
prevents access to the feed. General activity excludes chat message events.

## 8. Notification and FCM architecture

Trusted source events resolve current-member recipients and persist notifications
and push jobs in the business transaction. Source/recipient uniqueness handles
duplicate processing. Ordinary own actions are suppressed. Newly assigned members
receive assignment alerts, urgent requests reach eligible members, completion reaches
the creator/assignee and shopping updates reach interested members.

Inventory alerts follow meaningful stock severity increases and condition changes.
Repeated reads and unchanged low-stock states create no alerts. Explicit chat mention
IDs generate mention notifications, with ordinary chat notifications for other eligible
members. Disabled categories suppress new records. `push_enabled` additionally gates
delivery jobs. Preferences are rechecked before delivery.

The worker uses Firebase Admin `Message.fid`. Flutter SDK 17 reports its opaque
direct-send target through `onRegistered`. The requested token API/table names remain
the registration contract. Payload data contains notification/household IDs and event
type. OS-visible title/body are generic. Android notification tags deduplicate visible
retries. Firebase describes registration and app-state handling in its current Flutter
documentation. [Firebase Messaging setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)

## 9. Device token and worker lifecycle

Authorized foreground sessions register current targets and observe rotation.
Installation identity is saved securely. Explicit user action requests OS permission,
and a device-level flag prevents repeated permission prompts after denial. Logout
starts SDK unregistration and authenticated server revocation before Auth sign-out.
Native registration/unregistration operations are serialized. Server revocation
tombstones reject old installation-session requests that arrive late.

Each user supports multiple active devices. Rotation revokes the previous target for
that installation. An authenticated target handoff revokes its previous account owner.
Active registrations are bounded to 20 per user. Tokens and targets stay out of logs
and API list responses. Offline logout can leave an in-flight generic OS alert until
server/FCM revocation takes effect.

Worker jobs use `FOR UPDATE SKIP LOCKED`, two-minute leases and at most eight attempts.
Retry delay starts at 30 seconds and doubles up to one hour. Expired leases recover
after worker loss. A fresh authorization check suppresses revoked devices, lost
membership, read/dismissed notifications and disabled preferences. Unregistered targets
are revoked. Configuration/permanent errors stop retries. Late lease acknowledgements
are rejected. Processing has at-least-once semantics.

Run the independent process from `backend` with
`python -m app.workers.notifications`, or add `--once` for one controlled batch.
Its database connection must use the restricted worker login with verified TLS.
The API process operates independently of Firebase credentials. Firebase documents
the error categories used by the worker. [FCM error codes](https://firebase.google.com/docs/cloud-messaging/error-codes)

## 10. Security verification

Isolated tests verify typed inputs, recipient-bound API operations, scoped cursors,
date validation, generic payloads, SDK error classification, lease orchestration,
scope changes, offline writes and notification navigation. Protected targets are
looked up through the authenticated API before navigation. The household embedded in
FCM data grants no authority. Session restoration and household selection precede
protected routing, including explicit taps from another household.

Membership removal deletes that user's household notification history/preferences
and cascades pending jobs. Device registration belongs to the account/device across
households. RLS and trigger behavior still need the guarded database suite. Existing
M1 authentication/callback/session/removal and M2–5 hosted acceptance gaps remain.

## 11. Executed checks

| Check | Result |
| --- | --- |
| Baseline backend | 195 passed, 46 skipped |
| Baseline Flutter | 90 passed, 2 skipped |
| Backend full suite | 219 passed, 56 skipped |
| Ruff format/check | Passed |
| Python dependency consistency | Passed |
| Flutter dependency restoration | Passed with existing locked versions preserved |
| Flutter full suite | 107 passed, 2 skipped |
| Flutter analysis | Passed |
| Android debug build | Passed with Firebase dependencies and configuration-disabled runtime |
| Static SQL/PLpgSQL parsing | Passed with catalog limitations described above |
| Hosted migration/RLS/worker/FCM delivery | Unverified |

The backend suite has one upstream Starlette/httpx TestClient deprecation warning.
The successful Android build reports a `firebase_core` Kotlin Gradle Plugin migration
warning. Compatibility with future Flutter versions remains an upgrade consideration.
The additions include 24 passing backend cases, 16 Flutter hub cases and one chat
mention regression. The Shopping loading test now centers its navigation link before
tapping it in the expanded dashboard.
Ten new guarded database cases are included in the skipped total. They cover metrics,
closed/archived tasks, activity projection/pagination, recipient RLS, preferences,
stock transitions, mentions, device leases/rotation, revocation and rollback.
Two optional Flutter live API tests require `LIVE_API_BASE_URL`.

Commands used include Ruff format/check, `python -m pytest -q`, `python -m pip check`,
`flutter pub get`, `dart format`, `flutter analyze`, `flutter test --no-pub` and
`flutter build apk --debug --no-pub`. Java TLS verification used the existing task-local
trust store. Ordinary tests mock Firebase. Production pushes were never sent.

## 12. Required Firebase and Supabase setup

Follow the M6 section in setup.md. Provision the separate disposable Supabase project,
apply migrations in order, provision the restricted worker login, configure the
intended Firebase Android app and backend credentials, then run the guarded suite
and controlled device acceptance. The user confirmed that Firebase is unconfigured.
The read-only catalog diagnostic and final build results are recorded in PROJECT_STATUS.

## 13. Incomplete or unverified functionality

Actual hosted schema deployment, RLS/transaction execution, worker leases under real
concurrency and live FCM delivery remain unverified. Configured Android foreground,
background and terminated delivery/navigation require a Google Play-enabled device.
Device permission, secure storage, token rotation/logout and accessibility need
physical-device acceptance. iOS push certification is outside this milestone.

Dashboard/activity updates use periodic authoritative reads, pull refresh and refresh
after session restoration/resume. Foreground FCM debounces notification/dashboard
invalidation. Dedicated Supabase Realtime subscriptions for these modules remain
incomplete. Existing private M5 chat subscriptions continue independently.

Operational retention needs an owner-reviewed policy. Revoked device rows and terminal
jobs can be cleaned through reviewed maintenance. Installation revocation tombstones
and source deduplication identities must retain replay protection. Activity is retained
for current members. Private household caches remain isolated behind validated
membership and are cleared on logout or detected active-scope authorization failure.

## 14. Milestone completion status

**Partially Implemented — external acceptance pending.** Code and isolated test
evidence are available. Completion requires the hosted database and controlled
Firebase/device checks described above.

## 15. Readiness for Milestone 7

Milestone 7 remains unstarted. M1–6 external acceptance, configured push verification
and operational setup remain prerequisites for declaring release readiness.
