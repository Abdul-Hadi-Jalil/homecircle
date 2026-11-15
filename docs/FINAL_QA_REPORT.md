# HomeCircle final QA and Android release assessment

14 November 2026, Asia/Karachi. Milestone 7 local engineering report.

The 16 November deployment follow-up records the live Render API, applied migrations
and a rebuilt development APK with the hosted URL. Artifact hashes and deployment
gaps below describe the 14 November assessment. Full acceptance testing remains
pending. [Current project status](PROJECT_STATUS.md#hosted-deployment-and-apk-16-november)

## A. Executive summary

**Not Release Ready. Milestone 7 remains partially implemented.** Local backend and
Flutter checks pass. Unsigned release APK/AAB builds succeed. Real Auth, disposable
database/RLS/Storage, two-client Realtime, Firebase and production signing acceptance
remain open. Current release builds omit runtime defines and open the configuration
screen. Their role is build verification. Distribution requires configured rebuilds.

The initial working tree was clean on `main` at `820ea80`. M0–6 implementation
reports, status, architecture/security/setup records, SQL migrations, layered APIs,
Flutter modules, Stitch exports, locked dependencies and Android configuration were
reviewed before edits. All 25 Stitch exports are directly under `UI/`.

## B. Milestone reassessment

Classification applies to the evidence explicitly named. “Verified Working” below
means executed local isolated behavior where stated. Live service acceptance is
separately classified to avoid treating a fake transport as deployed integration.

| Milestone | Current completion status | Evidence and remaining acceptance |
| --- | --- | --- |
| 0 | Completed foundation | Reproducible Flutter/Python environments, analysis, HTTP/router/provider and pool lifecycle checks pass. Production deployment remains a release gate. |
| 1 | Partially Implemented | Auth/household implementation and isolated tests exist. Real confirmation, recovery, session renewal, invitation and revocation acceptance remain open. |
| 2 | Partially Implemented | Inventory screens/API, decimal quantities, photos, cache/drafts and local tests exist. Hosted SQL/concurrency/Storage acceptance remains open. |
| 3 | Partially Implemented | Tasks/repair integration, comments/photos/claims/status and local tests exist. Live SQL/Storage and device repair acceptance remain open. |
| 4 | Partially Implemented | Shopping, purchase history and stock idempotency implementation/tests exist. Real transactional and multi-client acceptance remains open. |
| 5 | Partially Implemented | Chat, private invalidation, sharing/conversion and local tests exist. Real two-client Realtime/private Storage acceptance remains open. |
| 6 | Partially Implemented | Dashboard/activity/notification/preferences/FCM implementation and local tests exist. Dedicated dashboard/activity Realtime remains incomplete. Firebase and worker delivery are unverified. |
| 7 | Partially Implemented | Confirmed local defects repaired, quality checks run, unsigned Android builds prepared and operational reports added. External release gates remain. |

### Feature evidence inventory

| Area | Classification | Evidence / limit |
| --- | --- | --- |
| Flutter startup, Feature-First MVVM, Provider, GoRouter, HTTP client | Verified Working | App/widget tests, analysis and Android builds. HTTP transport has bounded reads, fresh bearer lookup and explicit writes. |
| FastAPI startup, settings, pool lifecycle and restricted-role rejection | Verified Working | `test_api`, `test_config`, `test_pool`, `test_security` with isolated dependencies. |
| Supabase project configuration and hosted restricted-role startup | Implemented but Unverified | Prior foundation acceptance exists. Current hosted catalog/migration state remains unconfirmed. |
| Environment management and localization foundation | Verified Working | Lock resolution, format/analysis, settings and generated localization. Whole-app Urdu coverage is incomplete. |
| Registration, email verification, login, recovery and SDK session restoration | Implemented but Unverified | Form/auth/session tests pass. Real email, PKCE callback, renewal and Android account acceptance are pending. |
| Logout, session scope restoration, household switching and profile management | Verified Working | Isolated tests including failed device revocation and duplicate start. Live Auth/device behavior remains pending. |
| Create/join household, invitations, multiple memberships, admin/member controls | Implemented but Unverified | Service/widget tests pass. Guarded hosted tests are skipped. |
| Role/member-removal management UI | Missing | SQL functions exist. Dedicated management controls are absent. |
| Inventory CRUD, consumable/durable types, search/filter, categories, thresholds, conditions, activity | Verified Working | Backend and Flutter isolated tests pass through normal service/viewmodel/UI entry points. |
| Inventory photo lifecycle, concurrent quantities and household RLS | Implemented but Unverified | Validation/transport tests pass. Hosted upload/download/cleanup and locking tests remain unexecuted. |
| Inventory cached reading and saved drafts | Verified Working | Scoped offline/stale-response tests pass. Device persistence/security acceptance remains pending. |
| Task CRUD, repair/chore/general types, priorities, status, due dates, assignments and claims | Verified Working | Backend/Flutter isolated task tests pass. |
| Task comments, linked inventory repairs, attachments and activity | Implemented but Unverified | Local service/UI tests pass. Real Storage and relational trigger behavior remain pending. |
| Task concurrent edits/claims and offline cache/drafts | Implemented but Unverified | Scoped cache/draft tests pass. Real competing transaction tests are skipped. |
| Shopping quick add, shared list/task detail integration, quantities, priority, assignment, purchase/undo/history | Verified Working | Backend/Flutter isolated shopping tests pass. |
| Optional inventory adjustment, duplicate prevention and household isolation | Implemented but Unverified | Ledger implementation and local tests exist. Exact 0.5 L + 5 L guarded acceptance was added and skipped without its disposable database. |
| Chat send/history/pagination, replies/reactions, edit/delete, photo attachment, task sharing/conversion | Implemented but Unverified | API/service/widget tests pass. Real multi-user message and Storage acceptance remain pending. |
| Chat duplicate prevention, subscription cleanup and offline drafts | Verified Working | Isolated scope, retry/deduplication and draft tests pass. Real server/outbox behavior needs hosted acceptance. |
| Chat private Realtime reception and active membership revocation | Implemented but Unverified | Recipient-scoped SQL/outbox implementation and fake Realtime tests exist. Two-client acceptance remains pending. |
| Dashboard summary, Needs Attention ordering, upcoming tasks and quick actions | Verified Working | Aggregate/repository shape and widget tests pass. Actual database output accuracy remains pending. |
| Unified activity, persistent notifications, read states and preferences | Implemented but Unverified | Local API/viewmodel/widget tests pass. Trigger projection and recipient RLS remain unexecuted. |
| Dashboard/activity dedicated Realtime | Partially Implemented | Refresh fallbacks exist. Dedicated live invalidation is incomplete. |
| FCM registration, push delivery, notification deep links and multi-household destinations | Implemented but Unverified | Fake push and authenticated lookup tests pass. Firebase configuration and native live delivery are absent. |
| Android release signing, approved launcher/splash and Play privacy declarations | Missing | Secure signing inputs are implemented. Owner credentials/assets/legal declarations are pending. |

No remaining feature is classified Broken solely because an external service is
unconfigured. Confirmed failures and their fixes are recorded in the issue register.

## C. Fixes and changed files

- Active Profile now exposes localized notification settings, and profile save refreshes
  session profile data. `mobile/lib/features/household/views/membership_views.dart`.
- Session startup avoids duplicate subscriptions. Logout reaches identity clearing and
  Auth sign-out despite device revocation, Realtime or local-cache cleanup errors.
  `mobile/lib/features/household/viewmodels/session_view_model.dart`.
- Chat composer actions move above the input at narrow widths or large text. The
  320-pixel/200% failure found by the new regression is resolved.
  `mobile/lib/features/chat/views/family_chat_screen.dart`.
- Secondary/error colors use approved Stitch `#444654` / `#BA1A1A`. White-surface
  contrast improves from 4.02 / 3.40 to 9.33 / 6.46 respectively, with exact measured
  values retained in local audit output and a 4.5-to-1 regression assertion.
  `mobile/lib/core/theme/app_theme.dart`.
- Mobile configuration rejects URL queries/fragments and Supabase paths. Release mode
  requires HTTPS. `mobile/lib/core/config/app_config.dart`.
- All API mutation bodies are bounded before parsing, preserving photo upload limits.
  `backend/app/core/photo_body_limit.py`.
- Production disables schema/docs exposure. `/ready` probes database availability with
  sanitized failures and no-store responses. `backend/app/main.py`.
- API connection options bound statement, lock and idle-transaction waits. Configurable
  defaults are documented in `backend/.env.example`, `backend/app/core/config.py` and
  `backend/app/db/pool.py`.
- Secure existing-keystore signing support and blank example configuration were added.
  Version `1.0.0+2` was selected for this candidate. The package ID was retained pending
  owner confirmation. `mobile/android/app/build.gradle.kts`,
  `mobile/android/key.properties.example`, `mobile/pubspec.yaml`, `.gitignore`.
- Regression coverage was added in `backend/tests/test_release_hardening.py`,
  `backend/tests/test_release_integration.py`, `backend/tests/test_pool.py`,
  `backend/tests/test_shopping_integration.py`, `mobile/test/release_config_test.dart`,
  `mobile/test/accessibility_test.dart`, `mobile/test/hub_test.dart` and
  `mobile/test/session_view_model_test.dart`.
- Documentation deliverables include this report, the release checklist, known issues,
  deployment guide and updates to README, project status, architecture, security,
  setup and milestone records. Dependency lock versions were retained.

## D. Tests and actual results

| Command / check | Result |
| --- | --- |
| Baseline backend `python -m pytest -q` | 219 passed, 56 skipped |
| Final backend `python -m pytest -q` | 226 passed, 58 skipped, one upstream Starlette warning |
| `python -m ruff check app tests` | Passed |
| `python -m ruff format --check app tests` | Passed, 71 files |
| `python -m pip check` | Passed |
| `flutter pub get --enforce-lockfile` | Passed at baseline and final verification, locks retained |
| Baseline Flutter tests | 107 passed, 2 skipped |
| Final Flutter tests with capture defines | 115 passed, 2 skipped |
| `flutter analyze --no-pub` | No issues |
| Dart format check | Passed after final formatting |
| Narrow/large-text matrix | Home, Inventory, Tasks, Chat and Profile at widths 320, 390, 480, height 900, text scale 2 passed |
| Production schema/docs, bounded ordinary bodies, `/ready` | Passed in isolated API tests |
| Every protected API operation rejects absent bearer | Passed for all 85 operations in generated inventory |
| Five-actor SQL matrix and exact oil purchase retry scenario | Added, skipped because the disposable project is unconfigured |
| Private-key/service-role tracked-source scan | Limited scan executed. See security assessment |
| SQL parser audit | All 12 migration files / 371 top-level statements parsed. Catalog resolution, grants and RLS execution remain unverified |
| Signing guard dry runs | Dummy partial configuration rejects release. Debug task graph succeeds. An initial debug run was interrupted while freeing Gradle memory, then rerun successfully |

Local raw logs and generated screenshots are retained under ignored `.tmp/m7-*`,
`.tmp/tasks-*.png` and `.tmp/inventory-*.png`. Reproduce checks with the deployment
guide. Skipped Flutter live API tests require an intentionally configured API endpoint.

### Flows A–F

| Flow | Executed coverage | Live acceptance remaining |
| --- | --- | --- |
| A — Family setup | Auth validation/routes, session/profile, invitation service and household switching isolated tests | Real registration/confirmation/recovery, invitation redemption and two-account isolation |
| B — Inventory to shopping | UI/service tests for stock/purchase/explicit adjustment/retry. Guarded 0.5 L + 5 L = 5.5 L scenario added | Execute SQL transaction/ledger test and full device workflow against disposable services |
| C — Repair | Form/link/assignment/comment/status tests. Completion requires a separately confirmed inventory condition update | Upload real photo, verify SQL activity and complete workflow on device |
| D — Chat | Replies/reactions, pagination, send deduplication, sharing and conversion tests with fake transport | Two real clients, private Realtime delivery, photo lifecycle and retry idempotency |
| E — Notifications | Assignment projection expectations, fake FCM, preferences, read actions and authenticated destination resolution | Real SQL event generation, worker delivery, background/terminated taps and token rotation |
| F — Scope switching | Late response rejection, old-household mutation denial, cache/draft isolation and logout tests | Active membership revocation and device switching with hosted services |

## E. Security assessment

Verified isolated checks cover signatures/issuer/audience/expiry/roles, protected
routes, strict input shapes, sanitized errors, restricted startup role, local actor
transactions, rollback, scoped client state and credential-key rejection. Repositories
retain parameterized values and allow-listed query construction. Inventory/task
revision locks, stock application ledgers and chat/task conversion identities remain
in the existing transaction design.

SQL source review retains current-membership RLS, ordinary-member lock helpers,
cross-household foreign keys, fixed function search paths, restricted grants, private
Storage policies and recipient-scoped chat/notification workers. Hosted semantics
remain **Implemented but Unverified**. The new five-user test uses admin/member,
other-household participant, dual member and authenticated nonmember with rollback.
Existing integration tests cover other module isolation, rollback and concurrency.

The limited tracked-file scan checks private-key blocks and decodable service-role
JWTs. It does not replace a comprehensive secret-history audit. Private local files,
keystores, Firebase configuration and build outputs remain ignored. No production
database migration, write-capable app-project test or release publication was run.
M7 creates no database migration. Existing migration deployment cannot be inferred
from repository files.

## F. Performance and UI assessment

The shared Stitch design specification and screen exports were reviewed against
existing Flutter modules and test captures for dashboard, tasks, shopping, chat,
notifications and family activity. The application retains its five-tab navigation,
Material 3 theme and existing architecture. Captures show adapted layouts with
different typography, density and photo treatment from the references. Exact visual
acceptance remains open, especially inventory form/details and native branding.

Measured text contrast and the three-width large-text matrix justified the color and
composer fixes. The matrix covers major tabs with fixture data. It does not establish
TalkBack order, all touch targets, every form/keyboard/detail state, translated layouts
or device font rendering. Approved Android launcher/splash assets remain outstanding.

Current APIs already bound pagination, dashboard sections and cache sizes. No speculative
query rewrite or cache redesign was introduced. Live API latency percentiles, database
EXPLAIN evidence, release scrolling frame times and representative memory measurements
remain unavailable pending a populated test environment. Cold-launch measurements,
where available, describe startup only and cannot establish household workflow speed.

## G. Android build and installation evidence

Candidate package `com.homecircle.homecircle`, label HomeCircle, version `1.0.0`, code
`2`. APK metadata reports minimum SDK 24, target SDK 36 and compile SDK 36. Installed
tooling includes Android API 37, build-tools 36.0.0 and JDK 21 with Java target 17.

| Artifact | Build command | Classification |
| --- | --- | --- |
| `mobile/build/app/outputs/flutter-apk/app-release.apk` | `flutter build apk --release --no-pub` | Unsigned, missing runtime defines, configuration-screen build verification |
| `mobile/build/app/outputs/bundle/release/app-release.aab` | `flutter build appbundle --release --no-pub` | Unsigned, missing runtime defines, build verification |
| `mobile/build/app/outputs/flutter-apk/app-debug.apk` | `flutter build apk --debug --no-pub --dart-define-from-file=config.local.json` | Development-signed, local public configuration, debug acceptance only |

Release signing credentials and Firebase native configuration are absent. APK
signature verification reports missing signing metadata as expected for the unsigned
artifact. A signed production AAB has not been produced. Starter launcher/splash
resources remain. Build warnings include future Firebase built-in Kotlin support,
Cupertino font expectations and upstream Java deprecations. All locked versions were
preserved. Artifact hashes and installation/launch measurements are recorded in the
final evidence addendum below after the final build checks.

### Final artifact and emulator evidence

| Artifact | Bytes | SHA-256 |
| --- | --- | --- |
| Unsigned release APK | 62,609,796 | `46261b3e9ab90a376ffe7016cdc003378756fbf6701b07b1b62adbecff17a1ef` |
| Unsigned release AAB | 60,450,067 | `58c106cc7bb78790b665ce36d6d4c91c6ccca637a43bc812cb7981f2043a1280` |
| Development-signed debug APK | 175,843,709 | `b870132dadcc715188ce8373fa23dcd2528118581255f328076ad4d690baa1db` |

`apksigner verify` reports missing `META-INF/MANIFEST.MF` on the release APK.
`jarsigner -verify` reports the AAB is unsigned. These expected verification failures
establish the signing limitation. Partial signing configuration fails with a sanitized
message, while the same dummy alias permits the debug task graph to configure.

The initial running emulator disconnected before installation. Its existing API 37
AVD was restarted without wiping data. `adb install -r` succeeded and `am start -W`
returned `Status ok`, with onboarding visible. Two debug cold starts reported Android
activity times of 6654 ms and 6513 ms. Startup PSS observations were 351,870 KiB and
351,461 KiB. These debug/emulator observations include a resource-constrained host
and do not establish release performance or full Flutter interactive startup time.

The emulator showed System UI and Pixel Launcher ANR dialogs. Host free physical
memory was observed at 462,484 KiB during overlapping builds and a 4 GiB emulator.
Idle Gradle cleanup released some memory and a clear onboarding frame was captured,
but launcher hangs recurred. After dismissing the hung launcher and releasing build
memory, onboarding-to-login navigation succeeded and the login form rendered cleanly.
Full responsive-device acceptance remains unverified. No HomeCircle fatal exception
appeared in the sampled recent logcat,
which covers a bounded window only. Device app data was preserved. Evidence images
remain in `.tmp/m7-emulator*.png`; the clear onboarding capture is
`.tmp/m7-emulator-final.png`. The final login frame is retained in the repository.
[Android login evidence](images/milestone-7-login.png)

## H. Release blockers

Open P1 gates are disposable SQL/RLS/Storage/concurrency acceptance, migration history,
real M1 Auth/household acceptance, two-client chat, Firebase/worker delivery, configured
production HTTPS builds, approved signing and full device flows A–F. No confirmed
unresolved P0 defect was found locally. These gaps prevent production acceptance.
[Known issues](KNOWN_ISSUES.md)

## I. Manual configuration

Provide the separate disposable Supabase project, real test accounts and intended
Firebase Android project/worker credentials through local secret storage. Confirm
package/name/version, public HTTPS API configuration, callback allow-list, private
buckets/Realtime and Cron configuration. Supply the existing owner-approved signing
keystore and standalone Android branding assets. Prepare privacy/Play declarations.
Production migration and Play publication require separate authorization.
[Deployment guide](DEPLOYMENT_GUIDE.md), [Release checklist](ANDROID_RELEASE_CHECKLIST.md)

## J. Smallest next actions

1. Configure the disposable project and Firebase, then run the guarded suite without
   skips and complete two-device flows A–F, including active revocation.
2. Confirm deployed migration/grant history and resolve all P1 findings from real
   service acceptance. Finish dedicated hub Realtime if required for v1.0 acceptance.
3. Complete visual/accessibility/performance acceptance with approved assets and
   populated test households. Record measured latency, frame and memory results.
4. Confirm identity/version, supply HTTPS public runtime configuration and existing
   release signing inputs, rebuild, verify certificate fingerprints and test signed
   installation. Complete privacy and Play declarations.
5. Review the release checklist and obtain explicit production migration/publication
   approval only after release-blocking gaps are closed.

M7 stops at this assessment. Milestones 1–7 remain open at their stated acceptance
gates. No later milestone was started.
