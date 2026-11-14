# Milestone 3 implementation and verification

Updated 14 November 2026 (Asia/Karachi). **Partially Implemented — hosted acceptance pending.** The implementation and isolated checks described below are complete. The SQL migration has not been deployed or validated against PostgreSQL, and real signed-in Auth/API/Storage acceptance remains outstanding. Milestone 4 has not started.

## Implemented behavior

Repair, Chore and General requests use real household-scoped FastAPI endpoints. Shopping is reserved in the data model and disabled in the interface. Tasks support create/edit, archive/restore, assignment/unassignment, atomic ownership claims, four priorities, five statuses, due dates, calendar-based overdue indicators, search, type/status/priority/assignee/date/overdue/archive filters, sorting, pagination and summary counts. Completed and cancelled tasks require an explicit reopen to Open. Completion notes and previous terminal state remain in activity history.

Task discussions support text comments, author/admin edits and deletion, private task/comment photos, paginated history and actor display names. All actors come from verified identity. Former members have a fallback label; membership removal clears assignments and records an activity event through a database trigger.

Repairs can link to active inventory in the same household. Inventory details show related repairs and provide a prelinked create action. Completing a repair does not write inventory. After completion, the user may explicitly confirm a separate revision-protected change of a linked durable item to Working. A failure in that separate operation leaves the repair completed and displays an accurate error.

## Flutter and design sources

The implementation retains Feature-First MVVM, Provider, ChangeNotifier, Dart `http`, GoRouter, Material 3 and the existing shared HomeCircle theme. Localized English strings live in the ARB resources. No production mock records or new package dependencies were added for M3.

The supplied exports were located in the `UI` folder after the user's correction. The initial default file search missed them. Reference files inspected:

- `UI/tasks_requests_overview/{screen.png,code.html}`
- `UI/create_task_household_request/{screen.png,code.html}`
- `UI/task_repair_details/{screen.png,code.html}`
- Supporting states under `UI/task_empty_state/`, `UI/selection_bottom_sheet/` and `UI/modal_confirmation_dialog/`; the shared design system is `UI/warm_household_modern/DESIGN.md`.

Overview uses three count cards, horizontal request-type choices, search/filters and task cards with type icons, priority/status pills, assignee and due date. Create/edit uses a two-column request-type selector, white section cards, priority choices, horizontal member initials, a tinted repair section with the real inventory picker, photos and fixed save/discard controls. Details uses a header card, a two-column information grid, grouped actions, private attachment controls, discussion bubbles/composer and a collapsible activity log. Shared five-tab navigation is retained.

The exports are adapted to the working app: no demo avatars/photos, fabricated teamwork banner, push-notification promises or time-of-day fields. The shared application font/theme is retained rather than importing the exports' web fonts. Some action placement and form ordering differ to expose the implemented revision, archive and offline controls. This is a responsive design adaptation, not a pixel-identical reproduction. Real-font test captures at 360 × 800 were inspected for overview/form/details. Real device, accessibility scaling and iOS visual acceptance remain pending.

## Data model and migration

New migration: [`20261114000000_tasks.sql`](../supabase/migrations/20261114000000_tasks.sql). Apply all earlier migrations in order, including inventory access migration `20261113000000_inventory_access.sql`.

| Relation | Purpose |
| --- | --- |
| `public.household_tasks` | Type, title/description, priority/status, creator/updater, assignee, date/location, optional inventory link, completion/cancellation/archive timestamps and revision |
| `public.task_comments` | Task/household-bound text, author, timestamps, soft deletion and comment revision |
| `public.task_attachments` | Task/optional comment, uploader, generated JPEG path, MIME/size and soft deletion |
| `public.task_activity` | Trusted actor, action, timestamp and before/after changes |
| `private.task_uploads` | User-bound expiring upload permits and finalization state |

Composite foreign keys bind assignees, inventory, comments and attachments to their household/task. Repair-only inventory links and allowed type/priority/status values are constrained. Indexes cover household/status, assignment, due dates, linked items and child pagination. Trigger-maintained revisions/timestamps protect task state. System membership-removal events use a nullable actor.

The migration adds member-scoped RLS and narrowly granted helpers. `authenticated` may read household records but cannot directly mutate task tables. The restricted `homecircle_api` role writes with verified transaction-local claims. Ordinary members can manage tasks; comment mutation and photo removal require the author/uploader or a household admin. The migration tightens the reserved repair bucket's broad foundation read policy; inventory and other reserved bucket policies are preserved.

**Deployment is unknown.** The read-only catalog diagnostic could not connect (`connection_unavailable`); no migrations or production data were changed. Source review and skipped integration tests do not validate migration syntax, privileges or actual RLS execution.

## API contract

All paths below start with `/api/v1/households/{household_id}` and require a verified bearer token and current membership.

| Method/path | Behavior |
| --- | --- |
| `GET /tasks`, `POST /tasks` | Filtered page / create request |
| `GET /tasks/summary` | Household status and overdue counts |
| `GET /tasks/{id}`, `PATCH /tasks/{id}` | Detail including archived / edit |
| `DELETE /tasks/{id}`, `POST /tasks/{id}/restore` | Archive / restore |
| `PATCH /tasks/{id}/assignment` | Assign, unassign or claim |
| `PATCH /tasks/{id}/priority`, `PATCH /tasks/{id}/status` | Change priority / transition or explicitly reopen |
| `GET/POST /tasks/{id}/comments` | Page / add comment |
| `PATCH/DELETE /tasks/{id}/comments/{comment_id}` | Author/admin edit / soft delete |
| `GET /tasks/{id}/activity` | Paginated activity |
| `GET/POST /tasks/{id}/attachments` | Page metadata / upload photo |
| `GET /tasks/{id}/attachments/{attachment_id}/url` | Authorized 60-second signed download URL |
| `DELETE /tasks/{id}/attachments/{attachment_id}` | Uploader/admin removal |
| `GET /inventory/{item_id}/tasks` | Related repair tasks |

Writes require `expected_revision`, except creation. Comment edits/deletes additionally require `expected_comment_revision`. DELETE revisions use query parameters. Stale writes return 409; the client retains drafts and asks for refresh rather than silently rebasing. Pagination is bounded to 100 rows/page; sortable SQL expressions are allowlisted. Search is parameterized with escaped LIKE wildcards. Flutter supplies its local calendar date as `as_of` for consistent overdue queries; external callers default to UTC.

## Security, transactions and photos

The repository uses Psycopg 3/raw SQL and the existing pool/transaction identity boundary. A household parent lock checks current membership without requiring ordinary members to update household settings. Task locks serialize claims and edits; revision comparisons and activity inserts share the same transaction. Comment/photo mutations also advance the parent revision. An activity failure rolls back its associated database mutation. These properties have isolated tests; actual PostgreSQL concurrency remains unverified.

Photos are decoded, checked and re-encoded as metadata-free JPEG using the existing inventory validator: JPEG/PNG/WebP input, 5 MiB and 16 MP limits. The API also bounds photo JSON to 8 MiB before parsing, including chunked requests. Each object uses `<household>/<task>/<attachment>.jpg` in private `repair-attachments`; no overwrite or service-role credential is used. Comment photo uploads require author/admin authorization. A task has at most 50 visible attachments.

The backend commits a 60-second user-bound permit, then rechecks authorization/revision before finalizing metadata and activity. Failures compensate through best-effort Storage API cleanup. Finalization prevents deleting an in-flight object. Uploader/admin cleanup applies only to finalized, unreferenced objects. Archived task photos are retained for restore; deleted-comment objects lose active read authorization and require cleanup retention. Crashes/outages/revocation can leave private orphans; no scheduled retention worker is shipped.

Download URLs are requested using the verified user's token after scoped metadata authorization. URL responses are `no-store`; signed URLs exist only in view-model memory and expire after 60 seconds. An already issued signed URL can remain usable until expiration following revocation/archive/deletion. Do not promise immediate revocation of such a URL. Task activity is feature history, not the future M6 family activity feed.

## Offline and scope boundaries

Fetched task pages/details, summaries, comment/activity/attachment metadata and related repair views are cached under both user and household keys. Only visited pages/views are available. Form and comment drafts are local; edited task drafts retain the revision originally read. Photos and signed URLs are not persisted. Calendar parameters do not prevent access to a previously cached list on the next day; cached results are labeled and may be stale.

Offline writes are never queued or automatically replayed. Explicit failed saves retain drafts. Successful writes invalidate relevant cache entries. Scope changes clear visible state/URL memory and generation checks reject late reads/writes from another scope. Authorization failures clear affected caches instead of falling back. Previously downloaded household data cannot be remotely erased while a device is disconnected; these preferences are application-scoped storage, not an encrypted offline vault.

## Executed verification

| Check | Actual result |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Passed; no locked dependency upgrades |
| `flutter analyze` | Passed, no issues |
| Full `flutter test --no-pub --dart-define=CAPTURE_TASKS=true` | **58 passed, 2 skipped**; 19 M3 tests included |
| Task-only test suite after design adaptation | **19 passed** |
| Dart formatting | Passed |
| `ruff check app tests tools` | Passed |
| `ruff format --check app tests tools` | Passed, 49 files |
| Backend `python -m pytest -q` | **146 passed, 29 skipped**; one existing Starlette/httpx deprecation warning |
| `python -m pip check` | Passed |
| `flutter build apk --debug --no-pub` | Passed; existing task-local Java trust store, TLS verification enabled; APK not device/live acceptance |
| Hosted catalog diagnostic | Connection unavailable; no deployment assertion |

`backend/tests/test_tasks.py` covers service transitions, stale revisions, competing claims with isolated locks, rollback, input/actor forgery rejection, comment boundaries, API dispatch/filters and photo signing/upload/removal/failure/body limits. Flutter tests cover actual client payloads through a test-only HTTP server, all three request kinds, overview/search/filter/form/detail actions, comments/photos, explicit inventory confirmation and failure, stale drafts, duplicate-submit prevention, offline next-day reading and household switching/late responses.

Nine new cases in `backend/tests/test_tasks_integration.py` cover actual member/outsider/direct-write boundaries, cross-household references, explicit inventory updates, comment author/admin rules, member-removal assignment, SQL rollback, private Storage metadata policies and committed concurrent claim/edit behavior. They are among the **29 skipped** tests, alongside existing M1/M2 guarded cases. Metadata fixtures do not exercise real Storage byte transfers. No write-capable integration checks ran against the app project.

## Files and acceptance gates

New task code is under `backend/app/{api/v1,repositories,schemas,services}/` and `mobile/lib/features/tasks/{models,services,repositories,viewmodels,views,widgets}/`. Other integration changes mount the router, add the body-limit middleware, wire runtime/Provider/GoRouter/localization, show related repairs from inventory and extend the read-only deployment diagnostic. Inventory's Storage transport gained an optional JSON body for signing; its existing photo flow is preserved. New tests and the migration are listed above. README, architecture, security, milestones and PROJECT_STATUS are updated. Pre-existing M0–2 changes were preserved.

Before marking M3 Completed:

1. Configure the separate disposable hosted project using the guarded variables in PROJECT_STATUS. Apply pending migrations there with verified TLS and run all guarded tests. Establish the app project's actual migration history separately; never assume local SQL has been deployed.
2. Verify two signed-in users, ordinary-member task writes, outsider/revoked membership denial, concurrent claims/edits, member removal, archived restore, and cross-household inventory/comment/photo isolation against real SQL.
3. Exercise real task and comment image bytes through Auth → FastAPI → Storage: upload, sign/download, expiration, remove, comment deletion, archive/restore and orphan cleanup. Configure the public Storage project key and API database/JWT settings; keep secrets local.
4. Close M1 email confirmation/recovery/deep-link/session and two-household acceptance; complete M2 hosted RLS/quantity/photo acceptance. A missing management UI is recorded separately from the database permissions boundary.
5. Run configured Android device/picker/offline/household-switching acceptance and review text scaling; iOS requires macOS/Xcode. Debug compilation is not signed release or live acceptance.

Milestone 3 remains **Partially Implemented — hosted acceptance pending**. This report
records the M3 handoff. M4 was subsequently implemented at the user's request and is
covered in [the M4 report](milestone-4-report.md). Current acceptance status is in
[PROJECT_STATUS.md](PROJECT_STATUS.md).
