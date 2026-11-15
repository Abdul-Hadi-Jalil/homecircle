# Known issues and release gates

Updated 16 November 2026. HomeCircle is **Not Release Ready**. Priorities describe
release impact. External acceptance gaps remain gates even when isolated tests pass.

| ID | Priority | State | Issue and next action |
| --- | --- | --- | --- |
| QA-01 | P1 | Open | Local test setup is prepared and WSL/Docker are installed. The user deferred full testing on 16 November. When resumed, start Docker and the isolated stack, then verify normal-member edits, simultaneous updates, five account situations and removed-member access. Actual SQL tests remain unexecuted. See LOCAL_TESTING.md. |
| QA-02 | P1 | Open — deployment verified, behavior pending | All 12 hosted migrations are applied as of 16 November. Catalog checks confirm module tables, the inventory access helper, selected RLS flags, private buckets and restricted roles. Storage transfers, actual multi-user RLS/concurrency and private Realtime acceptance remain pending. |
| QA-03 | P1 | Open | Real registration, confirmation, recovery, renewal and household invitation acceptance remain incomplete from M1. Exercise flow A with two test accounts and verify logout/revocation on both clients. |
| QA-04 | P1 | Open | Firebase Android configuration and worker credentials are absent. Verify foreground/background/terminated delivery, token rotation, denied permission, account handoff and notification navigation. |
| QA-05 | P1 | Open — hosting resolved | API is live at https://homecircle-api.onrender.com with healthy database readiness. The current installable debug APK uses that fixed address. Production signing, owner identity/version confirmation and release-signed acceptance remain pending. The earlier unsigned release artifacts still represent the 14 November build. |
| QA-06 | P1 | Open | Flows A–F have partial isolated coverage, with live multi-user/device acceptance pending. SQL skips provide no executed authorization or concurrency evidence. |
| QA-07 | P2 | Open | Dedicated dashboard/activity Realtime from M6 is incomplete. Lifecycle, explicit and periodic refresh provide current fallback behavior. |
| QA-08 | P2 | Open | Starter Android launcher/splash assets remain. Stitch screenshots reference branding, but a standalone approved Android asset set was not recovered. Confirm branding assets before distribution. |
| QA-09 | P2 | Open | UI implements adapted Stitch layouts. Exact typography, image treatment, spacing and all form/detail states still require visual acceptance. Three-width large-text tab checks cover a subset of accessibility. TalkBack, keyboard/form coverage, physical-device and full semantics checks remain. |
| QA-10 | P2 | Open | Production latency, database query plans, scrolling frame timings and representative memory usage have no live baseline. Measure populated test households on a profile build before performance acceptance. |
| QA-11 | P2 | Open | Edge-level general rate limiting, request concurrency limits, monitoring, backups/restore drills and Storage orphan retention require deployment configuration. Invitation/chat limits exist in the application. |
| QA-12 | P2 | Open | Profile role/member-removal management UI is absent although SQL management functions exist. Verify owner-operated revocation and last-admin protection. |
| QA-13 | P2 | Open | Privacy policy and Google Play declarations require owner review. Document photos, messages, notifications, account deletion and retention accurately. |
| QA-14 | P3 | Open | Installed Firebase Core emits future built-in Kotlin migration warnings. Release builds also warn about unused Cupertino font expectations and upstream Java deprecations. Locked dependencies were retained. |
| QA-15 | P3 | Open | Upstream Starlette warns about the httpx-backed TestClient. Current tests pass using the requested httpx stack. |
| QA-16 | P2 | Fixed | Active Profile lacked the notification preferences action. The normal Profile route now has a localized action with widget coverage. Profile save refreshes session data. |
| QA-17 | P2 | Fixed | Chat composer overflowed at 320 pixels with 200% text. Its action toolbar moves above the text field for narrow/large-text layouts. |
| QA-18 | P2 | Fixed | Secondary/error text contrast was insufficient. Approved Stitch on-surface-variant/error colors now meet 4.5 to 1 on both app surfaces in a regression test. |
| QA-19 | P2 | Fixed | Ordinary API write bodies lacked a pre-parser size bound. All mutating methods now have a 64 KiB cap while photo endpoints retain 8 MiB. |
| QA-20 | P2 | Fixed | Production OpenAPI remained exposed after disabling docs. Production now disables both. Readiness probes check the database and sanitize errors. |
| QA-21 | P1 | Fixed in isolated tests | A synchronous device cleanup failure could abort logout before clearing identity. Logout now reaches local identity clearing and Auth logout despite cleanup failures. |
| QA-22 | P2 | Fixed | Repeated session start could create duplicate Auth subscriptions. A start guard prevents repeated restoration/subscription. |
| QA-23 | P2 | Fixed | Mobile URL validation accepted query/fragment configuration and local HTTP in release mode. Release configuration requires HTTPS, clean URLs and a Supabase origin. |
| QA-24 | P2 | Open | API 37 emulator displayed System UI and Pixel Launcher ANR dialogs during debug acceptance. Host free memory dropped below 500 MiB while builds and the 4 GiB emulator overlapped. Installation and onboarding launch succeeded, but responsive-device/performance acceptance needs a stable emulator or physical device. |

No confirmed unresolved P0 defect was found in this audit. The unexecuted security
acceptance gates prevent a claim that the application is free of P0 defects.

[Final QA report](FINAL_QA_REPORT.md) · [Release checklist](ANDROID_RELEASE_CHECKLIST.md)
