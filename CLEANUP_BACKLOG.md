# Noma Cleanup Resolution Ledger

Original audit date: 2026-07-18
Resolution snapshot: 2026-07-18

This file is the canonical status ledger for the 22 confirmed consolidations,
cleanups, and correctness gaps. The detailed sections below retain the original
audit evidence as history; the table in this section is the current authority.

## Status Contract

- `done`: implementation and all repository-local proof are complete.
- `external-proof`: repository work is complete, but a named external or manual
  proof cannot be established locally.
- `redeploy-required`: the repository implementation is complete, but the live
  production artifact is older and requires explicit deployment approval.

Priority values retain their original audit meaning:

- `P0`: broken user or release behavior.
- `P1`: high-risk debt or a missing quality gate.
- `P2`: focused consolidation with meaningful maintenance value.
- `P3`: hygiene after higher-value work is stable.

## Resolution Ledger

| ID | Priority | Status | Resolution and remaining proof |
| --- | --- | --- | --- |
| CLN-001 | P0 | `external-proof` | Production runs `delete-account` v4 (`89d6325a...`) with `verify_jwt=true`; Management API inspection binds its `index.ts`, `handler.ts`, and `deno.json` byte-for-byte to the repository, and the v4 route returns the expected unauthenticated `401`. A disposable authenticated-user deletion and its logs remain external proof. |
| CLN-002 | P0 | `external-proof` | Revoke/delete/local-cleanup outcomes are explicit and fail closed. The journal prevents multi-user overwrite, rejects corrupt/future schemas, blocks authentication while cleanup is pending, and covers legacy migration, persistence failure, observer/sign-in races, and relaunch recovery. A production-composition iPhone 16e proof persisted the journal plus scoped task data in the app container, shut the simulator down, booted it, and verified both keys were removed before authentication reopened; a second relaunch was idempotent. Disposable live deletion remains external, and issued access JWTs may remain valid until `exp`. |
| CLN-003 | P1 | `done` | Authentication transitions own notification activation and teardown; adapter tests cover removal, observable add failures, and auth races. |
| CLN-004 | P1 | `external-proof` | Pull requests run `NomaTests`; scheduled UI tests remain separate and workflow YAML parses locally. A deliberately red then green real pull request is external proof. |
| CLN-005 | P1 | `done` | The two original Swift concurrency warnings were removed; final app and test verification is recorded below. |
| CLN-006 | P1 | `done` | Production seed/fixture infrastructure is removed; a missing store loads empty and empty-account tests cover the behavior. Deterministic UI-test seed data is isolated behind `#if DEBUG`, and the final Release binary contains neither harness nor seed markers. |
| CLN-007 | P1 | `done` | Deliberate Swift constants are the single Debug/Release Supabase authority; configuration tests and Release artifact inspection bind the expected URL and key. |
| CLN-008 | P1 | `done` | The no-op tray control is passive and hidden from accessibility; swipe feedback uses the shared haptic authority across task surfaces. |
| CLN-009 | P1 | `done` | Signup is adaptive and scrollable; the localized privacy copy contains its own underlined, enabled accessibility control, exact `/en/` and `/de/` URL mapping is unit-tested, and fresh consent keeps Apple sign-in disabled. EN/DE at default and AX5 pass on iPhone 17 Pro and iPhone 16e. The external page is intentionally not tested because it does not exist yet. |
| CLN-010 | P1 | `done` | All 29 project icons have unique symbols and complete English/German accessibility copy. Final simulator trees expose every option as a localized button, preserve the selected trait, hide the decorative preview, and contain no raw SF Symbol children inside the checked icon buttons. |
| CLN-011 | P1 | `done` | Persistent Create state is store-owned; all store mutations use candidate-state plus commit, and UI/draft effects occur only after successful persistence. |
| CLN-012 | P1 | `done` | A version-1 persistence envelope distinguishes empty, corrupt, unsupported, read, write, and delete outcomes; golden migration and a 7,300-reminder baseline are covered. No database migration decision is implied. |
| CLN-013 | P2 | `done` | Current project APIs are global, legacy day-scoped DTOs are private migration input, and current writes contain no retired keys. |
| CLN-014 | P2 | `done` | Domain models import Foundation only, presentation copy is feature-owned, and one canonicalizer owns project/state uniquing. Legacy data is semantically migratable; new writes intentionally use the v1 envelope. |
| CLN-015 | P2 | `done` | Create and Project Detail share the workspace shell, toolbar, keyboard policy, and atomic completion behavior while feature actions stay separate. |
| CLN-016 | P2 | `done` | One `PrimaryGlassButton` API owns intrinsic/full-width, icon, disabled, and loading variants; Apple presentation remains specialized. |
| CLN-017 | P2 | `done` | Native SwiftUI scroll geometry replaces the UIKit/KVO observer. UI proof covers top, scrolled-away, returned-to-top, portrait-locked device rotation, and same-arguments relaunch. |
| CLN-018 | P2 | `done` | Live product keys are manually authoritative or extractor-owned, stale live keys and two retired keys are gone, and English/German catalog validation is automated. |
| CLN-019 | P3 | `done` | Confirmed dead/pass-through UI artifacts and false extension points are removed; the final symbol scan is empty. |
| CLN-020 | P3 | `done` | Mixed tests are split by production component, one configurable auth spy replaces repeated doubles, and coverage/assertion counts increased. |
| CLN-021 | P3 | `external-proof` | Tracked XcodeBuildMCP defaults are relative and contain no simulator UUID. XcodeBuildMCP 2.6.2 loaded them from an isolated `/private/tmp` copy without explicit project or simulator arguments, resolved that copy's `Noma.xcodeproj` plus an available iPhone 17 Pro, and completed a warning-free build. A fresh checkout on a second Mac remains external proof. |
| CLN-022 | P3 | `external-proof` | Icon Composer is the single source, the empty legacy catalog is removed, and local archive/variant inspection passes. App Store server-side validation remains external. |

## Original Findings

The following evidence, risks, targets, and proof requests are the 2026-07-18
audit snapshot. They explain why each item existed; they do not override the
current status or corrected proof boundaries in the Resolution Ledger.

### CLN-001 - Deploy and prove account deletion

- Evidence: `Noma/Services/Supabase/SupabaseAuthClient.swift:61` calls `delete-account`; `supabase/functions/delete-account/index.ts:14` contains the implementation. A live check of project `ogajkrmbznzpwjxhaxev` on 2026-07-18 returned no deployed Edge Functions.
- Risk: Account deletion currently reaches a missing backend endpoint.
- Target: Deploy the repository version, record its project/version binding, and add a release check that detects a missing function.
- Proof: List the deployed function, delete an authenticated disposable user, verify the old token and a new login no longer work, and inspect function logs.

### CLN-002 - Make deletion and revocation failure-safe

- Evidence: `supabase/functions/delete-account/index.ts:43` ignores the global sign-out result; `Noma/Services/Supabase/SupabaseAuthClient.swift:87` discards the local sign-out error.
- Risk: The UI can report success without proving that server and device sessions were revoked.
- Target: Define explicit outcomes for revoke, delete, and local cleanup; do not silently discard failures.
- Proof: Adapter tests force server revoke, delete, and local sign-out failures. After successful deletion, an old token cannot authorize an operation.

### CLN-003 - Bind notifications to authentication

- Evidence: Scheduling is initiated from `Noma/Features/Home/HomeView+Content.swift:103`; `Noma/NomaApp.swift:30` switches the data scope on auth changes without explicitly clearing pending notifications. Add errors are discarded in `Noma/Services/Notifications/DailyTaskNotificationScheduler.swift:103`.
- Risk: A signed-out or deleted user may continue to receive reminders, while scheduling failures remain invisible.
- Target: Make auth transitions own notification teardown and inject an observable notification-center adapter.
- Proof: A scheduler fake records removal on sign-out and account deletion; add failures follow the chosen error policy.

### CLN-004 - Add the pull-request unit-test gate

- Evidence: `.github/workflows/ci.yml:26` only builds pull requests; unit tests run only after a push to `main` at line 36.
- Risk: Behavioral regressions and broken test code can merge before CI executes the tests.
- Target: Run `xcodebuild test -only-testing:NomaTests` on every pull request. Keep scheduled UI tests separate.
- Proof: A deliberately failing unit test makes a disposable pull request fail, followed by a green run after reverting it.

### CLN-005 - Remove Swift concurrency warnings

- Evidence: `Noma/Services/Notifications/DailyTaskNotificationScheduler.swift:93` resolves an actor-isolated default from a default argument. `NomaTests/DailyTaskGroupTests.swift:22` decodes an actor-isolated conformance from a nonisolated test context.
- Risk: Both warnings become migration blockers under stricter Swift 6 checking.
- Target: Make isolation explicit without changing notification defaults or Codable behavior.
- Proof: Clean app and test builds contain neither warning; focused notification and legacy-decoding tests pass.

### CLN-006 - Remove production mock-data infrastructure

- Evidence: `Noma/NomaApp.swift:10` fixes `usesMockData` to `false`, but the flag remains in `Noma/Services/DailyTasks/DailyTaskGroupStore.swift:20` and `Noma/Services/DailyTasks/DailyTaskGroupStorage.swift:20`; production fixtures live in `Noma/Services/DailyTasks/DailyTaskGroupFixtures.swift:3` and are needed only by a test.
- Risk: The app target still ships a dormant seed-data path after empty accounts became the product behavior.
- Target: Missing persistence always yields an empty state. Test fixtures and seeding live only in `NomaTests`.
- Proof: Empty-store and migration tests pass; no `usesMockData` or `DailyTaskGroupFixtures` symbol remains in the app target.

### CLN-007 - Establish one Supabase configuration authority

- Evidence: URL and publishable key are duplicated in `Noma.xcodeproj/project.pbxproj:415` and `Noma/Services/Supabase/SupabaseClientProvider.swift:26`; the provider only reads the key and falls back to a bundled value at lines 39-45. The current built Info.plist did not contain the expected Supabase entries.
- Risk: Backend migrations require synchronized edits and build settings imply overrides that do not reach runtime.
- Target: Choose either real plist/xcconfig runtime configuration or deliberate Swift constants, with one tested authority and no fallback duplication.
- Proof: Read the built artifact and runtime configuration, then assert both resolve the intended Debug and Release backend policy.

### CLN-008 - Remove non-functional task interactions

- Evidence: `Noma/Components/Input/ReminderInputBar.swift:102` always renders its tray affordance as a button, while `Noma/Features/Home/ProjectDetailTaskSection.swift:34` supplies an empty action. `Noma/Features/Home/HomeView+Content.swift:78` discards swipe-threshold feedback while the other task surfaces provide it.
- Risk: Visible and accessible controls promise actions that do nothing, and the same gesture behaves differently by screen.
- Target: Model the input accessory as explicitly interactive or passive; centralize or make swipe feedback deliberately optional.
- Proof: Accessibility inspection finds no no-op button, and a haptic spy proves the intended behavior on Home, Create, and Project Detail.

### CLN-009 - Make signup layout adaptive

- Evidence: `Noma/Features/Auth/SignupView.swift:81` overlays separate marketing and control stacks in one `ZStack`, without a scroll or adaptive layout fallback.
- Risk: German text, small screens, or accessibility text sizes can overlap or become unreachable.
- Target: Use one adaptive, scrollable layout while retaining the intended visual hierarchy and a reachable login zone.
- Proof: Screenshot and interaction checks on the smallest supported iPhone and iPhone 17 Pro, in German and English, at default and AX5 Dynamic Type.

### CLN-010 - Localize icon accessibility names

- Evidence: `Noma/Features/Create/ProjectIconPickerSheet.swift:24` stores raw SF Symbol names; `Noma/Features/Create/ProjectIconPickerSheetContent.swift:104` exposes those technical names to VoiceOver.
- Risk: Labels such as `dollarsign.circle` are not understandable or localized product copy.
- Target: A typed icon option owns `symbolName` and a localized accessibility label key.
- Proof: Every option has a unique symbol and complete English/German label; inspect the VoiceOver tree in the simulator.

### CLN-011 - Establish one Create state authority

- Evidence: `Noma/Features/Create/CreateView.swift:33` mirrors persistent store data into local state, `Noma/Features/Create/CreateView+CarryForward.swift:3` reloads it manually, and `Noma/Features/Create/CreateView+Submission.swift:279` writes it back through several mutation paths. `Noma/Features/Create/CreateSheet.swift:53` mixes bindings with parallel mutation callbacks.
- Risk: Store and local copies can diverge; every new action must remember the correct save/reload sequence.
- First slice: Inventory each transient and persistent field, then choose one owner for every field. Do not build a second general-purpose store.
- Target: Persistent reminders/projects mutate through store commands; a small feature state owns only draft, focus, selection, and presentation state.
- Proof: Day switch, edit/delete, project mutation, carry-forward, and external store-refresh tests all pass.

### CLN-012 - Introduce an explicit persistence contract

- Evidence: `Noma/Services/DailyTasks/DailyTaskGroupStorage.swift:28` turns decode failure into an empty or legacy state, line 48 silently drops encode failure, and `Noma/Services/DailyTasks/DailyTaskGroupStore.swift:339` writes the complete growing state synchronously from a MainActor store.
- Risk: Corruption is indistinguishable from a new account and can be overwritten; history growth increases launch/save cost.
- First slice: Add a storage protocol, version marker, explicit load/save result, corruption fixture, and a size/performance baseline. Do not choose a new database in the same slice.
- Target: Versioned migration and failure behavior are testable before deciding whether UserDefaults, files, SQLite, or SwiftData should own the data.
- Proof: Golden migration, corrupt payload, write failure, and large-history performance tests produce deterministic results.

### CLN-013 - Remove legacy project API ambiguity

- Evidence: `Noma/Services/DailyTasks/DailyTaskGroupStore.swift:128` exposes `projects(forDayID:)` and `selectedProjectID(forDayID:)` but ignores the day ID. `Noma/Services/DailyTasks/DailyTaskGroupModels.swift:7` retains legacy day-scoped project fields while the current state stores projects globally.
- Risk: Call sites and serialized data imply two project scopes.
- Target: Expose global project APIs and isolate legacy decoding in the versioned migration from CLN-012. New writes contain only the current schema.
- Proof: A legacy golden fixture migrates successfully; a current round trip contains no retired project keys.

### CLN-014 - Separate domain and presentation responsibilities

- Evidence: Project deduplication exists in both `Noma/Services/DailyTasks/DailyTaskGroupStore.swift:364` and `Noma/Services/DailyTasks/DailyTaskGroupStorage+ProjectUniquing.swift:3`. Persisted `TaskProject` lives in `Noma/Features/Create/TaskProject.swift:1` and imports SwiftUI, while localized Home copy lives in `Noma/Services/DailyTasks/DailyTaskGroupModels.swift:99`.
- Risk: UI, persistence, and domain changes pull each other into unrelated diffs.
- Target: Pure shared domain models and invariants; feature-specific presentation adapters; exactly one project-uniquing implementation.
- Proof: Domain tests compile without SwiftUI imports and existing Codable fixtures remain byte/semantic compatible as required.

### CLN-015 - Consolidate the task workspace shell

- Evidence: Keyboard observation, focus, safe-area composer layout, and toolbar structure are repeated in `Noma/Features/Create/CreateView.swift:60`, `Noma/Features/Home/ProjectDetailView.swift:23`, `Noma/Features/Create/CreateView+Submission.swift:296`, and `Noma/Features/Home/ProjectDetailView+Content.swift:86`.
- Risk: Keyboard and spacing fixes must be duplicated and can drift.
- Target: After CLN-011, extract a narrow shared shell/modifier for keyboard and composer geometry plus reusable toolbar content. Keep feature actions separate.
- Proof: Both screens preserve identical keyboard transitions, layout geometry, filter behavior, and complete-all behavior.

### CLN-016 - Consolidate glass primary actions

- Evidence: `Noma/Components/Buttons/PrimaryGlassButton.swift:3`, `Noma/Features/Create/CreateView.swift:203`, and `Noma/Features/Create/AddProjectSheetContent.swift:93` independently implement the same glass CTA. `Noma/Features/Create/CreateSheet.swift:75` reuses the date-picker-specific button for project creation.
- Risk: Misleading ownership and small style differences accumulate across sheets.
- Target: One shared intrinsic/full-width glass action with optional icon, disabled, and loading states. Keep Apple-branded presentation as a specialized wrapper.
- Proof: Component previews or screenshots cover intrinsic, full-width, disabled, loading, and long localized labels; both sheets pass smoke tests.

### CLN-017 - Replace the UIKit/KVO scroll observer

- Evidence: `Noma/Features/Home/HomeView.swift:30` inserts a sentinel while `Noma/Features/Home/HomeScrollOffsetObserver.swift:4` traverses UIKit superviews, observes KVO, and retries attachment on a timer. The app targets iOS 26.
- Risk: The behavior depends on private SwiftUI hierarchy and timing.
- Target: Use native SwiftUI scroll geometry and remove the sentinel and observer bridge.
- Proof: Existing header-visibility tests plus UI checks for top, scrolled, returned-to-top, rotation, and reopen.

### CLN-018 - Make localization extraction authoritative

- Evidence: The catalog contains 58 `stale` entries that are still dynamically referenced, including `create.project.add.title`, `home.empty.title`, and `signup.title`. Two stale keys appear genuinely unused: `create.project.empty.add-button` and `settings.appearance.mode`.
- Risk: A normal catalog cleanup could delete live translations because extraction state is misleading.
- Target: Adopt one extractor-friendly or explicitly manually managed localization API; then remove only proven unused keys.
- Proof: Re-extraction leaves no live key marked stale, every product key has English and German values, and both locales pass a smoke test.

### CLN-019 - Delete confirmed dead and pass-through artifacts

- Evidence: Candidate dead types include `Noma/Components/Sheets/EmptyNavigationSheet.swift:3`, `Noma/DesignSystem/NomaDesignTokens.swift:66` (`NomaGradient`), and `Noma/Features/Create/TaskProject.swift:76` (`TaskProjectStatsCopy`). `Noma/Components/Input/ReminderInputBar.swift:152` writes `inputHeight` without reading it. `Noma/Features/Create/CreateReminderSubmission.swift:304` returns reminders unchanged, while `Noma/Features/Create/CreateView+Submission.swift:166` defines a capability that is always true.
- Risk: False extension points and tautological tests make the code harder to navigate.
- Target: Reconfirm references after CLN-015/016, then delete unused symbols, state, keys, and tests that assert markers instead of behavior.
- Proof: Symbol/reference scan, catalog validation, build, and full unit suite pass with no replacement abstractions added.

### CLN-020 - Reorganize tests and auth doubles

- Evidence: `NomaTests/NomaTests.swift` has 635 lines across unrelated features; `NomaTests/DailyTaskGroupTests.swift` also contains reminder UI-policy tests; `NomaTests/AuthStateManagerTests.swift:149` begins several repetitive `AuthClient` stubs.
- Risk: Contract changes require repetitive edits and coverage ownership is difficult to see.
- Target: Split tests by production component and replace repeated auth stubs with one configurable spy. Preserve assertions before adding new behavior.
- Proof: Test count and assertions do not decrease; new account-deletion and notification failure paths are covered.

### CLN-021 - Make XcodeBuildMCP configuration portable

- Evidence: `.xcodebuildmcp/config.yaml:3` contains an absolute user path and line 7 contains a local simulator UUID.
- Risk: A fresh clone or another Mac inherits invalid machine-specific defaults.
- Target: Track only project-relative, machine-independent defaults; keep local path/device overrides ignored.
- Proof: A fresh checkout can select an available simulator and build without editing the tracked file.

### CLN-022 - Establish one AppIcon authority

- Evidence: `Noma/Assets.xcassets/AppIcon.appiconset/Contents.json:2` declares slots without filenames while `Noma/AppIcon.icon/icon.json:58` contains the real Icon Composer source; both are presented to the asset build.
- Risk: Ownership is unclear and deleting either source without an archive proof could break variants or submission.
- First slice: Inspect the compiled archive and Light/Dark/Tinted variants; record which input supplies the final icon.
- Target: Retain one proven source and remove the empty legacy authority only after archive validation.
- Proof: Archive has no asset warnings, variants render correctly, and App Store validation passes.

## Current Verification Snapshot

Current implementation and proof state on 2026-07-18:

1. Xcode Beta 27.0 (`27A5218g`) ran the complete `NomaTests` target on iPhone
   17 Pro: **172 passed, 0 failed, 0 skipped**. The only build warnings are the
   expected AppIntents metadata notices for an app without AppIntents.
2. The canonical UI suite passed **4/4** on iPhone 17 Pro. It covers Signup,
   Create, Project Detail, Home scrolling/rotation/relaunch, keyboard geometry,
   both locales, icon accessibility, long labels, and control states. The
   Signup EN/DE x default/AX5 matrix also passed **1/1** on iPhone 16e.
3. The normal, non-harness app composition then built, installed, and launched
   successfully on iPhone 17 Pro. Its runtime logs contain no error, fault,
   crash, or fatal entry; direct AXe inspection confirms the final Signup tree.
   The live browser mirror is `http://localhost:3200/`.
4. A separate production-composition recovery proof on iPhone 16e wrote a
   `requestInFlight` deletion journal and scoped task payload directly into the
   stopped app container, fully shut down and rebooted the simulator, and then
   launched Noma normally. The container preferences were empty after startup,
   direct AXe inspection showed Signup with no cleanup error, consent at `0`,
   and Apple sign-in disabled only by consent; a second terminate/relaunch kept
   the container empty.
5. An isolated current-tree copy at `/private/tmp/noma-portability-proof` loaded
   the tracked relative XcodeBuildMCP defaults with no explicit project path or
   simulator UUID. XcodeBuildMCP 2.6.2 resolved that copy's project and the
   available iPhone 17 Pro, then completed its Debug simulator build with no
   warnings or errors.
6. A fresh unsigned Release archive succeeded at
   `/private/tmp/Noma-cleanup-final-20260718-2116.xcarchive`; Xcode ran its local
   `-validate-for-store` bundle check. The archive contains an arm64 `LAM.Noma`
   app, version 1.1 build 2, minimum iOS 26.0, English/German localization, and
   the intended Release Supabase URL/key.
7. The Release executable contains no UI-test harness symbol, launch argument,
   deterministic seed string, or seed UUID. `Assets.car` contains 1024-pixel
   default, dark, and tintable AppIcon renditions; exported phone and iPad icons
   are 120 and 152 pixels.
8. Deno format, lint, frozen type-check, and all **8/8** Edge Function handler
   tests pass.
9. Supabase reports production function v4 as `ACTIVE`, with
   `verify_jwt=true` and SHA `89d6325a...`; Management API source inspection
   matches its three runtime source/config files exactly to the repository. A
   v4 log records the expected unauthenticated `401`; this does not replace an
   authenticated deletion proof.
10. `git diff --check`, String Catalog JSON, Xcode Cloud JSON, workflow/config
   YAML, TOML, project-plist, and shell syntax checks pass. Dead-symbol and
   removed-harness scans return no current-tree production matches.

The five remaining external proofs are intentionally not collapsed into
`done`: disposable authenticated deletion (CLN-001/002), a real red/green pull
request (CLN-004), a second-Mac checkout (CLN-021), and App Store Connect
server-side validation (CLN-022). Per the
latest product decision, the not-yet-existing Privacy Policy webpage is not a
current verification requirement.

## Future Incremental Work Template

Use this only for a future item that is reopened after this consolidated pass:

```text
Implement exactly CLN-### from CLEANUP_BACKLOG.md.

Read the Resolution Ledger and original audit history before editing. Preserve
unrelated dirty-worktree changes. Make the smallest change that closes the
named remaining proof or regression, add focused coverage, run the full local
verification applicable to the change, and update only that ledger row. Report
changed files, exact proof results, and any external uncertainty.
```
