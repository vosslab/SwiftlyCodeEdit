# TODO

Backlog scratchpad for small tasks without timelines. Large or milestone-scale
work belongs in [ROADMAP.md](ROADMAP.md) or a dedicated plan under
`docs/active_plans/`, not here.

## Code polish

- Notification-center detachment (SwiftLint sweep, 2026-07-10): `PlainTextEditorView.swift`'s
  `Coordinator.attachNotifications(to:)` calls `NotificationCenter.default.removeObserver(self)`
  outside `deinit` (to re-attach cleanly when the target `TextView` changes). SwiftLint flags
  this as a `notification_center_detachment` violation; left as a behavioral judgment call
  rather than a mechanical fix, since moving the detach into `deinit` only would change
  re-attachment behavior across `TextView` swaps.
- Consolidate the scattered `debugRuntimeLog` call sites in
  `PlainSyntaxHighlighter.swift` and `PlainTextEditorView.swift` into a
  single logging seam; all sites are already `#if DEBUG` guarded so this is
  polish, not a correctness fix (noted in
  `docs/active_plans/audits/ms_entry_criteria_scout.md`).
- Syntax path authority injection seam (WP-F3 fast-follow, from spec review
  2026-07-09): `SyntaxDefinitionRepository` currently discovers user files via
  the package-local `UserSyntaxDirectory` helper, which duplicates the
  `~/Library/Application Support/SwiftlyCodeEdit/Syntax/` path policy from
  `CodeEdit/Features/Support/UserDataDirectories.swift` (SwiftPM dependency
  direction blocks a direct import). Once the SwiftUI app entry (WP-S1) is
  stable, invert: the app calls `UserDataDirectories.discoverFiles(in:)` at
  startup and injects the discovered URLs into the repository before first
  use (settable pre-init configuration point plus a public
  `SyntaxDefinitionLoader.key(for:)` helper so the filename-stem keying lives
  in one place), then delete `UserSyntaxDirectory`'s path constant. Restores
  `UserDataDirectories` as the single path-policy authority per the plan's
  data boundary.
- Theme parser hardening (WP-F2 quality-review TODO 2026-07-09): `ThemeParser`'s
  fixed-depth YAML-subset reader silently degrades out-of-subset constructs
  (anchors `&`, aliases `*`, flow style `{[`, block scalars `| >`) on optional
  keys to the `base_text` fallback instead of rejecting. Bounded and never
  yields a wrong color, but untested: either add a `ThemeParseError` rejection
  for values starting with those sigils, or add a test fixture pinning the
  silent-degrade behavior as intentional.

- Clean-text quality review (WP-F4, 2026-07-10): document the column-counting
  model in `convertTabsToSpaces`
  (`CodeEdit/Features/Editor/PlainEditorTextCleaner.swift`). Columns are counted
  per Unicode scalar, so combining-mark grapheme clusters over-count width by one
  per combining mark. Add a one-line doc-comment caveat to head off a future
  "alignment off with accented text" report. Rare input, low priority.
- Perf note (WP-F4, 2026-07-10): `PlainEditorTextCleaner` builds output strings
  without `reserveCapacity`, matching the pre-existing file-wide pattern. Revisit
  if the keystroke-latency harness starts exercising Clean Text actions on the
  1 MB fixture.
- Dirty-state status-bar field (audit finding F5, MEDIUM, deferred from WP-L1
  2026-07-10): show a modified/edited indicator in the status bar driven by
  `CodeFileDocument.isDocumentEdited`, now that undo/redo track the dirty flag
  correctly. Not a one-line change (needs a `PlainEditorChromeModel` field, a
  refresh from the edit path, and a `PlainEditorStatusBar` label), so it was
  filed here rather than folded into WP-L1. See
  `docs/active_plans/audits/document_lifecycle_audit.md` finding F5.
- Storage-swap gate identity (WP-Q6 review, 2026-07-10):
  `PlainTextEditorView.swift`'s `updateNSViewController` storage-swap gate
  (around lines 148-163) compares content (`textView.string != textStorage.string`)
  while its comment describes object-identity swap detection. No live bug today
  (`CodeFileDocument` reuses one `NSTextStorage` identity post-open), but a future
  document-architecture change that swaps storage objects with identical content
  would silently defeat the gate. Prefer an `===` identity check next time this
  file is touched.

## Verification follow-ups

- Confirm the status bar's encoding label refreshes when
  `CodeFileDocument.read(from:ofType:)` re-detects a different encoding on an
  external reload; the refresh currently relies on the SwiftUI
  `@Published`/`@ObservedObject` update cycle rather than an explicit call
  from the reload path (LOW Finding 7 in
  `docs/active_plans/audits/document_lifecycle_audit.md`).
- Extend `scripts/plain_editor_smoke.sh` with a literal save-to-disk and
  reopen-from-disk round-trip step; the current run exercises the in-memory
  lifecycle via the command self-test (insert/undo/redo/copy/cut/paste/
  cleanText) but never writes the edited buffer to disk and reloads it, so
  save-path regressions are invisible to smoke (found by the WP-P5 reviewer,
  2026-07-09).
- `--kill-after` gap (WP-Q5, 2026-07-10): the debug `--kill-after` flag calls
  `NSApp.terminate(nil)`, which blocks forever on the standard "save changes?"
  alert once a document is dirty, and nothing can dismiss it headless. The
  keystroke-latency harness works around this by polling
  `/tmp/codeedit_runtime.log` for its DONE marker and terminating the process
  itself. Any future E2E harness that dirties a document under `--kill-after`
  will hang the same way. Options: have `--kill-after` mark documents clean
  before terminate, or use `terminateNow` semantics for the debug backstop.
- Shared runtime log single-writer rule (WP-Q5, 2026-07-10):
  `/tmp/codeedit_runtime.log` is truncated on every DEBUG launch, so concurrent
  app launches from different harnesses corrupt in-flight runs.
  `e2e_keystroke_latency.py` refuses to start when another SwiftlyCodeEdit
  process is running, but nothing detects a concurrent harness script. Consider
  a lockfile or a per-run log path.
- Double highlight per edit (DONE 2026-07-10, WP-Q6): resolved. Per-keystroke
  highlighting is now driven solely by the document's edited-range broadcast
  (`CodeFileView`'s `.range` observer -> `PlainSyntaxHighlighter.rehighlight`);
  `onTextChange` no longer schedules a highlight, so exactly one bounded pass
  runs per edit instead of a whole-document pass layered on the edited-range
  signal. Verified by `CodeEditTests/PackageSmoke/BoundedRehighlightTests.swift`
  (bounded coloring stays in sync with a full pass).
- Keystroke baseline variance (WP-Q6 carry-forward, from the WP-Q5 re-review,
  2026-07-10): the baseline is wide (min 2.6 s / median 10.7 s / p95 15.2 s
  over a roughly 33-minute run). Before wiring `--gate`, consider averaging
  multiple runs or controlling thermal state so the 20 percent regression
  threshold is not dominated by jitter.
- Find re-scan debounce (WP-F1 quality review, 2026-07-10): `FindPanelModel.performFind()`
  runs synchronously on the main actor for every find-field keystroke and now also for
  every external document edit while the bar is presented, with no debounce or
  cancellation. On a large file this rescans the whole document per keystroke and can
  stall the UI. A grouped multi-mutation undo (for example undoing a Replace All) fires the
  synchronous whole-document re-scan once per contained mutation rather than once per undo
  action, so a single user gesture triggers N scans in a row. Fold into the M8 large-file
  performance work (debounce the search, or run it off the main actor with cancellation).
- Find regex timeout (WP-F1 quality review, 2026-07-10): `FindEngine.findMatches` builds an
  `NSRegularExpression` with no matching timeout, so a pathological user regex (catastrophic
  backtracking) can hang the UI during a synchronous `performFind()`. Fold into the M8
  large-file performance work (bound the match time or run the regex off the main actor with
  cancellation).
- Replace All stale match list (WP-F1 re-review, 2026-07-10): `FindPanelModel`'s
  `replaceAllMatches` clears the match list manually instead of re-running `performFind()`,
  so replacements that reintroduce new occurrences of the query (for example "aa"->"a" over
  "aaaa" creating adjacent "aa" pairs) do not show as matches until the next external edit.
  Consider ending `replaceAllMatches` with a `performFind()` re-scan so the match list
  reflects the post-replace document.
- ThemeRepositoryTests cache-race flake (found 2026-07-11): an intermittent
  failure in `ThemeRepositoryTests` traced to a test-cache race (parallel test
  cases sharing `ThemeRepository`'s resolved-theme cache), not a product bug.
  Needs a maintainer decision on the fix shape: per-test cache isolation (an
  `overrideRoot`-style seam like `UserSyntaxDirectory`'s) versus serializing
  the affected cases.
- Editor default font renders larger than expected (found 2026-07-09): the app
  default font size is 13.0 (`PlainEditorFontSettings.defaultFontSize` in
  `CodeEdit/Features/Editor/Views/CodeFileView.swift`), but on screen the
  editor text reads noticeably larger than a 14pt terminal on the same
  display, roughly double per user observation. Investigation so far found no
  scaling bug in the font construction (clean `monospacedSystemFont(ofSize:)`,
  no `* 2`, and no magnification/scaleFactor in `PlainTextEditorView` or the
  vendored `CodeEditTextView`). Likely a line-height/metrics or
  display-scaling effect, not a settable point-size bug. Follow-up: confirm
  the perceived size against the vendored `CodeEditTextView`
  line-height/typesetting and decide the target default (user prefers roughly
  a 14pt-terminal appearance). Screenshots are separately forced to 14pt via
  `scripts/capture_screenshots.sh`; this item is about the live-app default
  only.
- Lifecycle test uses real-time sleeps instead of a deterministic hook (found
  2026-07-09): `CodeEditTests/PackageSmoke/CodeFileDocumentLifecycleGapTests.swift`
  uses two `Task.sleep(nanoseconds: 200_000_000)` (200ms each) waits for
  `presentedItemDidChange`'s async task. Replace with a deterministic
  drain/completion hook (same pattern as the status reporter's
  `drainHeavyRecomputeForTesting`) so the test does not spend ~400ms of real
  time per run. Pre-existing, non-blocking; flagged by the test audit.
- Optional final-gate re-verification (found 2026-07-09): the last full gate
  (build / swift test / plain_editor_smoke / pytest) ran on the final code
  during the planning-tag cleanup; a later change touched only
  `scripts/capture_screenshots.sh` and regenerated PNGs (no Swift/test logic).
  A fresh full-gate run on the exact pre-commit tree is belt-and-suspenders,
  not required, since the code gates already passed on the final source.
- SETTINGS_APPLIED smoke gate (DONE 2026-07-10): the DEBUG-only
  `CODEEDIT_SETTINGS_APPLY_SELF_TEST` seam
  (`CodeEdit/Features/Settings/PlainEditorSettingsApplySelfTest.swift`) now
  performs a real post-mount font-size and theme change through the same
  `@AppStorage` path the Settings window uses, so both
  `SETTINGS_APPLIED key=fontSize` and `key=theme` fire from their
  view-application sites and `scripts/plain_editor_smoke.sh` gates on them
  plus the `SETTINGS_APPLY_SELF_TEST fontRestored=true themeRestored=true`
  reversal line. The theme name change is made observable with only one
  bundled theme by a DEBUG in-memory theme registry on `ThemeRepository`
  (no user Themes-dir write); the font marker uses the existing
  compare-against-live-`textView.font` design, which detects a genuine
  post-mount change (the cold-seed limitation only affected creation-time
  comparison). The seam restores every captured value, so the user's stored
  preferences are unchanged after the run.
