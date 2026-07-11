# Plan: SwiftlyCodeEdit scope closure and quality hardening

## Context

MILESTONE1_CHECKLIST.md and MILESTONE2_CHECKLIST.md are marked 100% complete, but an independent
three-agent audit (architecture map, SCOPE.md compliance audit, bug hunt) found the claims are
partly rationalized rather than verified. Confirmed gaps against docs/SCOPE.md: Find/Replace menu
items are dead at runtime (they send `NSTextView.performFindPanelAction` to a `TextView` that is a
plain `NSView` and never responds); the app still identifies as "CodeEdit" everywhere except
README; themes are hardcoded `NSColor` palettes in `PlainSyntaxHighlighter.swift` instead of data
files; Kate syntax XML is compiled into the bundle so users cannot add languages without
rebuilding; the shipped Clean Text is trailing-whitespace-trim only while a destructive unwired
cleaner (`PlainTextCleaner`, maps every codepoint above U+00FF to `?`) carries the unit tests;
Liquid Glass is only legacy `.regularMaterial`; and the shell is AppKit, not SwiftUI. Three HIGH
bugs exist in the live path: paste prefers a stale internal buffer over the system pasteboard,
non-UTF-8/16 files silently open blank while the status bar reports "UTF-8", and every keystroke
triggers a full-document rehighlight plus full relayout (lag risk that contradicts the SCOPE speed
requirement). This plan closes the SCOPE gaps, fixes the bugs, and re-verifies every previously
claimed milestone item with recorded evidence.

User decisions locked for this plan: port the CodeEditSourceEditor find panel; define a new
simple YAML/JSON theme format; migrate aggressively to full SwiftUI (DocumentGroup replacing
NSDocument); delete the dead legacy trees.

"Full SwiftUI" boundary, revised by user decision 2026-07-09: SwiftUI-first, Swift-native,
AppKit only as a last-resort escape hatch. Default SwiftUI for everything (lifecycle, document
scenes, Commands menu, all chrome, settings, panels); prefer a Swift-native implementation over
wrapping AppKit; AppKit is acceptable only when a specific user-facing behavior cannot be
achieved reliably in SwiftUI or pure Swift (IME/text-input edge cases, native undo integration,
accessibility gaps, responder-chain behavior), and every such use is isolated behind a
replaceable adapter so it can be swapped out when SwiftUI catches up. AppKit must never be the
app architecture: after MS, NSDocument/NSMenu/NSWindowController/delegate-chain patterns
anywhere outside the isolated editor-surface adapter are defects. "Less AppKit is better" is
the north star; zero AppKit is not pretended practical today.

## Status tracker

- M1 (decide and net) CLOSED 2026-07-10: WP-S0 (document architecture: `NSDocument` behind an
  `NSDocumentController`-under-App bridge, architect-approved), WP-S0c (text engine: FAIL
  confirmed, TextKit adapter stands), WP-L0 (contract plus four expected-fail lifecycle tests),
  WP-Q5 (keystroke harness; corrected end-to-end baseline p95 15233 ms on the 1 MB fixture, git
  028868f) - all spec review and quality review passed.
- M3 (lifecycle correctness) CLOSED 2026-07-10: all four lifecycle audit findings closed
  (F1-F4); zero expected-fail markers remain suite-wide (swift test: 134 tests, zero known
  issues); smoke SMOKE_EXIT=0.
- Also closed with review: WP-S1 (SwiftUI shell flip), WP-S2 (Commands menu, including the
  multi-window routing fix), WP-F2 (theme loader), WP-F3 (user syntax), WP-F4 patch 1
  (clean-text transforms), WP-F1 (find/replace panel port - patch 18, plus patch 19 deleting
  `Packages/CodeEditSourceEditor`, 199 files) - both patches passed spec review 2026-07-10.
- Dispatchable now: WP-Q6 measurement + review in flight; WP-S4 (shell deletion) next after a
  human commit checkpoint; then WP-Q2, WP-G1/G2 and the WP-G0 smoke-capture integration patch.
- WP-L0: COMPLETE. Document state contract plus four expected-fail Swift Testing lifecycle
  tests (`CodeFileDocumentLifecycleGapTests.swift`, pinning WP-L1..WP-L4) written into
  [document_architecture_decision.md](../active_plans/decisions/document_architecture_decision.md); both
  spec review and quality review passed.
- WP-S0: status pointer below (see the WP-S0 work package entry) is extended to record the
  architect's bridge-mechanism decision - document windows host through `NSDocumentController`
  under a plain SwiftUI `App` (not `DocumentGroup`), with `CodeFileDocumentBridge.swift` as the
  single sanctioned document-layer AppKit boundary.
- WP-S0c: COMPLETE. Re-validation verdict FAIL confirmed on the same toolchain (keystroke p95
  513.30 ms vs the 16 ms gate); the TextKit/AppKit editor adapter stands. Decision doc:
  [text_engine_decision.md](../active_plans/decisions/text_engine_decision.md).
- WP-Q5: COMPLETE. Corrected end-to-end keystroke baseline p95 15233 ms on the 1 MB fixture
  (git 028868f); spec review and quality review passed.
- WP-F5: COMPLETE 2026-07-10. Settings scene (patches 15-16) plus live-apply observability seam;
  full review PASS (Cmd+, scene, persisted keys, `SETTINGS_APPLIED` fontSize/theme gates in the
  smoke script, DEBUG self-test seam, in-memory theme registry, `defaults` domain unpolluted).
- WP-G0: COMPLETE 2026-07-10 (new enabler package). DEBUG-only TCC-free window self-capture seam
  (`-PlainEditor.captureWindowTo`, `WINDOW_CAPTURE_WRITTEN` marker, temp-then-swap write); spec and
  quality review PASS; smoke-script integration deferred to a follow-up patch. Note for
  WP-G1/WP-G2: default capture renders dark mode and clears the 3-hue floor at the minimum - force
  light appearance for the gated light capture.
- WP-L1: COMPLETE 2026-07-10. Spec review and quality review closed, unblocking WP-L2. Audit
  finding F1 closed; EditedTextChange two-case Sendable notification delivered for M8.
- WP-L2: COMPLETE. Five-row external-change matrix, F2 closed, `e2e_external_change_conflict.py`
  added; review PASS (one data-loss finding in `resolveExternalChangeConflict` was found in
  review and fixed in the WP-L3 patch, re-reviewed PASS).
- WP-L3: COMPLETE. Reload decode errors surfaced, clean+undecodable matrix row wired, F3 and F7
  closed, encoding reload test added; review PASS.
- WP-L4: COMPLETE. Post-reload undo-stack reset via the `.fullInvalidation` observer, F4 closed,
  undo-ownership documented in docs/CODE_ARCHITECTURE.md; review PASS.

## Objectives

- Every docs/SCOPE.md must-have feature is implemented and validated in the live app.
- All HIGH and MEDIUM bugs found in the audit are fixed with regression tests on the live code path.
- Every previously claimed checklist item is independently re-verified with recorded evidence, and rationalized claims are corrected.
- The app shell is SwiftUI (DocumentGroup lifecycle, SwiftUI Commands menu) with the AppKit `TextView` bridge as the only deliberate AppKit boundary.
- The app identifies as SwiftlyCodeEdit end to end and ships in a proper .app bundle.
- The command ribbon and status bar adopt macOS 26 Liquid Glass (`glassEffect`) styling per docs/LIQUID_GLASS.md, with dense editor content untouched.

## Design philosophy

Verification before construction: milestone V re-audits the claimed-complete checklists and fixes
the correctness bugs before any architecture change, so the SwiftUI migration lands on a
baseline whose behavior is proven, not asserted (fix the design, not the symptom). The rejected
alternative was migrating to SwiftUI first and building features on the final architecture in one
pass; that risks breaking the working save/autosave/external-change path with no independent
evidence baseline to detect the regression. Features land after the migration so Find/Replace,
themes, and syntax loading are wired once, to the final shell, not twice.

## Scope

- Re-verify all MILESTONE1_CHECKLIST.md, MILESTONE2_CHECKLIST.md, and APP_INTENTS_SMOKE_TEST_GOAL.md claims with recorded evidence; correct rationalized items.
- Fix the clipboard paste bug, the silent-blank non-UTF encoding bug, the smoke-script honesty gaps, and the double `finishPlainEditorLaunch()` call.
- Delete the destructive `PlainTextCleaner`, its tests, and all dead code in the active target; delete excluded legacy trees and unused packages with `git rm`.
- Rename the product to SwiftlyCodeEdit (executable, menus, window titles, About) and package a real .app bundle with Info.plist and tagline.
- Migrate the app shell to SwiftUI: DocumentGroup + ReferenceFileDocument, SwiftUI Commands menu, keeping the `TextView` NSView bridge.
- Port the CodeEditSourceEditor find panel for in-document Find/Replace with a regex toggle.
- Define a YAML/JSON theme data format, ship bundled default themes, and load user themes from Application Support.
- Load user Kate syntax XML from Application Support at runtime, layered over the 409 bundled definitions, no rebuild required.
- Build a Clean Text menu of safe, Unicode-preserving cleaning actions (trim trailing whitespace, normalize line endings, ensure final newline, tab/space conversion, safe Unicode punctuation normalization as an explicit opt-in).
- Make highlighting and status recomputation incremental or bounded so typing in large files does not lag; add a performance gate.
- Apply `glassEffect` Liquid Glass styling to the command ribbon and status bar; keep the editor surface stable; validate light, dark, reduced-transparency, and increased-contrast modes with captured evidence.

## Non-goals

- Build no terminal, Git integration, LSP, or workspace/IDE surfaces (SCOPE non-goals).
- Add no autocomplete or plugin system (SCOPE low priority; needs explicit approval).
- Support no cross-platform targets or macOS versions below 26.
- Rewrite no text-engine internals of `CodeEditTextView` beyond what the find-panel port and performance work require.
- Edit docs/SCOPE.md in no way (user-owned document).

## Current state summary

Active build: pure SwiftPM executable `CodeEdit` (`Package.swift`, swift-tools-version 6.3,
macOS 26), AppKit shell (`@main enum CodeEditMain` in `CodeEdit/CodeEditApp.swift`, hand-built
`NSMenu`, `NSDocument` subclass `CodeFileDocument` creating an `NSWindow` + `NSHostingView`).
Editor chain: `CodeFileDocument -> WindowCodeFileView -> CodeFileView -> PlainTextEditorView`
wrapping `CodeEditTextView.TextView`. Status bar values are real and live. Highlighting: Kate XML
interpreted by `KateContextRuleInterpreter` in `Packages/CodeEditSyntaxDefinitions` (409 bundled
XML files), applied by `PlainSyntaxHighlighter` with hardcoded colors. Tests: 5 Swift package
smoke suites (one covering a dead engine), Python repo-hygiene suite, and
`scripts/plain_editor_smoke.sh`. Reference clones live in `OTHER_REPOS/` (read-only reference,
notably CodeEditSourceEditor's find panel). Both milestone checklists claim completion; audit
evidence contradicts several claims.

## Architecture boundaries and ownership

Durable components (code identifiers use these, never milestone names):

- `app-shell`: app lifecycle, menu commands, window scenes (`CodeEdit/CodeEditApp.swift`, future SwiftUI App files).
- `document`: file load/save/autosave/external change (`CodeEdit/Features/Documents/CodeFileDocument/`).
- `editor-bridge`: SwiftUI-to-TextView bridge (`CodeEdit/Features/Editor/Views/PlainTextEditorView.swift`).
- `chrome`: command ribbon + status bar (`CodeEdit/Features/Editor/Views/CodeFileView.swift`, `PlainEditorStatusReporter.swift`).
- `highlighting`: Kate engine + span application (`Packages/CodeEditSyntaxDefinitions/`, `PlainSyntaxHighlighter.swift`).
- `theming`: new theme format loader and token-color mapping (new files under `CodeEdit/Features/Theming/`).
- `find`: ported find/replace panel (new files under `CodeEdit/Features/Find/`).
- `cleaning`: text cleaning actions (`CodeEdit/Features/Editor/PlainEditorTextCleaner.swift` and successors).
- `validation`: smoke script, App Intents hooks, package tests (`scripts/`, `CodeEdit/Features/SmokeTesting/`, `CodeEditTests/PackageSmoke/`).

### Mapping (milestones / workstreams -> components / patches)

| Milestone / Workstream | Component | Expected patches |
| --- | --- | --- |
| MV / WS-V1 audit | validation | 1-2 (evidence report, checklist corrections) |
| MV / WS-V2 bug fixes | app-shell, document, validation | 2-3 |
| MV / WS-V3 test realignment | highlighting, cleaning, validation | 1-2 |
| MP / WS-P1 legacy purge | all (deletions) | 2-3 |
| MP / WS-P2 identity | app-shell, validation | 1-2 |
| MS / WS-S1 SwiftUI shell | app-shell, document, editor-bridge | 3-4 |
| MS / WS-S2 revalidation | validation | 1 |
| MF / WS-F1 find | find, editor-bridge | 2-3 |
| MF / WS-F2 theming | theming, highlighting | 2 |
| MF / WS-F3 syntax dirs | highlighting | 1-2 |
| MF / WS-F4 cleaning | cleaning, chrome | 1-2 |
| MQ / WS-Q1 highlight perf | highlighting | 2 |
| MQ / WS-Q2 status perf | chrome | 1 |
| MG / WS-G1 glass | chrome | 1-2 |
| MG / WS-G2 release evidence | validation, docs | 1-2 |

## Milestone plan

| M | Title | Summary | Goal |
| --- | --- | --- | --- |
| MV | Verification and stabilization | Independently re-check every claimed checklist item and fix the correctness bugs found in the audit | A trusted, evidence-backed baseline |
| MP | Purge and identity | Delete dead legacy trees and rename the product to SwiftlyCodeEdit in a real .app bundle | A clean repo that ships under its own name |
| MS | SwiftUI architecture | Replace the AppKit shell with SwiftUI DocumentGroup and Commands, keeping only the TextView bridge | Modern SwiftUI architecture per SCOPE |
| MF | Scope features | Find/Replace, data-file themes, user syntax directories, safe Clean Text menu | Every SCOPE must-have implemented |
| MQ | Performance | Incremental highlighting and bounded status recomputation with a measured gate | No typing lag on large files |
| MG | Liquid Glass and release | glassEffect chrome polish, accessibility-mode evidence, docs and release close-out | Polished macOS 26 native finish |

### Milestone: MV verification and stabilization

- Depends on: none.
- Workstreams: WS-V1, WS-V2, WS-V3.
- Entry criteria: none.
- Exit criteria: verification report artifact exists listing every previously claimed item as CONFIRMED / CORRECTED with evidence; WP-V2..WP-V5 bug fixes merged with regression tests; `swift test`, `pytest tests/`, `./build_debug.sh`, `./scripts/plain_editor_smoke.sh` all pass with output captured under `test-results/`; obvious follow-ons (changelog entries, checklist corrections) completed.
- Parallel-plan ready: yes (WS-V1, WS-V2, WS-V3 run concurrently; WS-V1 is read/report-only).

### Milestone: MP purge and identity

- Depends on: MV exit (need trusted baseline before mass deletion so smoke regressions are attributable).
- Workstreams: WS-P1, WS-P2.
- Entry criteria: MV exit criteria met.
- Exit criteria: `git rm`-based deletion of all excluded trees and unused packages with build+smoke green after each deletion patch; app builds as `SwiftlyCodeEdit.app` bundle with correct name in menu bar, About, and window titles; changelog updated.
- Parallel-plan ready: yes (WS-P1 and WS-P2 touch disjoint files; sequence only the Package.swift edits).

### Milestone: MS SwiftUI architecture

- Depends on: MP exit (bundle identity and cleaned tree; migration should not carry dead code forward).
- Workstreams: WS-S1, WS-S2.
- Entry criteria: MP exit criteria met.
- Exit criteria: app launches via SwiftUI `App` + DocumentGroup; ReferenceFileDocument (or NSDocument-backed DocumentGroup shim if ReferenceFileDocument cannot preserve autosave/external-change parity - decision recorded) handles open/save/save-as/autosave/external-change with parity proven by the existing lifecycle tests; SwiftUI Commands menu replaces `PlainEditorMainMenu` and dead `PlainEditorCommands` is either promoted or deleted; smoke script and App Intents hooks updated and green; obvious follow-ons (delete superseded AppKit shell code, changelog) completed.
- Parallel-plan ready: no. The lifecycle swap is one inherently serial refactor (single critical path through app-shell + document); WS-S2 validation work packages still run in parallel with late WS-S1 packages.

### Milestone: MF scope features

- Depends on: MS exit (features wire once into the final shell).
- Workstreams: WS-F1, WS-F2, WS-F3, WS-F4.
- Entry criteria: MS exit criteria met.
- Exit criteria: Find/Replace panel works with literal and regex modes and is undoable; themes load from bundled data files and Application Support with live switching; a user-dropped Kate XML file highlights a new language without rebuild; Clean Text menu ships the safe action set with unit tests; each feature has smoke or package-test coverage; changelog updated.
- Parallel-plan ready: yes (four independent lanes; only WS-F2/WS-F3 share the highlighting component and declare a file-level boundary: WS-F2 owns color mapping, WS-F3 owns definition loading).

### Milestone: MQ performance

- Depends on: MF exit (measure the real feature-complete editor, not a moving target).
- Workstreams: WS-Q1, WS-Q2.
- Entry criteria: MF exit criteria met.
- Exit criteria: keystroke-to-highlight work is bounded (edited-line window or visible range, not whole document); status refresh no longer rescans the full document per keystroke; a repeatable benchmark script proves p95 keystroke handling under 16 ms on a 1 MB source file, recorded in `test-results/`; step-budget truncation path has a regression test; changelog updated.
- Parallel-plan ready: yes (WS-Q1 and WS-Q2 touch disjoint components).

### Milestone: MG Liquid Glass and release

- Depends on: MQ exit (polish last, on stable behavior).
- Workstreams: WS-G1, WS-G2.
- Entry criteria: MQ exit criteria met.
- Exit criteria: command ribbon and status bar adopt `glassEffect` per docs/LIQUID_GLASS.md with editor content untouched; captured screenshots for light AND dark mode plus reduced-transparency spot check exist under `docs/screenshots/`; README, docs/CODE_ARCHITECTURE.md, docs/FILE_STRUCTURE.md, docs/SMOKE_TEST.md refreshed; release checklist executed; changelog updated.
- Parallel-plan ready: yes (WS-G1 code polish and WS-G2 evidence/docs run concurrently).

## Workstream breakdown

### Workstream: WS-V1 independent verification audit

- Owner: reviewer-type coder (read-only against product code).
- Needs: nothing.
- Provides: `docs/active_plans/audits/milestone_claims_verification.md` evidence report; corrected checklist annotations.
- Expected patches: 1-2.

### Workstream: WS-V2 live-path bug fixes

- Owner: expert_coder (clipboard and encoding fixes are design-sensitive).
- Needs: nothing (bugs already pinned to file:line).
- Provides: fixed app-shell/document behavior with regression tests.
- Expected patches: 2-3.

### Workstream: WS-V3 test realignment

- Owner: coder.
- Needs: nothing.
- Provides: tests target the live engine and live cleaner; destructive cleaner deleted.
- Expected patches: 1-2.

### Workstream: WS-P1 legacy purge

- Owner: coder.
- Needs: WS-V1 report (confirms what is safely dead).
- Provides: repo without excluded trees, unused packages, or dead active-target code.
- Expected patches: 2-3 (staged deletions, build+smoke green after each).

### Workstream: WS-P2 product identity

- Owner: coder.
- Needs: none within MP.
- Provides: SwiftlyCodeEdit naming end to end plus .app bundle packaging.
- Expected patches: 1-2.

### Workstream: WS-S1 SwiftUI shell migration

- Owner: expert_coder.
- Needs: MP purge complete.
- Provides: SwiftUI App, DocumentGroup, Commands menu; AppKit shell deleted.
- Expected patches: 3-4.

### Workstream: WS-S2 migration revalidation

- Owner: coder.
- Needs: WS-S1 packages as they land.
- Provides: updated smoke script, App Intents hooks, lifecycle tests proving parity.
- Expected patches: 1.

### Workstream: WS-F1 find and replace

- Owner: expert_coder.
- Needs: MS shell (panel hosts in SwiftUI window).
- Provides: ported CodeEditSourceEditor find panel bound to `TextView`, regex toggle, undoable replace.
- Expected patches: 2-3.

### Workstream: WS-F2 theme data files

- Owner: coder.
- Needs: MS shell for settings surface; owns `PlainSyntaxHighlighter` color mapping.
- Provides: theme schema doc, bundled defaults, Application Support loading, live switching.
- Expected patches: 2.

### Workstream: WS-F3 user syntax directories

- Owner: coder.
- Needs: none beyond MS; owns `SyntaxDefinitionLoader`.
- Provides: Application Support Kate XML scan layered over bundled definitions.
- Expected patches: 1-2.

### Workstream: WS-F4 clean text menu

- Owner: coder.
- Needs: MS Commands menu.
- Provides: safe cleaning action set with unit tests.
- Expected patches: 1-2.

### Workstream: WS-Q1 incremental highlighting

- Owner: expert_coder.
- Needs: MF feature-complete highlighter.
- Provides: bounded rehighlight strategy plus benchmark and truncation regression test.
- Expected patches: 2.

### Workstream: WS-Q2 status recomputation

- Owner: coder.
- Needs: none within MQ.
- Provides: incremental or debounced status metrics.
- Expected patches: 1.

### Workstream: WS-G1 Liquid Glass chrome

- Owner: coder.
- Needs: stable chrome from MQ.
- Provides: `glassEffect` ribbon/status bar per docs/LIQUID_GLASS.md.
- Expected patches: 1-2.

### Workstream: WS-G2 release evidence and docs

- Owner: coder.
- Needs: WS-G1 visuals for screenshots.
- Provides: light/dark/reduced-transparency screenshots, refreshed docs, release checklist run.
- Expected patches: 1-2.

## Work packages

### Work package: WP-V1 verify claimed checklist items

- Owner: reviewer-type coder.
- Touch points: MILESTONE1_CHECKLIST.md, MILESTONE2_CHECKLIST.md, APP_INTENTS_SMOKE_TEST_GOAL.md, new `docs/active_plans/audits/milestone_claims_verification.md`.
- Depends on: none.
- Acceptance criteria: report is a strict table - one row per claim with columns: claim, source of truth, evidence command, result, corrected status, owning work package when not confirmed. Every checked item classified CONFIRMED (command + output evidence) or CORRECTED (with the true state); known-false claims (dead Find menu, "non-fatal screenshot" claim vs hard-fail script, dark-mode "validated" without capture, wrong-engine test coverage) explicitly corrected in the checklists. Scope is evidence and correction only; fixes stay in their owning work packages.
- Verification commands: `./build_debug.sh`, `./scripts/plain_editor_smoke.sh`, `swift test`, `pytest tests/`; outputs saved under `test-results/verification/`.
- Obvious follow-ons: add changelog entry; file any newly found bugs as work-package candidates in the audit report.

### Work package: WP-V2 fix clipboard paste

- Owner: expert_coder.
- Touch points: `CodeEdit/CodeEditApp.swift:269-295` (`PlainEditorActionRouter`).
- Depends on: none.
- Acceptance criteria: paste always reads `NSPasteboard.general`; internal `copiedText` buffer removed; copy "A", cut "B", paste yields "B"; external-app copy pastes correctly.
- Verification commands: new package test in `CodeEditTests/PackageSmoke/`; extend smoke command self-test with copy-then-cut-then-paste ordering; `swift test`.
- Obvious follow-ons: changelog entry; rerun smoke.

### Work package: WP-V3 fix silent-blank non-UTF open

- Owner: expert_coder.
- Touch points: `CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift:126-143`, `FileEncoding.swift`, `PlainEditorStatusReporter.swift:56-59`.
- Depends on: none.
- Acceptance criteria: Latin-1 and Windows-1252 become supported decode paths (added to `FileEncoding` and the suggested-encodings list); a file that still fails every supported decode presents a real NSError alert and opens nothing; status bar shows the actual detected encoding, or "Unknown" for the alert case; the window always contains either real decoded text or an explicit error - decide-and-record this contract in the patch.
- Verification commands: new lifecycle test with a Latin-1 fixture written inline to `tmp_path`-style temp dir; `swift test`.
- Obvious follow-ons: update the documented limitation in changelog and docs/SMOKE_TEST.md.

### Work package: WP-V4 make smoke script honest

- Owner: coder.
- Touch points: `scripts/plain_editor_smoke.sh`, `build_debug.sh` (line 49 background-launches a GUI instance and leaves it running, contaminating `/tmp/codeedit_runtime.log` launch-marker counts and piling instances in the Dock), app launch argument parsing in the debug launch path.
- Depends on: none.
- Acceptance criteria: this is a validation design task - classify every check as hard gate (launch, load, edit, save, reopen, status, highlight markers) or optional diagnostic (screenshot on machines without the helper or TCC grant), with skipped diagnostics reported as an explicit `SKIPPED: <reason>` line, so a green run states exactly what it proved; screenshot softening requires an explicit `--no-screenshot` flag; the script `rm -f`s its own stale artifacts (runtime log, prior smoke temp/test files) at start so every run begins clean; the app accepts a `--kill-after=N` CLI argument (for example `CodeEdit --kill-after=5`) that terminates the process cleanly N seconds after launch completes (after all smoke markers and the screenshot capture), `scripts/plain_editor_smoke.sh` launches the app with `--kill-after=N` on every run so validation never leaves app instances lingering in the Dock, and normal user launches without the flag never auto-quit; `build_debug.sh` either stops background-launching the app after building or launches it with `--kill-after=N`, so builds never leave a stray instance that contaminates the shared runtime log or the Dock; the script is invoked as plain `./scripts/plain_editor_smoke.sh` with no output redirection or wrapper needed, and it prints its own final exit status to stderr (for example `SMOKE_EXIT=0`) so callers that need the code read it from the script's own output; docs/SMOKE_TEST.md matches actual behavior.
- Verification commands: `./scripts/plain_editor_smoke.sh`; run once with skip flag; confirm no CodeEdit process survives the smoke run (`pgrep` returns nothing).
- Obvious follow-ons: changelog entry.

### Work package: WP-V5 fix double finishPlainEditorLaunch

- Owner: coder.
- Touch points: `CodeEdit/CodeEditApp.swift:17,31`.
- Depends on: none.
- Acceptance criteria: launch sequence runs once; runtime log shows single set of launch markers.
- Verification commands: `./scripts/plain_editor_smoke.sh` log inspection.
- Obvious follow-ons: changelog entry.

### Work package: WP-V6 delete destructive cleaner, test the live one

- Owner: coder.
- Touch points: `CodeEdit/Features/Editor/Views/PlainTextCleaner.swift` (delete), `CodeEditTests/PackageSmoke/PlainTextCleanerTests.swift` (retarget), `PlainEditorTextCleaner.swift`.
- Depends on: none.
- Acceptance criteria: destructive `PlainTextCleaner` removed via `git rm`; unit tests cover `PlainEditorTextCleaner.trimTrailingHorizontalWhitespace` (tabs, spaces, mixed, CRLF preservation, empty input).
- Verification commands: `swift test`.
- Obvious follow-ons: changelog entry; note in WS-F4 that safe Unicode normalization is rebuilt fresh there.

### Work package: WP-V7 retarget highlighter tests to live engine

- Owner: coder.
- Touch points: `Packages/CodeEditHighlighting/Tests/`, `CodeEdit/Features/Editor/Views/PlainEditorSyntaxStyler.swift` (delete), `Packages/CodeEditSyntaxDefinitions/Tests/`.
- Depends on: none.
- Acceptance criteria: dead `PlainEditorSyntaxStyler` and its `KateXMLSyntaxHighlighter`-only tests removed or ported to `KateContextRuleInterpreter`; live engine gains tests for `#pop!ctx` stack transitions and the step-budget truncation path.
- Verification commands: `swift test`, `swift test --package-path Packages/CodeEditSyntaxDefinitions`.
- Obvious follow-ons: changelog entry.

### Work package: WP-P1 delete excluded legacy trees

- Owner: coder.
- Touch points: `CodeEdit/Features/{SourceControl,TerminalEmulator,LSP,Extensions,Tasks,...}` (full Package.swift exclude list), `CodeEditTests/Features/`, `CodeEditUITests/`, `Configs/`, `OpenWithCodeEdit/`, `DefaultThemes/` (superseded by WS-F2 format), Package.swift exclude list shrink.
- Depends on: WP-V1 (audit confirms dead), WP-V7 (styler already removed).
- Acceptance criteria: `git rm` staged deletions in reviewable chunks; `./build_debug.sh` and smoke green after each chunk; Package.swift exclude list reduced to near-empty.
- Verification commands: `./build_debug.sh`, `./scripts/plain_editor_smoke.sh`, `swift test`, `pytest tests/`.
- Obvious follow-ons: update docs/FILE_STRUCTURE.md; changelog entries per deletion patch.
- Status 2026-07-09: staged, gates green. Spec review PASS on all five items (634 staged D entries exactly match changelog counts 559+56+19; exclude array fully gone; zero live references to deleted trees across 148 surviving files; protected set confirmed on disk; FILE_STRUCTURE/CHANGELOG consistent). Quality review folds into a combined MP deletion review after WP-P2 lands. Three chunks git rm-staged: (1) 559 files - all CodeEdit/-scoped Package.swift excludes (22 full Feature dirs, partial Documents/Editor excludes, root-level dead files, Utils subtrees), exclude array removed entirely (59 lines -> 0); (2) 56 files - CodeEditTests/Features+Utils, CodeEditUITests; (3) 19 files - Configs/, OpenWithCodeEdit/ (unreferenced-verified first). Build + smoke green after every chunk; final swift test 40 pass, pytest 2913 pass. FILE_STRUCTURE.md rewritten (live Features: About, Documents, Editor, Keybindings, SmokeTesting, Support); 3 changelog bullets. Empty dir husks removed via rmdir -p, including one pre-existing SwiftTerm husk.

### Work package: WP-P2 delete unused packages

- Owner: coder.
- Touch points: `Packages/CodeEditKit`, `Packages/WelcomeWindow`; OTHER_REPOS/ left untouched (user reference material).
- Depends on: WP-P1. Sequencing decision (explicit): `Packages/CodeEditSourceEditor` is EXCLUDED from this package - it stays on disk through WP-F1 as the find-panel harvest source, and its deletion is a listed WP-F1 obvious follow-on after the ported panel is validated.
- Acceptance criteria: CodeEditKit and WelcomeWindow removed; `Package.resolved` regenerated; build green; CodeEditSourceEditor untouched.
- Status 2026-07-09: COMPLETE (staged; human commit pending). Combined MP quality review PASS: independent gate rerun all green (build 4.64s, swift test 40 pass, smoke SMOKE_EXIT=0, pytest 2717 pass - count drop from 2913 reflects deleted files, not failures); survivor-tree rot check clean (zero dangling imports, Package.swift coherent, docs/scripts reference no deleted path); changelog category order intact with 3+1 Removals bullets. MP milestone exit criteria met pending the human commit. Note: quality reviewer's smoke rerun overwrote docs/screenshots/codeedit_window.png (script side effect, line 11 default) - screenshot-docs regenerates it anyway. Pre-deletion greps: zero CodeEditKit references; WelcomeWindow's only 3 hits are stale file-header comments in Packages/AboutWindow (noted for the dead-code sweep). git rm 44 + 43 files; Package.resolved unchanged (MD5-identical - local path deps never recorded there); build 4.88s, swift test 40 pass, smoke SMOKE_EXIT=0. Changelog carries the WP-P2 bullet plus the routed WP-Q1 docs bullet.
- Verification commands: `./build_debug.sh`, `swift test`.
- Obvious follow-ons: changelog entry.

### Work package: WP-P5 live-target dead-code purge (added 2026-07-09)

- Owner: coder.
- Touch points: per docs/active_plans/audits/live_target_dead_code_audit.md - 50 DELETE-NOW files (About subtree x10, Keybindings x3 + json resource, KeyChain x3, dead SmokeTesting AppIntents file, Utils standalone x5, 27 Utils extensions keeping only DebugRuntimeLog/String+Lines/SceneID), 2 in-file symbol removals (PlainEditorCommands in CodeEditApp.swift:440-545; legacy SYNTAX_THEME_VARIANT=rotated branch), orphaned packages AboutWindow + CodeEditSymbols with their Package.swift dependency/product lines, plus stray CodeEditUI/src/Preferences/ViewOffsetPreferenceKey.swift and AppCast/ (both outside the compile surface, unreferenced).
- Depends on: WP-P1/P2 (landed), the sweep audit (landed). User directive: "clean up the codebase as best you can, legacy code will promote regressions and drift."
- Acceptance criteria: all DELETE-NOW items git rm-ed / edited out in reviewable chunks with build+test+smoke green after each; the two MEDIUM-confidence items (Localized+Ex.swift, generic-name String extensions) deleted only if swift build stays green, else reclassified KEEP with the failing referent recorded; About menu behavior verified post-deletion (standard NSApp About panel or menu item removed consciously - decision recorded); UndoManagerRegistrationTests kept (tests live CEUndoManager machinery; rename is a follow-on note, not scope).
- Verification commands: ./build_debug.sh; swift test; ./scripts/plain_editor_smoke.sh; pytest tests/.
- Status 2026-07-09: COMPLETE (staged; human commit pending). Combined review PASS: independent gate rerun green incl. a from-scratch isolated build - zero deprecation warnings and zero first-party warnings remain (all 276 surviving warnings are vendored Packages/); audit conformance exact (every DELETE-NOW absent, every KEEP present, Package.swift = 4 deps, no dangling resource); in-file removals clean (CodeEditApp.swift 450 lines, no PlainEditorCommands remnant; PlainSyntaxTheme.current coherent). Reviewer note (not a P5 issue): smoke script exercises in-memory lifecycle via the command self-test but has no literal save-to-disk/reopen step - logged as a smoke-coverage follow-up in docs/TODO.md. 106 files removed in 4 gated chunks (About subtree 10 + AboutWindow 46 + CodeEditSymbols 41 with Package.swift dep/product lines; Keybindings/KeyChain/dead SmokeTesting AppIntents 8; Utils tree 33 keeping DebugRuntimeLog/String+Lines/SceneID + WindowObserver.swift; MEDIUM items + CodeEditUI stray + AppCast/ 8 + PlainEditorCommands 106 lines + SYNTAX_THEME_VARIANT rotated branch). Both MEDIUM-confidence items deleted clean (no reclassification). About finding: no About menu item or standard-panel call ever existed in the compiled app - nothing dangled. Final gates: swift test 40 pass, pytest 2418 pass (one stale CODE_ARCHITECTURE Known-gaps bullet fixed mid-run). Chunks 5-6 (post-dispatch additions): Documentation.docc/CodeEditUI 8 files + dangling index entry, then the whole remaining Documentation.docc/ tree 26 files (zero build references, no DocC plugin; every surviving section indexed already-deleted symbols) - gates green after each. WP-P5 total: 140 files. Follow-up landed: TODO.md pruned to 2 accurate items and RELATED_PROJECTS.md re-verified against the four real Package.swift deps (AboutWindow/CodeEditSymbols moved to the deleted-projects section).

### Work package: WP-P3 rename product to SwiftlyCodeEdit

- Owner: coder.
- Touch points: `Package.swift` (product/target names), `CodeEdit/CodeEditApp.swift` menu strings, About surface, window title path, smoke script expectations, README.
- Depends on: none within MP.
- Acceptance criteria: running app shows "SwiftlyCodeEdit" in menu bar, Quit item, About, and window titles; no user-visible "CodeEdit" strings remain (`rg -i 'codeedit'` audit of user-facing strings recorded).
- Verification commands: `./scripts/plain_editor_smoke.sh` with updated markers; manual menu inspection screenshot.
- Obvious follow-ons: changelog entry; update docs referencing binary name.
- Status 2026-07-09: implemented; spec review returned MUSTFIX but items 1-4 were overruled by manager verification - every flagged "user-visible CodeEdit string" lives in a Package.swift-excluded tree (Feedback, WindowCommands, Settings, SourceControl, CEWorkspace, LSP), never compiled and all on the WP-P1 deletion list; the compiled-files-only audit scope was correct. MUSTFIX 5 stands: reviewer's smoke rerun hit SMOKE_EXIT=1 (`Plain editor Swift syntax highlight:` wait timeout, elapsedMs=6158 landed after the wait window) while running concurrently with the WP-P4 bundle coder's builds/launches - the known cold-compute contention knife-edge owned by WP-Q1. CLOSED 2026-07-09: clean smoke rerun on an idle machine passed (SMOKE_EXIT=0); quality review PASS (all seven files consistent, binary name verified against the real build artifact, style conforms).

### Work package: WP-P4 app bundle and icon

- Owner: coder.
- Touch points: new `scripts/make_app_bundle.sh`, Info.plist (CFBundleName SwiftlyCodeEdit, CFBundleGetInfoString tagline "A fast native code editor for macOS."), new `scripts/make_app_icon.py` plus generated `SwiftlyCodeEdit.icns` icon wiring.
- Depends on: WP-P3.
- Acceptance criteria: a simple original logo representing fast and code - a lightning bolt between angle brackets (`<` bolt `>`) on a macOS squircle background, flat two-tone, legible at 16x16 - is generated programmatically by `scripts/make_app_icon.py` (Pillow) into the full macOS icon size set (16 through 1024, 1x and 2x) and assembled into `SwiftlyCodeEdit.icns` via Pillow's native ICNS writer (user machine lacks `iconutil`; decision 2026-07-09); the icon source script is committed so the logo is reproducible and editable as code, not a binary-only asset; `scripts/make_app_bundle.sh` produces `SwiftlyCodeEdit.app` from the SwiftPM binary with the icon wired via CFBundleIconFile; Finder, Dock, and menu bar show correct name and icon; smoke can launch the bundle; image_evaluator assesses the 1024px render for legibility, bolt/bracket balance, and small-size readability, with the assessment saved under `docs/active_plans/reports/`.
- Verification commands: `python3 scripts/make_app_icon.py`; the produced `.icns` loads back via `PIL.Image.open`; run the bundle script; `open SwiftlyCodeEdit.app`; screenshot evidence of Dock icon.
- Obvious follow-ons: changelog entry; document in docs/DEVELOPER_USAGE.md.
- Status 2026-07-09: COMPLETE. Icon SHIP verdict after inset/chevron rework (assessment in `docs/active_plans/reports/app_icon_assessment.md`); bundle script verified release + debug (plutil OK, `--kill-after` self-quit honored); Dock evidence at `docs/screenshots/dock_icon.png` (icon with running dot visible; menu bar read SwiftlyCodeEdit). Operational note: a LaunchServices `open` of the bundle has no agent-side kill path (the permissions hook denies pkill/kill in every context, steering to `--kill-after` at launch) - Dock-evidence runs end with a manual user quit; one stray instance from this capture awaits the user's Cmd+Q.

### Work package: WP-S0 document architecture proof spike

- Owner: expert_coder.
- Touch points: throwaway branch prototype; decision recorded in `docs/active_plans/decisions/document_architecture_decision.md`.
- Depends on: MP exit.
- Acceptance criteria: a minimal DocumentGroup + ReferenceFileDocument prototype demonstrates (or refutes) each of: autosave debounce parity, Save As, external-change reload into shared text storage, and encoding preservation on save; the decision doc records the chosen architecture (ReferenceFileDocument vs DocumentGroup-over-NSDocument bridge) with the evidence for each behavior BEFORE WP-S1 is dispatched.
- Verification commands: prototype run log; lifecycle test suite executed against the prototype where feasible.
- Obvious follow-ons: changelog decision entry; feed the chosen shape into WP-S1's task description.
- Status 2026-07-09: COMPLETE, verdict "NSDocument behind a DocumentGroup bridge". A throwaway `DocumentGroup`+`ReferenceFileDocument` prototype (macOS 26.5.2, Swift 6.3.3, MacBookPro18,3) passed the encoding gates (Save As and open-edit-save round-trips byte-identical across all five encodings) but failed both lifecycle gates: no 2 s autosave debounce (`ReferenceFileDocument` has no `scheduleAutosaving` override; a force-dirtied document never autosaved within 8 s), and no external-change reload into the same `NSTextStorage` (reload was either not delivered in place or arrived as a fresh document with a new storage). Mechanical rule -> bridge. Keep `CodeFileDocument` as the `NSDocument` model; the single sanctioned document-layer AppKit bridge file is `CodeFileDocumentBridge.swift` (created by WP-S1). Re-evaluation trigger: next macOS SDK. Decision record: [document_architecture_decision.md](../active_plans/decisions/document_architecture_decision.md).
- Bridge-mechanism decision (architect, 2026-07-09, same decision doc): document windows host through `NSDocumentController` under a plain SwiftUI `App` scene, not `DocumentGroup` - this refines the mechanical verdict's "DocumentGroup" label to the concrete scene type. `CodeFileDocument` keeps sole ownership of the autosave debounce, the `NSFilePresenter` external-reload path, and the shared `NSTextStorage` identity; a `ReferenceFileDocument` facade under `DocumentGroup` cannot deliver this (`DocumentGroup` always manages its own private `NSDocument`, creating a double-owner conflict). WP-S1 wires `@main` as the SwiftUI `App`, routes File > New / File > Open to `NSDocumentController.shared`, and builds `CodeFileDocumentBridge.swift` accordingly.

### Work package: WP-S0b SwiftUI-native text engine spike

- Owner: expert_coder.
- Touch points: throwaway prototype under a scratch directory (not the repo tree); decision recorded in `docs/active_plans/decisions/text_engine_decision.md`.
- Depends on: none (added 2026-07-09 by user directive to pursue full SwiftUI architecture; runs independently of MP deletions).
- Acceptance criteria: a minimal macOS 26 SwiftUI prototype using `TextEditor` bound to `AttributedString` (the macOS 26 rich-text binding) is measured as a candidate code-editor engine against the smoke fixture (~14,920 chars) and a generated ~1 MB Swift file, recording: (1) p95 keystroke-to-render latency while typing mid-document; (2) wall-clock to apply a full `[HighlightSpan]` -> AttributedString foreground-color run set programmatically; (3) whether a programmatic attribute update preserves cursor position, selection, and scroll offset; (4) memory footprint at 1 MB. Provisional pass gates: p95 keystroke under 16 ms and full span apply under 50 ms on the smoke fixture with cursor/scroll preserved; gates revisable as a logged decision. The decision doc states the verdict under the user's 2026-07-09 weighting (research: SwiftUI is the preferred shell; AppKit remains the deep systems layer for serious Mac text behavior, mixing expected): default is "AppKit core retained" - SwiftUI-native wins only on a decisive pass of ALL gates with clear margin and no state-preservation or API-maturity red flags; a narrow/borderline pass = KEEP with numbers recorded and a re-evaluation trigger at the next macOS SDK. Either way the SwiftUI shell migration (WP-S1..S3) proceeds; this spike only decides the text-engine interior.
- Verification commands: prototype run printout of the four measurements; the decision doc quoting them.
- Obvious follow-ons: changelog decision entry; if PASS, add a text-engine migration work package to MS and mark the `editor-bridge` component for retirement; if FAIL, note the re-evaluation trigger (next macOS SDK) in the decision doc.
- User note 2026-07-09: the isolated prototype is deliberately minimal for clean measurement, and it doubles as the seed for the real migration - on a SwiftUI-native outcome, WP-S1 starts from the spike's TextEditor harness rather than from scratch; even on the adapter outcome, the spike's SwiftUI scaffolding (document loading, AttributedString span application) carries into the WP-S1 shell.
- Status 2026-07-09: COMPLETE, verdict "Replaceable AppKit adapter (escape hatch)" - measured FAIL on macOS 26.5.2 / Swift 6.3.3, decisive on all gates (decision doc: `docs/active_plans/decisions/text_engine_decision.md`). Named behaviors justifying the adapter: (1) caret collapse - any programmatic attribute write (batched reassign or in-place subrange edit) throws the insertion point from mid-document to end-of-file, fatal for an async highlighter that writes attributes every pass; (2) latency - keystroke p95 140.56 ms vs 16 ms gate, span apply 159.07 ms vs 50 ms gate; (3) ~1 MB document wedges main-thread layout (never mounts in 25 s; one run >160 s) where TextKit lays out incrementally. The `editor-bridge` component is NOT retired: it survives as the narrow, isolated, documented-swap-path adapter per the SwiftUI-first principle; re-evaluation trigger next macOS SDK. WP-S1..S3 shell migration proceeds unchanged; changelog decision entry owed to the next docs pass.

### Work package: WP-S1 SwiftUI App and DocumentGroup lifecycle

- Owner: expert_coder.
- Touch points: `CodeEdit/CodeEditApp.swift` (replace `@main enum` + delegate + `PlainEditorMainMenu`), `CodeFileDocument.swift` (ReferenceFileDocument conformance or DocumentGroup/NSDocument bridge), `WindowCodeFileView.swift`.
- Depends on: WP-S0 (recorded architecture decision).
- Acceptance criteria: app launches through SwiftUI `App` with DocumentGroup scenes; open/save/save-as/close/new all work; autosave parity (2 s debounce or DocumentGroup-native) proven; external-change reload parity proven; decision on ReferenceFileDocument vs NSDocument-bridge recorded in the plan tracker with rationale.
- Verification commands: `swift test` (lifecycle suite), `./scripts/plain_editor_smoke.sh`.
- Obvious follow-ons: delete superseded AppKit shell code in the same patch series; changelog per patch.

### Work package: WP-S2 SwiftUI Commands menu

- Owner: expert_coder.
- Touch points: promote/rewrite `PlainEditorCommands` (currently dead) as the single menu source; delete `PlainEditorMainMenu`; keep `PlainEditorActionRouter` or replace with focused-scene state.
- Depends on: WP-S1.
- Acceptance criteria: File (New/Open/Save/Save As/Close), Edit (Undo/Redo/Cut/Copy/Paste/Select All/Clean Text), Find menu present via SwiftUI Commands; every item reaches the active editor; keyboard shortcuts preserved; command ribbon buttons share the same actions.
- Verification commands: smoke command self-test extended to run via the new menu paths; `./scripts/plain_editor_smoke.sh`.
- Obvious follow-ons: changelog entry.

### Work package: WP-S3 revalidate smoke and App Intents on new shell

- Owner: coder.
- Touch points: `scripts/plain_editor_smoke.sh`, `CodeEdit/Features/SmokeTesting/PlainEditorSmokeIntents.swift`, `CodeEditTests/PackageSmoke/`.
- Depends on: WP-S1, WP-S2.
- Acceptance criteria: all smoke markers fire on the SwiftUI shell; App Intents hooks exercise the same document path; lifecycle tests green; APP_INTENTS_SMOKE_TEST_GOAL.md updated to reflect the new shell.
- Verification commands: `./scripts/plain_editor_smoke.sh`, `swift test`.
- Obvious follow-ons: changelog entry.

### Work package: WP-F1 port find panel

- Owner: expert_coder.
- Touch points: new `CodeEdit/Features/Find/` (panel views + controller ported from `Packages/CodeEditSourceEditor` find implementation), `PlainTextEditorView.swift` bridge hooks, Find menu items.
- Depends on: MS exit.
- Acceptance criteria: Cmd-F opens find bar; literal and regex modes; next/previous navigation with visible selection; Cmd-Opt-F reveals replace; Replace and Replace All mutate the document and are undoable. Edge cases with tests: zero matches shows a clear "no results" state; invalid regex shows an inline error and disables navigation; overlapping regex matches follow documented non-overlapping left-to-right semantics; Replace All undoes as one operation; selection lands on the replaced text after each single replace. Panel matches Liquid Glass control-layer guidance.
- Verification commands: new package tests for match/replace logic including the edge cases (inline fixtures); smoke assertion that find UI marker fires; `swift test`.
- Obvious follow-ons: delete `Packages/CodeEditSourceEditor` via `git rm` once the ported panel is validated (completes the sequencing decision recorded in WP-P2); changelog.
- Status 2026-07-10: COMPLETE. Patch 18 (find panel port into `CodeEdit/Features/Find/`) and
  patch 19 (deletion of `Packages/CodeEditSourceEditor`, 199 files, completing the WP-P2
  sequencing decision) both landed and passed spec review.

### Work package: WP-F0 Application Support path policy

- Owner: coder.
- Touch points: new `CodeEdit/Features/Support/UserDataDirectories.swift` (single helper owning the app identifier, base path `~/Library/Application Support/SwiftlyCodeEdit/`, subdirectory creation, discovery logging, and a test-override root parameter).
- Depends on: MS exit.
- Acceptance criteria: one shared helper defines the path policy consumed by both WP-F2 (Themes/) and WP-F3 (Syntax/); directories created on first use; discovery logged with counts; tests point the helper at a temp root.
- Verification commands: package test using the override root; `swift test`.
- Obvious follow-ons: changelog; short docs section on user data locations.

### Work package: WP-F2 theme data format and loader

- Owner: coder.
- Touch points: new `CodeEdit/Features/Theming/` (schema structs, loader, bundled `Resources/Themes/*.yaml` or `.json` defaults for light+dark), `PlainSyntaxHighlighter.swift` (replace hardcoded `PlainSyntaxTheme`), new `docs/THEME_FORMAT.md`.
- Depends on: WP-F0 (path policy); owns highlighting color mapping (boundary with WP-F3).
- Acceptance criteria: Patch A is `docs/THEME_FORMAT.md` alone - a small versioned schema (one JSON/YAML file per theme; a file may carry paired light/dark variants that the loader and UI treat as one selectable theme), semantic token names, explicit fallback colors, and malformed-file handling; the manager records the schema decision and proceeds (human may redirect later, no blocking approval gate). Patch B is the loader: token-style-to-color mapping defined entirely by data files; bundled default light + default dark seed themes, converting useful colors from the legacy `DefaultThemes/*.cetheme` files before those are deleted as legacy data (single-format future, old format is reference input only); user themes discovered via WP-F0 paths; a malformed theme loads the default with a logged warning and keeps the app running; theme selectable via menu.
- Patch A DONE 2026-07-09, schema decision recorded: YAML per theme (JSON accepted, format-neutral schema), top-level `version`/`name`/`variants: {light, dark}`, one file's variant pair = one selectable theme; `#RRGGBB`/`#RRGGBBAA` colors; token keys mirror the live `HighlightToken` enum plus the six Kate styleName refinements the highlighter consults, resolution order styleName -> token -> `base_text` exactly as `color(for:)` implements today; fallback chain missing-key -> variant base_text, missing-variant -> mirror the present one, malformed file -> bundled default + logged warning; `background` included as a required key ahead of an editor-background feature (accepted - theme files stay self-contained). See docs/THEME_FORMAT.md.
- Verification commands: package tests for parse/fallback with inline theme strings; smoke `SYNTAX_THEME_VARIANT` path replaced by a real theme-file swap; `swift test`.
- Obvious follow-ons: delete env-var theme hack; delete `DefaultThemes/` after conversion; changelog.

### Work package: WP-F3 user syntax definition directories

- Owner: coder.
- Touch points: `Packages/CodeEditSyntaxDefinitions/Sources/.../CodeEditSyntaxDefinitions.swift` (`SyntaxDefinitionLoader`), new user-dir scan of `~/Library/Application Support/SwiftlyCodeEdit/Syntax/`.
- Depends on: WP-F0 (path policy); owns definition loading (boundary with WP-F2).
- Acceptance criteria: user XML files layered over bundled ones (user wins on name collision); dropping a new Kate XML then relaunching highlights that language without rebuild; a malformed XML is logged, skipped, and the app keeps running; extension-to-definition mapping documented, including the tsName-to-Kate alias mapping risk from the audit.
- Verification commands: package test with a temp-dir user definition; manual smoke with a dropped XML file; `swift test --package-path Packages/CodeEditSyntaxDefinitions`.
- Obvious follow-ons: document in README + new docs section; changelog.

### Work package: WP-F4 safe clean text menu

- Owner: coder.
- Touch points: `CodeEdit/Features/Editor/PlainEditorTextCleaner.swift` (extend), Clean Text submenu in SwiftUI Commands, chrome ribbon.
- Depends on: WP-S2 (menu), WP-V6 (destructive cleaner gone).
- Acceptance criteria: actions - trim trailing whitespace, normalize line endings to LF/CRLF, ensure final newline, tabs-to-spaces, spaces-to-tabs, normalize smart punctuation to ASCII (explicit opt-in, preserves all other Unicode); each undoable, each unit-tested, each marks document dirty.
- Verification commands: package tests per action with inline fixtures; smoke self-test extended for one new action; `swift test`.
- Obvious follow-ons: changelog; docs update describing each action.

### Work package: WP-F6 general font menu

- Owner: coder.
- Touch points: `PlainEditorFontSettings` and `PlainEditorCommandBar.fontControls` in `CodeEdit/Features/Editor/Views/CodeFileView.swift`; SwiftUI Commands menu (new Format > Font submenu).
- Depends on: WP-S2 (SwiftUI Commands menu exists).
- Acceptance criteria: replace the hardcoded `availableFontFamilies` four-font list with a general enumeration of installed fixed-pitch font families (NSFontManager/NSFontCollection filtered to monospaced), so user-installed fonts such as mononoki appear automatically; move font family selection out of the command ribbon into a Format > Font menu (font choice is long-lived, not a per-session ribbon control); Format > Font menu carries Increase Font Size (Cmd-+, accepting Cmd-= as the unshifted key) and Decrease Font Size (Cmd--) plus Reset Size, using the existing clamp range; ribbon keeps only A-/A+/size affordances or drops font controls entirely; selection persists via the existing `@AppStorage` keys; default remains SF Mono with the existing fixed-pitch fallback; mononoki selectable and rendering when installed.
- Verification commands: package test that the enumeration includes only fixed-pitch families and contains an installed known mono font; smoke log marker for the selected family; `swift test`.
- Obvious follow-ons: changelog entry; docs note on font selection location.

### Work package: WP-Q1 bounded rehighlighting

- Owner: expert_coder.
- Touch points: `PlainSyntaxHighlighter.swift`, `CodeFileView.swift:61-69` (`onTextChange`), `KateContextRuleInterpreter` entry points.
- Depends on: MF exit. PULLED FORWARD 2026-07-09 (user directive: cold highlight still takes seconds; top complaint after WP-Q0b closed reliability). Dispatched ahead of MS/MF.
- Acceptance criteria: per-keystroke highlight work bounded to edited region plus context window (line-window re-scan from last stable context state) or visible range; no full-document attribute rewrite or full `layoutLines()` per keystroke; `actualColumn` back-scan quadratic fixed; correctness suite still green.
- Acceptance extension 2026-07-09 (user directive, "ammeter in a circuit"): the syntax-color pipeline is modularized into separately callable, display-free stages (definition parse -> interpretation -> span mapping, with attribute application as the only display-side stage), each stage pure text/data-in data-out and independently timeable; a headless benchmark in `Packages/CodeEditSyntaxDefinitions` (swift test or swift run, zero AppKit) prints per-stage wall-clock (parseMs, interpretMs, spanMapMs) recorded under `test-results/perf/`; per-stage timings before and after each optimization are the acceptance evidence, and the stage APIs remain as durable profiling seams. Also folds in the three WP-Q0b polish items (drift-loop iteration cap, storage-capture comment, strengthen `swiftKeywordsReceiveSyntaxColoring`). Priority order: cold-compute cost first (target <1 s on the ~1400-line smoke file, baseline elapsedMs=6158), viewport-first paint second, bounded keystroke rescan third.
- Verification commands: new benchmark script `scripts/highlight_benchmark.sh` on a generated 1 MB Swift file, output to `test-results/perf/`; `swift test`. Gate is provisional regression protection, not a flaky wall: the script records machine model, fixture generation command, input method, warmup runs, sample count, and variance; the initial target is p95 < 16 ms per keystroke, revisable once the recorded baseline exists (revision recorded as a decision).
- Obvious follow-ons: regression test for step-budget truncation (visible fallback instead of silent partial); changelog.
- Status 2026-07-09: COMPLETE. Confirmatory review PASS on all four fix-round items: POSIX bail correct including `[^[:cntrl:]]` and end-of-pattern edges; regression test carries a non-vacuous positive assertion (asserts the Keyword run itself, not just equivalence); `advanceCursor(toAtLeast:)` single-walk with a proven forward-progress guarantee (match length > 0 plus the apply() one-grapheme stall guard); reviewer independently reran both suites (package 9 pass, full repo 40 pass). Reviewer also confirmed the WP-Q0b fold-in `swiftKeywordsReceiveSyntaxColoring` strengthening landed (polls distinctForegroundColorCount >= 2). Cold highlight on the ~1400-line smoke fixture: 6293 ms -> 67 ms (real culprit: O(n^2) step-budget guard recomputing `text.count` per interpreter step, not regex compilation); warm reopen 0 ms via process-wide `CompiledRegexCache`. Ammeter delivered: public display-free stages `parseDefinition` -> `definition(forLanguage:)` -> `tokenRuns` -> `spans`, per-stage timings parseMs=6 interpretMs=54 spanMapMs=2 recorded in `test-results/perf/highlight_cold_pass.txt` via HIGHLIGHT_BENCH_STAGES. Review MUSTFIX 1 (POSIX `[:name:]` bracket misparse -> false-skip) fixed by bailing FirstCharFilter analysis to always-run on nested `[:name:]`/`[=c=]`/`[.name.]`; regression test proven to fail without the fix. SHOULDFIX 1 fixed: match-jump uses `advanceCursor(toAtLeast:)` so grapheme cursor and UTF-16 offset derive from one walk (unicode fixture test: emoji/CJK/combining marks). All suites green (swift test 40 pass; package 9 pass; smoke SMOKE_EXIT=0, spans=4416 byte-identical).
- Decision 2026-07-09 (large-file deferral): large files (~1 MB+) remain multi-second cold until viewport-first lands (deferred to a future large-file work package). The original 1 MB p95 keystroke gate stays with that future package; this round's gate was the cold-compute target (<1 s on the smoke fixture), met at 67 ms.

### Work package: WP-Q2 incremental status metrics

- Owner: coder.
- Touch points: `PlainEditorStatusReporter.swift`, `PlainEditorChromeModel` in `CodeFileView.swift`.
- Depends on: none within MQ.
- Acceptance criteria: word/line/char counts updated incrementally from edit deltas or debounced (>=150 ms) full recompute - decision recorded; cursor label no longer allocates full-prefix substrings per refresh; values remain correct after paste/undo/clean.
- Verification commands: package tests for delta correctness; benchmark script includes status refresh timing; `swift test`.
- Obvious follow-ons: changelog.

### Work package: WP-Q0 launch pinwheel fix (async first highlight)

- Owner: expert_coder.
- Touch points: `CodeEdit/Features/Editor/Views/PlainSyntaxHighlighter.swift:24-79`, `CodeEdit/Features/Editor/Views/CodeFileView.swift:61-82`, `CodeEdit/Features/Editor/Views/PlainTextEditorView.swift:83-158`.
- Depends on: MV wave landed (same files as WP-V2's self-test edits).
- Acceptance criteria: the first document window orders front and paints (plain text) without waiting for highlighting - span computation (`CodeEditSyntaxDefinitions.highlightSpans`) moves off the main thread with attribute application hopping back to `@MainActor`; a stale-result guard drops a background result when the text changed while it computed; the command self-test and smoke highlight markers still pass (markers may fire after window-visible); no beachball between app open and window visible (probe evidence: previously 3.4 s synchronous cold highlight inside window construction). The durable interpreter speedup (persistent regex cache, viewport-first) stays in WP-Q1; this package only unblocks the main thread.
- Verification commands: `./scripts/plain_editor_smoke.sh`; `swift test`; manual/log check that window-visible precedes the first `PlainSyntaxHighlighter finish` marker on a cold run.
- Obvious follow-ons: changelog entry; note the async pattern for WP-Q1 to reuse.

### Work package: WP-Q0b per-document highlight state (intermittent-highlight fix)

- Owner: expert_coder.
- Touch points: `CodeEdit/Features/Editor/Views/PlainSyntaxHighlighter.swift` (replace global static `latestGeneration`/`cachedText`/`cachedSpans` with per-storage state), `CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift` (schedule a highlight after external-change reload), tests.
- Depends on: WP-Q0 (async pattern this fixes forward).
- Acceptance criteria: highlighter generation counter and span cache are keyed per document/text storage so one window's request can never invalidate another window's in-flight compute; a post-compute drop caused by text drift with an unchanged generation re-schedules against the current storage text instead of leaving the document unhighlighted; `presentedItemDidChange` reloads trigger a highlight even though they bypass `onTextChange`; two-document scenario covered by a package test; smoke stays green without depending on last-edit-wins ordering luck (probe evidence: `dropped stale generation=4 latest=29` with no retry, runtime.log:107-110).
- Verification commands: `swift test`; `./scripts/plain_editor_smoke.sh`; a two-window manual or App Intents check where both windows end up highlighted.
- Obvious follow-ons: changelog entry via docs subagent.
- Status 2026-07-09: COMPLETE. Spec review PASS (all five criteria confirmed; reviewer independently reran `swift test` 28/6 pass and `./scripts/plain_editor_smoke.sh` SMOKE_EXIT=0 with chromatic_hue_families=4). Quality review PASS with two accepted SHOULDFIX polish items: (1) add an iteration cap to the drift-recompute loop as defense against a future programmatic-mutation-in-a-loop caller (today's only non-generation-bumping mutator is the one-shot smoke-intent insert); (2) one-line comment noting the Task's strong `storage` capture intentionally extends lifetime only for one compute pass. Quality review also confirmed the reload path repaints via the standard NSTextStorageDelegate invalidation pipeline (no explicit relayout needed) and flagged pre-existing test `swiftKeywordsReceiveSyntaxColoring` as no longer meaningful post-async (length-only assert) - fold both SHOULDFIX items and the test strengthening into WP-Q1.

### Work package: WP-Q4 screenshot color-count check

- Owner: coder.
- Touch points: new `tests/e2e/e2e_screenshot_colors.py`, `scripts/plain_editor_smoke.sh` (invoke the check on the branch that captured a screenshot).
- Depends on: WP-Q0b (highlighting must be reliably applied before pixel evidence gates on it).
- Acceptance criteria: `tests/e2e/e2e_screenshot_colors.py` crops a 10% border from all four edges of `docs/screenshots/codeedit_window.png`, counts the distinct significant colors in the remaining region (quantized to tolerate antialiasing, counting only colors above a small pixel-fraction floor), prints the count and the dominant colors, and exits non-zero when the count is below the threshold proving multi-color syntax highlighting is visible in the pixels (provisional threshold: at least 5 significant colors, matching the smoke log's colors=6 claim with headroom for quantization); the smoke script runs the check as part of the screenshot-captured branch so a captured screenshot of plain unhighlighted text fails the run; the script accepts an optional image path argument so it can check any capture.
- Verification commands: `python3 tests/e2e/e2e_screenshot_colors.py`; `./scripts/plain_editor_smoke.sh`.
- Obvious follow-ons: changelog entry via docs subagent.

### Work package: WP-Q3 launch-to-GUI time gate

- Owner: coder.
- Touch points: `CodeEdit/CodeEditApp.swift` (record a monotonic timestamp at the top of `main()` and log `LAUNCH_TO_WINDOW_MS=<n>` to the runtime log when the first document window is ordered front and visible), new `tests/e2e/e2e_launch_time.py`, `scripts/plain_editor_smoke.sh` (assert the marker exists).
- Depends on: the launch-lag root-cause fix (dispatched from the launch-lag probe findings) so the gate measures the fixed behavior, not the pinwheel.
- Acceptance criteria: the app logs `LAUNCH_TO_WINDOW_MS` measured from process entry to first window visible; `tests/e2e/e2e_launch_time.py` launches the built app with `--kill-after=N` five times, parses the marker, reports min/median/max, and exits non-zero when the median exceeds the budget; provisional budget 1000 ms cold / 500 ms warm on the recorded baseline hardware, revisable as a logged decision once the baseline exists; the script lives in `tests/e2e/` (excluded from `pytest tests/` per repo E2E policy) and follows the `e2e_*.py` naming rule; the smoke script asserts the marker line exists so every smoke run also proves the measurement path works.
- Verification commands: `python3 tests/e2e/e2e_launch_time.py`; `./scripts/plain_editor_smoke.sh`.
- Obvious follow-ons: changelog entry; record the hardware baseline next to the benchmark outputs under `test-results/perf/`.

### Work package: WP-G0 DEBUG window self-capture seam (added 2026-07-10)

- Owner: coder.
- Touch points: DEBUG-only `-PlainEditor.captureWindowTo` launch-argument seam, `WINDOW_CAPTURE_WRITTEN` runtime marker, temp-then-swap write path so a partially written PNG is never observable.
- Depends on: none within MG; feeds WP-G1/WP-G2 screenshot evidence.
- Acceptance criteria: a TCC-free, DEBUG-only window self-capture path writes a PNG to the requested path via a temp file swapped into place, and logs `WINDOW_CAPTURE_WRITTEN` once the swap completes; no production/RELEASE code path is affected.
- Status 2026-07-10: COMPLETE. Spec review and quality review both PASS. Smoke-script integration deferred to a follow-up patch (WP-G0 lands the seam; wiring it into `scripts/plain_editor_smoke.sh` is separate work). Note for WP-G1/WP-G2: the default capture renders in dark mode and clears the LIQUID_GLASS 3-hue floor at the minimum - force light appearance for the gated light-mode capture.

### Work package: WP-G1 glassEffect chrome

- Owner: coder.
- Touch points: `PlainEditorCommandBar` and `PlainEditorStatusBar` in `CodeFileView.swift` (replace `.background(.regularMaterial)` with `glassEffect`/GlassEffectContainer per macOS 26 API), per docs/LIQUID_GLASS.md sections 2, 5, 8.
- Depends on: MQ exit.
- Acceptance criteria: ribbon and status bar use Liquid Glass; editor text surface unchanged (`.textBackgroundColor`); readable in light, dark, increased-contrast; reduced-transparency degrades gracefully; passes the docs/LIQUID_GLASS.md section 9 review test. Accessibility validation is behavioral, not screenshot-only: the smoke run toggles `defaults write com.apple.universalaccess reduceTransparency`/increaseContrast (or the app-level accessibility environment overrides) where scriptable and asserts the chrome still renders with legible semantic foreground styles via runtime log markers.
- Verification commands: build + smoke including the accessibility-mode pass; screenshots captured in light and dark mode to `docs/screenshots/`.
- Obvious follow-ons: changelog; docs note where glass is used and why.

### Work package: WP-G2 release evidence and docs close-out

- Owner: coder.
- Touch points: `docs/screenshots/` (light, dark, reduced-transparency captures), README screenshots block, docs/CODE_ARCHITECTURE.md, docs/FILE_STRUCTURE.md, docs/SMOKE_TEST.md, docs/CHANGELOG.md, MILESTONE checklists archived via `git mv` to `docs/archive/`.
- Depends on: WP-G1.
- Acceptance criteria: dark-mode screenshot evidence exists (closing the M2 rationalized claim); all docs match shipped behavior; release checklist below fully executed. Close-out is automation-first: the smoke run asserts runtime markers for product name ("SwiftlyCodeEdit"), bundle identity, command availability, theme discovery count, user-syntax discovery count, and clean-text action wiring - screenshots are supplementary evidence, not the gate. Each capture (light, dark, reduced-transparency) is additionally assessed by the `image_evaluator` agent against explicit criteria - syntax token colors visibly distinct, ribbon/status text legible over glass chrome, status fields unclipped, window title shows SwiftlyCodeEdit - and the written assessment is saved under `docs/active_plans/reports/` as the visual-acceptance record (a non-empty PNG alone does not close a visual claim).
- Verification commands: `pytest tests/` (markdown links, hygiene), `./scripts/plain_editor_smoke.sh` with the release marker set.
- Obvious follow-ons: draft release notes body for `devel/make_release.py` if present.

### Work package: WP-P6 vendored-package warning burn-down (added 2026-07-09)

- Owner: coder.
- Depends on: WP-P5 (dead first-party warning sources already removed; survivors are all in Packages/).
- User directive: reduce warnings on a fresh build; verification for warning work is a from-scratch build count plus swift test - no smoke run (see memory: warning-reduction-fresh-build-metric).
- Baseline: ~276 warnings on an isolated from-scratch build, all under Packages/ (WP-P5 reviewer evidence); first fix landed - ViewReuseQueue @MainActor + isolated deinit, zero cascade.
- Acceptance criteria: fresh-build warning count reduced substantially with annotation-first/mechanical fixes only (actor isolation, deprecated-API swaps with identical semantics, unused-variable removals); anything needing logic redesign is reported with file:line and left for a designed fix, never forced; swift test stays green; before/after counts recorded.
- Status 2026-07-09: COMPLETE (staged). True from-scratch baseline was 7 distinct warning sites (all CodeEditTextView), not ~276 - earlier counts were warning LINES multiplied across generic instantiations, and the shared /tmp/warncheck-build path had been silently reused between agents (measurement trap: always use a fresh build path). Fixes: 3 dead-value bindings dropped; CursorTimer @MainActor + isolated deinit + MainActor.assumeIsolated timer closure; TextLayoutManagerRenderDelegate.lineFragmentView annotated @MainActor (protocol + default impl). Final fresh build: 0 warnings. swift test 40 pass throughout. Bonus: String(cString:) deprecation fixed in the syntax-definitions benchmark test. Pre-existing dependency-package test-target build errors logged as follow-ups (CodeEditLanguages test imports undeclared SwiftTreeSitter; KillRingTests actor violation - fold into the fixture-sandboxing WP).

### Work package: WP-F5 settings dialog (candidate, added 2026-07-09)

- Owner: coder.
- Depends on: MS exit (SwiftUI Settings scene wants the SwiftUI App shell; Cmd+, is a Scene, not a window hack).
- User request 2026-07-09: "a proper settings dialog... where we can select settings like font that are more static/permanent."
- Sketch: standard SwiftUI Settings scene (Cmd+,) per the SwiftUI-first boundary; font family/size (promote the existing PlainEditor.fontFamily/fontSize AppStorage keys from command-bar-only to a real preferences surface); theme picker binding to the WP-F2 loader; editor defaults (indentation style/width, default line ending); live-apply to open windows. Tracked user-facing in MILESTONE3_CHECKLIST.md.
- Status 2026-07-10: COMPLETE. Settings scene (patches 15-16) plus a live-apply observability seam; full review PASS covering the Cmd+, scene, persisted font/theme/indent/line-ending keys, `SETTINGS_APPLIED` fontSize/theme gates in `scripts/plain_editor_smoke.sh`, a DEBUG-only self-test seam, the in-memory theme registry, and confirmation the `defaults` domain stays unpolluted.

## Acceptance criteria and gates

- Per-patch gate: `./build_debug.sh` passes; `swift test` passes; `pytest tests/` passes; docs/CHANGELOG.md entry added; no new user-visible "CodeEdit" strings after MP.
- Integration gate (per milestone exit): `./scripts/plain_editor_smoke.sh` passes end to end; outputs archived under `test-results/`; milestone exit criteria checked with evidence, never rationalization - a claim without a command+output artifact does not close.
- Manual review gate: human reviews staged diffs and runs `git commit` (agents never commit per docs/REPO_STYLE.md); destructive patches (WP-P1, WP-P2, WP-V6) reviewed file-list-first before staging.

## Test and verification strategy

- Unit: Swift package tests in `CodeEditTests/PackageSmoke/` and package-local test targets; inline fixtures; every new feature lands with tests against the live code path (lesson from the wrong-engine coverage found in the audit).
- Integration: document lifecycle tests (load/edit/save/reopen, encoding fallback, external change) run in `swift test` without display access.
- Smoke/system: `scripts/plain_editor_smoke.sh` plus App Intents hooks; markers extended per milestone (find UI, theme swap, user syntax file, glass chrome).
- Performance: `scripts/highlight_benchmark.sh` (new, WP-Q1) with recorded p95 numbers; regression = gate failure.
- Failure semantics: any red gate blocks milestone exit; a failing claim discovered later reopens the owning work package rather than being annotated around.
- Python hygiene suite (`pytest tests/`) remains the repo-wide lint gate.

## Migration and compatibility policy

- Additive rollout: SwiftUI shell built behind the same document component before AppKit shell deletion within MS; theme/syntax loaders default to bundled data when user dirs are absent.
- Backward compatibility: none owed to upstream CodeEdit users - this is a hard fork; file-format behavior (preserve line endings, encoding on save) must not regress.
- Legacy deletion criteria: a tree/package is deletable when the WS-V1 audit confirms no active-target references and build+smoke stay green after removal.
- Rollback strategy: staged deletion and migration patches, each independently revertible; the MS lifecycle swap keeps the lifecycle test suite as the parity contract - if parity cannot be proven, fall back to the recorded NSDocument-bridge decision rather than shipping regressions.

## Risk register

| Risk | Impact | Trigger | Owner | Mitigation |
| --- | --- | --- | --- | --- |
| DocumentGroup cannot match NSDocument autosave/external-change parity | Save-path regressions, data loss | Lifecycle tests fail on WP-S1 | expert_coder (WS-S1) | Recorded fallback: DocumentGroup UI over NSDocument bridge; lifecycle tests are the contract |
| CodeEditSourceEditor find panel too entangled with its own text system | WP-F1 stalls | Port exceeds 2 patches of glue | expert_coder (WS-F1) | Harvest UI + match logic only; drive our TextView selection API; escalate to custom bar if entanglement confirmed |
| Incremental highlighting breaks Kate context correctness | Wrong colors, regressions | WP-Q1 correctness suite failures | expert_coder (WS-Q1) | Keep full-scan as debug oracle; property test comparing incremental vs full output on edit sequences |
| glassEffect API surface differs from expectations on macOS 26 SDK | WP-G1 rework | Compile/runtime failures on `glassEffect` | coder (WS-G1) | Prototype in first patch; fall back to closest system material while keeping structure |
| Mass deletion removes something silently needed | Build/smoke break late | Red gate after a WP-P1 chunk | coder (WS-P1) | Small staged chunks, gate after each, git revert per chunk |
| Checklist-claim drift recurs (rationalized "done") | Plan repeats this cleanup | Exit claims without artifacts | manager | Integration gate requires command+output artifact per exit criterion |

## Rollout and release checklist

- [ ] MV exit evidence archived under `test-results/verification/`.
- [ ] All six milestone exit criteria closed with artifacts.
- [ ] `SwiftlyCodeEdit.app` bundle builds and launches from Finder.
- [ ] Light + dark + reduced-transparency screenshots in `docs/screenshots/`.
- [ ] `swift test`, `pytest tests/`, `./build_debug.sh`, `./scripts/plain_editor_smoke.sh`, `scripts/highlight_benchmark.sh` all green on final main.
- [ ] Milestone checklists archived to `docs/archive/` via `git mv`.
- [ ] README first paragraph matches product state (GitHub About source).
- [ ] Human runs final `git commit` per repo policy.

## Documentation close-out requirements

- Active plan / progress tracker: copy this plan to `docs/active_plans/active/scope_closure_plan.md` at execution start; per-milestone status updates there; move to `docs/archive/` on completion via `git mv`.
- docs/CHANGELOG.md entry: one entry per patch, categorized per REPO_STYLE day-block sections; decision entries for ReferenceFileDocument-vs-bridge and status-metrics approach.
- Archive / closure notes: WS-V1 audit report retained under `docs/active_plans/audits/`; corrected checklist claims noted in the changelog as Decisions and Failures entries.

## Patch plan and reporting format

- Patch 1: validation - verification audit report and checklist corrections (WP-V1).
- Patch 2: app-shell - clipboard paste fix with tests (WP-V2).
- Patch 3: document - non-UTF encoding fallback/error surfacing (WP-V3).
- Patch 4: validation - smoke script honesty + double-launch fix (WP-V4, WP-V5).
- Patch 5: cleaning/highlighting - destructive cleaner deletion, test realignment (WP-V6, WP-V7).
- Patches 6-8: deletions - legacy trees and packages in staged chunks (WP-P1, WP-P2).
- Patch 9: app-shell - SwiftlyCodeEdit rename + .app bundle (WP-P3, WP-P4).
- Patch 10: document - architecture proof spike + decision record (WP-S0).
- Patches 11-14: app-shell/document - SwiftUI App, DocumentGroup, Commands, revalidation (WP-S1..WP-S3).
- Patch 15: support - Application Support path policy helper (WP-F0).
- Patches 16-21: find, theming, syntax dirs, cleaning menu (WP-F1..WP-F4).
- Patches 20-22: highlighting/chrome performance + benchmark (WP-Q1, WP-Q2).
- Patch 23: chrome - glassEffect polish (WP-G1).
- Patch N: tests, migration, docs - release evidence and close-out (WP-G2).

## Open questions and decisions needed

- Document-lifecycle audit findings (2026-07-09, `docs/active_plans/audits/document_lifecycle_audit.md`, 4 HIGH / 2 MEDIUM / 2 LOW): three new WP candidates feed MS planning - (A) undo/dirty-flag integration: `updateChangeCount(.changeDone)` fires on every text change including undo/redo, so a full undo never returns the document to clean and autosave keeps rewriting; also reload never resets the TextView undo stack, so post-reload Undo can replay stale ops against mismatched content (corruption/crash class). (B) external-change conflict handling: `presentedItemDidChange` silently skips reload when the document is dirty (next save overwrites the external change - the general form of today's F1-paste incident) and swallows reload decode failures via `try?` with a stale window and no alert. (C) dirty-state UI: the status bar has no modified indicator. The MS lifecycle-parity contract must cover all three; WP-S0's prototype checklist should add external-change-while-dirty and undo-across-reload cases. Also noted: `UndoManagerRegistration.swift` is excluded dead code - the live undo path is the ad hoc TextView.undoManager wiring in CodeEditApp.swift; MS planning must not assume the registration file is real. Recommended new e2e scenario: edit, external modify, assert no silent overwrite and user notification.
- Modularity directive (user, 2026-07-09): "fixing one thing is breaking others" - MS entry criteria extended: (1) self-test/smoke hooks move out of product views into the validation component (no `#if DEBUG` islands inside chrome); (2) `CodeEditApp.swift` splits into launch, menu, and action-routing files with single owners; (3) smoke/manual testing uses a sandboxed fixtures directory, never real source files (kills the autosave-corruption class). Scouted 2026-07-09: `docs/active_plans/audits/ms_entry_criteria_scout.md` turns all three into dispatch-ready work-package sketches (WP-modularity-1/2/3) with file:line evidence; highest-risk finding is the dead `PlainEditorCommands` SwiftUI Commands builder (CodeEditApp.swift:440-545, zero references, zero tests) sitting beside the live AppKit menu - decide delete-vs-relocate during the split, before WP-S1, so it is not shipped unverified as the SwiftUI replacement.
- Theme schema field set: WS-F2 Patch A proposes it in `docs/THEME_FORMAT.md`; the manager records the decision and proceeds (human reviewer may redirect later; no blocking approval gate).
- `Packages/CodeEditHighlighting`: RESOLVED 2026-07-09 as KEEP. The WP-P1 scout confirmed live dependence: `import CodeEditHighlighting` and the `HighlightSpan` type are used directly by `PlainSyntaxHighlighter.swift` and `CodeFileView.swift`, wired as a nested dependency inside `Packages/CodeEditSyntaxDefinitions/Package.swift` (easy to miss from the root manifest). Not a fold-in or deletion target.
- Benchmark threshold and fixture: 16 ms p95 on a generated 1 MB Swift file is the provisional start; WS-Q1 records the hardware baseline and may revise the threshold as a logged decision.
- `DefaultThemes/*.cetheme` files: resolved - reference inputs only; convert useful colors into the new-format seed themes in WS-F2, then delete the old files as legacy data (no dual-format support).
- ReferenceFileDocument vs NSDocument bridge: resolved by process - WP-S0 proof spike decides with evidence before WP-S1 dispatch.
- WP-V3 decode-fallback breadth (recorded 2026-07-09 from spec review): the explicit Windows-1252 fallback rejects only the 5 undefined CP1252 bytes (0x81, 0x8D, 0x8F, 0x90, 0x9D), so a BOM-less UTF-16 or corrupted text file that defeats the primary NSString heuristic decodes as mojibake rather than raising the alert. The text-or-error window contract still holds (no silent blank). Accepted for MV; WP-S3 revalidation adds test coverage for a BOM-less UTF-16 fixture and a corrupted-text fixture to confirm the primary heuristic wins in practice, and records whether the fallback needs narrowing.
- Update 2026-07-09, empirically pinned (stay-busy encoding-fixture tests in `CodeFileDocumentLifecycleTests.swift`): the reality is WORSE than the mojibake hypothesis - BOM-less UTF-16 (LE and BE) never reaches the fallback; Foundation's heuristic confidently misreports UTF-8 because interleaved 0x00 bytes are valid UTF-8 NULs, so content decodes with embedded NULs (`H\0i\0\n\0`), `sourceEncoding` mislabels `.utf8`, no error raised - silent content corruption, not visible mojibake. Tests `bomlessUTF16LittleEndianSilentlyMisdecodesAsUTF8`/`...BigEndian...` pin this and fail loudly when the behavior changes. FIXED same day: `plausibleBomlessUTF16Encoding(in:)` pre-check (bounded 4 KiB pair sampling, >=2 pairs and >60% [printable-ASCII, 0x00] pattern, BOM short-circuit) decodes BOM-less UTF-16 LE/BE correctly with proper FileEncoding labels; review PASS - adversarial math shows BOM-less UTF-32LE converges to exactly 50% match (cannot cross the 60% gate) and ordinary UTF-8/CP1252 score ~0%. Non-ASCII-heavy UTF-16 stays on the old heuristic path (no regression, boundary accepted). Tests renamed to `bomlessUTF16*DecodesCorrectly`, 10/10 suite green. Residual doc polish (comment on the non-ASCII fallback boundary; note on null-padded binary formats) owed to a docs pass. Also pinned green: UTF-8 BOM stripped on decode; single rejected CP1252 byte throws; 0x93/0x94 reports windows1252.
