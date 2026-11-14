# Milestone 4 — Shared Shopping List

Updated 14 November 2026 (Asia/Karachi). Implementation uses the existing household
task system and inventory module. **Partially Implemented — hosted acceptance
pending.** No app-project database writes or migrations were performed. M5 was not
started. Current executed check results are in [PROJECT_STATUS.md](PROJECT_STATUS.md).

## Functionality and architecture

Shopping requests are `household_tasks` with `task_type='shopping'`. The parent owns
title/notes, household, creator, assignee, priority, status, revision, timestamps and
activity. One `shopping_item_details` row holds requested quantity/unit, the optional
inventory link, current purchase UUID/quantity/actor/time/price/currency and stock
application time. There is no second shopping status or duplicate task per request.

Ordinary members can add/edit, assign/unassign, claim, purchase, undo/reopen, cancel,
search/filter/sort, paginate and read purchase history. Quantity and unit are optional
for quick add. Linked consumables default to their existing unit; incompatible units
are rejected rather than converted. Durable links can be recorded but cannot receive
a quantity increase. Closed requests must be reopened before editing or reassigning.
Cancelled requests can also explicitly reopen through the undo/reopen action.

The UI maps Open to To Buy, In Progress to Being Handled, Completed to Purchased and
Cancelled to Cancelled. Blocked keeps its existing task meaning. Purchasing assigns
the verified actor, a server-generated purchase UUID and timestamp, advances the
parent revision and records a trusted task event. Actual purchased quantity can differ
from the requested quantity. Price is optional and requires a supported currency.
Undo clears current purchase metadata but retains the original purchase event; it
does not subtract inventory. A later purchase receives a different UUID.

FastAPI retains Router → Service → Repository, Pydantic v2, Psycopg 3/raw parameterized
SQL and the restricted existing pool. Flutter retains Feature-First MVVM,
Provider/ChangeNotifier, Dart `http`, GoRouter, shared task priority/status enums,
member/inventory selectors and the existing HomeCircle theme. The existing guarded
task cache repository now accepts a namespace; shopping reuses it with `shopping`.
No dependencies were added or upgraded for M4.

## Database and security

New forward migration: [`20261114000001_shopping.sql`](../supabase/migrations/20261114000001_shopping.sql).
It requires all M0–3 migrations. Earlier migrations are unchanged.

Existing outstanding/cancelled Shopping parents receive empty details with their
task IDs and revisions preserved. The migration checks for completed legacy
Shopping parents before creating tables. Those require reviewed purchase attribution
because the missing metadata cannot be reconstructed reliably.

- `shopping_item_details` has a unique task parent, composite household foreign keys,
  exact numeric quantities/prices, supported units/currencies and purchase-metadata
  checks. Deferred constraint triggers check both parent and detail changes: a
  Shopping parent must have a detail, other task types must not, and Completed must
  agree with purchase UUID/actor/time and the parent's completion timestamp.
- `shopping_inventory_applications` stores each purchase UUID at most once, together
  with household/task/inventory IDs, exact quantity and verified applying actor. It
  survives undo and later purchase cycles. Triggers validate the current completed
  purchase/link/quantity and agreement with the detail's application timestamp.
- Both tables enable RLS. Current household members may read; direct `authenticated`
  mutations are denied. The restricted API role has member-scoped insert/update grants,
  immutable ownership and verified purchase/application actor checks. Cross-household
  links are rejected. No service-role credentials are used.
- Generic task creation/edit/assignment/priority/archive routes continue to reject
  shopping operations that belong to its dedicated API. Generic task status changes
  delegate to shopping-aware purchase/reopen logic, preserving the same metadata
  invariants instead of bypassing them. Direct task detail links redirect to the
  shopping details screen.

Quantities are Decimal/NUMERIC, up to 12 whole digits and 3 decimal places, positive
when supplied. Prices allow 13 whole digits and 2 decimal places, including zero.
Non-finite and excessive values are rejected. Responses encode exact numeric fields
as strings. Supported inventory units: `piece`, `pack`, `kg`, `g`, `L`, `mL`, `bottle`,
`box`, `roll`. The explicit currency allowlist is PKR, USD, EUR, GBP, AED, SAR, INR,
CAD, AUD, JPY and CNY. This is a purchase annotation, not a currency conversion or
expense-management feature.

## Transactions, inventory and concurrency

The existing household membership lock precedes parent/detail locks. Creation,
purchase/undo, assignment, revision and activity changes commit together. Every
mutation except creation requires an expected parent revision. A stale request is
rejected with 409. Concurrent claims/purchases have one winning transition; the
client reloads authoritative state and retains unsaved drafts.

Purchasing never changes stock. Inventory details open a prefilled Add to List form,
requiring confirmation. Linked requests have advisory duplicate checking with View
Existing and Add Another choices; separate requests are permitted and never silently
merged. The check is not a uniqueness or security constraint.

After a purchase succeeds, an explicit follow-up offers Update Inventory or Not Now.
`apply-inventory` locks the task/detail and current inventory, validates active
consumable/unit/quantity, then uses the existing inventory adjustment calculation and
write/activity path. Quantity increase, persistent ledger insert, application timestamp,
task revision and task activity share one transaction. The ledger links trusted
inventory changes to the purchase. Retrying the same purchase returns confirmed
already-applied success without adding quantity again, even with its original revision.
An old UUID cannot affect a reopened or later repurchased request. No conversions are
invented. Failed application rolls back that transaction and leaves the independently
committed purchase intact. The UI displays immediate failure feedback and provides a
retry from details. Undo always leaves physical stock untouched.

## API

All paths begin `/api/v1/households/{household_id}/shopping` and require verified
bearer identity and current household membership.

| Method/path | Purpose |
| --- | --- |
| `GET /`, `POST /` | Filtered/paginated combined records; atomic parent/detail creation |
| `GET /summary` | Active, purchased, high/urgent outstanding, assigned-to-me and progress |
| `GET /history` | Paginated historical purchase events, including purchases later undone |
| `GET /{task_id}`, `PATCH /{task_id}` | Combined detail; revision-protected edit |
| `POST /{task_id}/claim` | Atomic verified-user claim |
| `PATCH /{task_id}/assignment` | Assign/unassign with same-household member validation |
| `POST /{task_id}/purchase` | Complete with optional actual quantity, price/currency and note |
| `POST /{task_id}/undo-purchase` | Explicit reopen, preserving history and existing stock |
| `POST /{task_id}/cancel` | Cancel an outstanding request |
| `POST /{task_id}/apply-inventory` | Explicit atomic/idempotent stock application; requires purchase UUID |

The root endpoint has no trailing slash in the client. Filters include search,
priority, assignment (all/me/unassigned), member, linked inventory, archive scope,
view (all/active/purchased/cancelled) and allowlisted sorting. Pages are bounded to
100 rows. Summary uses the same search/priority/assignment/link/archive scope,
ignoring the active/purchased display view. Its denominator is active + purchased;
cancelled rows are excluded, the scope is all time, and an empty list reports zero.
History uses the same record scope and retains original purchase title/quantity/price
snapshots. Default history excludes archived tasks; the archive filter selects those
explicitly. A cancelled/reopened request does not erase a historical purchase event.

## Flutter screens, designs and offline behavior

Shopping stays a secondary route; the five tabs remain unchanged. Home links to
Shopping, task overview includes Shopping requests, the task create tile opens the
shopping form, and inventory details can prefill a linked request.

The list implements real progress, To Buy/Purchased sections, checkboxes, priority,
requester/assignee/purchaser/timestamp, search, filters, pagination and quick add.
The compact form provides optional quantity/unit, priority chips, notes, inventory
selection and member assignment. Purchase uses a keyboard-safe confirmation sheet
with optional actual quantity/price/currency/note. Details expose claim/reassignment,
edit, purchase, undo/cancel and explicit inventory application/retry; history is paged.
Loading, failure/retry, empty, all-purchased, filtered-empty and cached states exist.

Design sources: `UI/shared_shopping_list/{screen.png,code.html}` and
`UI/add_shopping_item/{screen.png,code.html}`, plus the shared design system. These
were inspected and adapted to real data, supported units and the existing app theme.
No demo names/counts, live-sync indicators, push notifications, aisle grouping,
voice entry, auto-stock claims or fabricated suggestions were copied. Real-font
widget captures of the list/form/purchase sheet were reviewed; exact pixel fidelity,
device picker/keyboard/accessibility scaling and iOS acceptance remain pending.

At the user's request, all 25 screen folders were moved directly under `UI/`.
Four byte-identical design-system copies were consolidated to
`UI/warm_household_modern/DESIGN.md`. Every original file's content hash was checked
against its destination; only three duplicate copies were removed. Report paths were
updated. No app feature code was moved into `UI`.

Fetched list/details/summary/history are cached under user + household + shopping
keys. Form drafts retain their original edit revision, and inventory-prefilled drafts
have an item-specific key to preserve the selected inventory item. Only fetched views/pages are
available offline. Photos and shopping write queues are not introduced. Offline saves
retain drafts and never claim server success. Reconnect does not replay writes.
Authorization errors clear affected cache; stale/foreign-household responses are
rejected. Scope changes clear visible records and invalidate pending operations.
Application preferences are not an encrypted offline vault and cannot discover remote
revocation while disconnected.

Secure realtime publication/private channels are not configured or accepted. M4
implements manual/pull refresh and refresh on application resume. Another member's
change becomes visible after a refresh or reopening the screen; no instantaneous
collaboration claim is made. No shopping Realtime subscription exists to leak across
scopes. Full Family Chat, Notifications and Dashboard were not implemented.

## Verification and remaining gates

| Command/check | Executed result |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Passed, locked versions retained |
| `flutter analyze` | Passed with no issues |
| `flutter test --no-pub --dart-define=CAPTURE_TASKS=true` | 73 passed, 2 optional live checks skipped |
| Shopping Flutter cases in the final full suite | 15 passed |
| `ruff check app tests tools` | Passed |
| `ruff format --check app tests tools` | Passed, 55 files |
| `python -m pytest -q` | 173 passed, 36 guarded database cases skipped |
| Shopping-only backend suite | 27 passed |
| `python -m pip check` | Passed |
| `flutter build apk --debug --no-pub` | Passed using the existing Java trust store with verified TLS |

Pytest emits the existing Starlette/httpx deprecation warning. Database tests are
skipped because the separate disposable hosted project is unconfigured.

See PROJECT_STATUS for final executed totals, analyzer/lint/build outcomes. New
backend tests cover inputs/precision/currency/identity, quick add, links/units,
revision and claim/purchase conflicts, undo history, persistent application retries,
rollback, generic task status bridging, summary denominator and HTTP contracts.
Flutter tests cover models/progress, duplicates, explicit purchases/stock/undo,
inventory failure/retry, cached list/history/drafts, no replay, stale edits,
household switching/late responses, malformed scope responses and widget flows.

Seven guarded SQL cases were added: ordinary-member CRUD/RLS and outsider denial;
cross-household/nonshopping/metadata constraints; purchase/stock/undo/history/summary;
actual rollback; and concurrent claim, purchase and stock-application cases. They use
the existing target guard and a separate disposable hosted project. Most roll back;
concurrency fixtures commit generated IDs and clean only those IDs. They have not run
because that project is not configured. Isolated tests do not prove PostgreSQL
constraint triggers, actual RLS or concurrency. The new migration remains undeployed
and unvalidated against a database.

Before completion: configure the disposable project, apply all M0–4 migrations in
order, run the guarded integration suite, and exercise two real users through
Auth → FastAPI → SQL. Verify 0.5 + 5 = 5.5 and safe retries, actual quantity changes,
undo after stock application, member removal and household switching. Close M1
email/session/household and M2–3 hosted acceptance gaps. Review configured Android
and iOS/keyboard/text scaling. No new external credentials are required beyond the
existing Auth/API/database configuration. Realtime remains an explicit limitation.

M4 is **Partially Implemented — hosted acceptance pending**. M5 is **Not Started**;
full acceptance readiness requires these security/integration gates. No M5 work began.

Main changed files include `backend/app/{api/v1,repositories,schemas,services}/shopping.py`,
the forward migration, shopping backend tests, `mobile/lib/features/shopping/`,
`mobile/test/shopping_test.dart`, runtime/Provider/router/localization, inventory
entry point, task navigation/status bridge/cache namespace and this report. README,
architecture, security, milestones and PROJECT_STATUS are also updated.
