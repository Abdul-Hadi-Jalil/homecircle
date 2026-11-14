# Milestone 5 — Family Chat & Realtime Communication

14 November 2026, Asia/Karachi. **Partially Implemented — hosted acceptance pending.**
This report distinguishes isolated passing checks from hosted behavior that has not
been verified. No production writes or migration deployment were performed.

## 1. Implementation summary

Implemented one group conversation per household, real API history and text sending,
cursor pagination, replies, six reactions, own-message edit/delete, image attachments,
existing task sharing and reviewed message conversion to Repair/Chore/General/Shopping.
Sending, Sent and Failed/manual Retry states use client UUIDs. Offline mode supports
secure cached reading and local drafts; it never automatically sends queued messages.
The app uses the existing FastAPI/Pydantic/Psycopg/Supabase and Flutter MVVM stack.

## 2. Files created or modified

- Backend: `app/api/v1/chat.py`, `schemas/chat.py`, `repositories/chat.py`,
  `services/chat.py`, `services/chat_photos.py`; router, settings, body-size middleware,
  shared photo normalizer, deployment diagnostic and `.env.example` extended.
- Backend tests: `tests/test_chat.py`, `tests/test_chat_integration.py`.
- Flutter: `lib/features/chat/models/{chat_message,chat_task_source}.dart`,
  `repositories/{chat_cache,chat_repository}.dart`,
  `services/{chat_api_service,chat_conversion_service,chat_realtime_service}.dart`,
  `viewmodels/family_chat_viewmodel.dart`, `views/family_chat_screen.dart`.
- Flutter integration: app providers, runtime, router, localization/generated resources,
  task/shopping forms and ViewModels, shared error copy; `test/chat_test.dart` and
  test runtime/cache fakes. Existing Shopping widget test now scrolls its checkbox
  into view before tapping, resolving the baseline narrow-layout test failure.
- SQL: migration and owner retry-job file below. README, PROJECT_STATUS, architecture,
  security and milestones updated. Existing dependency locks remain unchanged.

## 3. Database migrations

`supabase/migrations/20261114000002_chat.sql` is a forward migration requiring all
preceding foundation, inventory, task and shopping migrations.

| Relation | Purpose |
| --- | --- |
| `public.household_messages` | Author, client UUID, type/body, reply/task links, revision, edit/deletion timestamps |
| `public.message_reactions` | One member/message/emoji row; six allowed emoji |
| `public.message_attachments` | Finalized, exact-path image metadata bound to its message |
| `private.chat_uploads` | Actor/message-bound permits, byte hashes, expiration/finalization/abandonment |
| `public.chat_task_conversions` | Persistent source-message/task relation and conversion retry identity |
| `public.chat_events` | Durable ordered invalidations and publication acknowledgement |
| `private.chat_rate_limits` | Shared database rate windows per member/household/action |

Composite household foreign keys, immutable ownership, deferred image-content checks,
event triggers, RLS/grants and private Storage/Realtime policies are included. System
message type is reserved; user creation is denied. No system-message producer is shipped.
**Migration syntax/platform behavior has not been validated against PostgreSQL.** The
read-only deployment diagnostic returned `connection_unavailable`; deployment status
cannot be assumed. No table reset, hosted migration apply or destructive SQL ran.

## 4. API endpoints

All paths below are under `/api/v1/households/{household_id}/chat` and require a
verified access token and current household membership.

| Method/path | Behavior |
| --- | --- |
| GET `/messages?before=&after=&limit=` | Stable history, scoped opaque cursor; choose before or after; limit 1–100 |
| GET `/changes?after=&limit=` | Ordered recovery of current records/tombstones; limit 1–200 |
| POST `/messages` | Typed text/image/task-share; 201 new, 200 same-payload retry |
| GET `/messages/{id}` | Current authorized representation |
| PATCH `/messages/{id}` | Nonempty body edit, sender-only, expected revision |
| DELETE `/messages/{id}?expected_revision=` | Sender-owned tombstone and best-effort image cleanup |
| PUT `/messages/{id}/reactions` | Set own allowlisted reaction idempotently |
| DELETE `/messages/{id}/reactions/{emoji}` | Remove own reaction idempotently |
| POST `/share-task` | Typed task-share convenience endpoint |
| POST `/messages/{id}/create-task` | Reviewed typed task/Shopping fields; source revision and stable request UUID |
| POST `/attachments` | Validate/normalize/upload/finalize one image permit |
| GET `/attachments/{id}/url` | Authorize active image; return 60-second URL, no-store |
| DELETE `/attachments/{id}?expected_revision=` | Delete the owning image message; sender-only |

Default rate windows per minute: 60 message mutations, 120 reactions, 10 uploads;
conversion is 20. `CHAT_MESSAGE_RATE`, `CHAT_REACTION_RATE`, `CHAT_UPLOAD_RATE`
and `CHAT_IMAGE_MAX_BYTES` configure the supported limits. Non-image chat request
bodies are capped at 64 KiB, upload bodies at 8 MiB; decoded images at most 5 MiB/16 MP.

## 5. Flutter screens and components

`FamilyChatScreen` replaces the placeholder and adapts `UI/family_chat/code.html` and
`screen.png`: household header/member count, initial avatars, incoming/outgoing
bubbles, date chips, names/timestamps, reply previews, task cards and attachment/text
composer. HomeCircle theme and existing modal/selection components guide interactions.
Action sheet is scrollable on short screens. Pending sends have progress/retry/discard;
restored image drafts require reselecting bytes when not already uploaded.

Images open a zoomable viewer after requesting an authorized URL. Search/pagination
in the share picker use existing real task endpoints. Task cards refresh on entry and
every 30 seconds and open the proper existing Task/Shopping details route. Archived
or missing tasks show unavailable. Conversion opens the existing reviewed form with
source data passed through router memory, not private text in a URL. Source forms
use secure drafts, and backend creation reuses existing services in one transaction.

Text initials replace sample avatar photography. Labels say Sent, not Delivered;
receipts, typing, voice, push, DMs, public rooms and video are not implemented. Real
device visual fidelity/accessibility and platform image-picker acceptance are pending.
The [rendered chat capture](images/milestone-5-chat.png) uses test fixtures and real
fonts; production screens load authenticated API data.

## 6. Realtime architecture and delivery mechanism

PostgreSQL remains authoritative. Message/reaction/attachment/conversion triggers
append invalidations inside the mutation transaction. The owner-only dispatcher
queues `chat_changed` through `realtime.send` with `private=true`, then records
acknowledgement. Failed/missing queue acknowledgement leaves the event pending.
The in-transaction trigger attempts immediate delivery; owner Cron retries pending
events using `supabase/operations/chat_realtime_jobs.sql`.

Recipients are current members, each on `chat:<household UUID>:<user UUID>`.
Payloads contain event/message/household IDs, sequence, kind and revision, never body,
image bytes or signed URL. Database Broadcast uses committed WAL; missing daily
Realtime partitions can drop a send with a warning, so acknowledgement is explicitly
checked. Repeated attempts may queue duplicates; clients reconcile by ID/version.
See Supabase's [database Broadcast documentation](https://supabase.com/docs/guides/realtime/broadcast)
and [authorization model](https://supabase.com/docs/guides/realtime/authorization).

Client subscriptions use private mode and current Auth token. Reconnect triggers
change-cursor catch-up; a 30-second authoritative refresh and resume/manual refresh
provide recovery when Realtime is unavailable. History and change cursors preserve
ordering and catch edits/deletions to older cached messages. There is no delivery
receipt or exactly-once broadcast guarantee. Database/transport behavior is unverified.

## 7. Authentication and authorization

API reads/writes check current membership inside the existing locked household
transaction. Ordinary members can participate. Only a message sender edits/deletes;
only a reaction author removes their row. Typed inputs reject forged actors, direct
system messages, unknown fields, arbitrary Storage paths and foreign references.

Raw chat tables are API-only because soft-deleted original text is retained for audit.
API tombstones omit body and private relationships. Reply previews redact deleted
parent text. Foreign household data is also rejected by the Flutter repository.
Private Realtime join requires current membership and the user's own exact topic;
restrictive chat namespace policies stop broad policies widening access. Client
publishing and dispatcher invocation are denied.

Dispatcher fan-out omits removed members even if an old websocket remains open.
Pre-removal queued invalidations may arrive, without body text; fresh API reads remain
authorized. Current membership removal is serialized against household operations.
Confirmed API authorization failure clears visible/cache/draft/image state, disconnects
and stops automatic refresh. M1 real sign-in/session/household/removal acceptance is
still pending; it blocks secure production acceptance of this feature.

## 8. Idempotency, concurrency, attachments and caching

Unique `(household, sender, client_message_id)` plus canonical request hash makes a
same-payload retry return the existing record; conflicting reuse returns 409. Conversion
has an independent persistent actor/request UUID and returns the current full task on
retry. Expected revisions reject stale edits/deletes. Bound existing creation services
commit tasks and their chat relation/events together. A household advisory lock
serializes API chat commits so change cursors cannot skip uncommitted lower sequences.
This implementation is intended for household traffic, not high-volume public chat.

Image normalization strips metadata and permits only decoded JPEG/PNG/WebP, re-encoded
as JPEG. Uploads use the verified user's JWT and immutable generated paths. Finalized
object bytes/hash are checked before attaching. Permits authorize upload for 60 seconds;
finalized staging lasts one day. Active message membership gates signing. URLs expire
after 60 seconds but remain usable until expiry after deletion/removal. Failed upload
or message deletion attempts private Storage API cleanup. Stranded objects after a
crash/cleanup failure need an operator retention workflow; no automatic orphan sweeper
is shipped. Never delete Storage metadata directly or use the production test target.

`SecureChatCache` uses Flutter secure storage and a serialized key registry. History
holds up to 100 recently loaded messages; older fetched pages are available offline
only while retained. Composer and up to 20 pending sends are scoped by user/household.
No image bytes/signed URLs are persisted, and no plaintext preferences fallback exists.
Reviewed created tasks follow the established task/Shopping cache policy. Switching
isolates caches, logout clears the prior account, and late old-scope responses are
discarded. Membership must be validated before entering cached household screens.
Offline writes fail visibly and require manual retry with the original UUID.

## 9. Test commands and actual results

Final full-suite results: **195 backend passed / 46 skipped**, **90 Flutter passed /
2 skipped**. Backend checks completed:

- `.venv/Scripts/ruff.exe format --check app tests tools` and `ruff check app tests tools`: clean.
- `.venv/Scripts/python.exe -m pytest -q`: **195 passed, 46 skipped**, one existing
  upstream Starlette/httpx TestClient deprecation warning. No dependency change made.
- `.venv/Scripts/python.exe -m pip check`: no broken requirements.
- Read-only `python -m tools.inspect_inventory_deployment`: separate test project
  false; connection unavailable, so hosted deployment status is unverified.
- `flutter pub get`: succeeded, lock unchanged; `dart format` and `flutter analyze`: clean.
- `flutter test --no-pub`: **90 passed, 2 optional live cases skipped**. The real-font
  390×844 chat capture/interaction test also passed with `CAPTURE_TASKS=true`.
- `flutter build apk --debug --no-pub`: passed with verified task-local Java trust store;
  debug APK at `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

22 new passing backend cases cover typed contracts, own edits/stale writes, retry
identity, rate limiting, deleted privacy, foreign references, replies/reactions,
task conversion service reuse, normalized upload/signing and API authentication.
17 new Flutter tests cover send-state widgets, reactions/edit/delete, reviewed Shopping,
scope validation, private-cache teardown, duplicate/out-of-order invalidations,
pagination, offline restart/manual retry, image upload sequencing/expired permits,
secure-cache registry serialization and task sharing.

Ten new guarded SQL cases are among 46 skipped: ordinary-member access/removal,
cross-household keys, direct grants/forgery, ordering/reactions/outbox rollback,
four conversion kinds, finalized image binding/private topic helper permissions,
and committed concurrent duplicate sends/stale edits. None is live acceptance.
Two optional Flutter live API tests remain skipped without `LIVE_API_BASE_URL`.

## 10. Manual Supabase setup and acceptance

1. Provision a **separate disposable hosted Supabase project**. Set locally
   `HOMECIRCLE_TEST_DB=hosted-test`, `HOMECIRCLE_TEST_PROJECT_REF`,
   `SUPABASE_TEST_DATABASE_URL` (owner/test role), and where needed
   `SUPABASE_TEST_DATABASE_SSLROOTCERT`. Existing target guards reject the app project.
   Never paste secrets or point write-capable tests at production.
2. Review/apply all migrations in order to that test project through the existing
   hosted workflow. Configure the restricted API login and verified TLS. Review
   previous Shopping legacy-data requirements before any later app-project deployment.
3. Verify `chat-attachments` is private with JPEG-compatible size settings. Review
   all Storage/Realtime policies for preexisting broad grants. Disable public Realtime
   channel access. Chat does not require adding raw chat tables to a publication.
4. Enable Supabase Cron and review/run `supabase/operations/chat_realtime_jobs.sql`
   as owner. Inspect existing jobs before scheduling. Monitor pending event age/count
   and Cron failures. Keep tombstones/request identities; do not prune change history
   without designing a cache reset watermark. Configure reviewed private orphan cleanup.
5. Run `python -m pytest -m integration -q` only against this guarded test target.
   Verify trigger syntax, RLS/grants, rollback, real concurrent writes, Storage objects
   and actual outbox acknowledgement on the project's deployed Realtime version.
6. Configure test public project keys/URL in backend/mobile. Use two real Auth users
   and two clients: text/replies/reactions/edit/delete, lost acknowledgements/retries,
   reconnect/missed edits, task sharing/conversion, switch households, sign out,
   remove a connected member, verify no future event delivery or fresh reads.
   Test valid/oversize/malformed images, signed URL expiry and cleanup failures.
7. Check Android picker, keyboard, scrolling, accessibility/text scale, secure storage
   restart/logout and image memory teardown on a physical device. iOS requires Xcode.
   Close M1–4 hosted acceptance gaps before production acceptance/deployment.

No configuration in this list was silently applied to the hosted app project.

## 11. Remaining issues and limitations

Hosted migration syntax, RLS/concurrency, real Storage transfers and private Realtime
delivery/revocation are **implemented but unverified**. A disposable project is the
external blocker. Physical-device/iOS checks, pixel fidelity and operational retention
remain pending. Offline history is bounded and excludes image bytes; expired staging
may require reselecting an image. System-message generation, moderation, receipts,
typing, push and automatic offline synchronization are not implemented.

## 12. Milestone 5 completion status

**Partially Implemented — hosted acceptance pending.** Isolated tests and a debug
build establish implementation evidence, not full acceptance. Do not mark complete
until actual database/Storage/private Realtime and two-client checks pass.

## 13. Readiness for Milestone 6

M6 was not started. The implementation provides a base for future work, but M1–5
acceptance and the operational setup above must be closed before declaring production
readiness. Push notifications, product dashboard and family activity remain later work.
