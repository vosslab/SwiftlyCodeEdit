# Milestone 3 To-Do Checklist

Milestone 3 tracks the major feature gaps between docs/SCOPE.md must-haves and the code as it
stands after Milestone 1 and Milestone 2. Every box below is unchecked: nothing in this file is
done yet, even where a foundation already shipped (noted in prose next to the relevant item).
Execution detail, owners, and acceptance criteria for each gap live in
docs/archive/scope_closure_plan.md; this checklist is the human-readable tracking
layer over those work packages, not a replacement for them.

---

## AppKit shell to SwiftUI (MS, WP-S1..S3)

Goal: replace the AppKit app shell with a SwiftUI `App` + `DocumentGroup`, keeping AppKit only
inside the isolated `TextView` bridge adapter.

- [ ] App launches via a SwiftUI `App` + `DocumentGroup` scene, replacing `@main enum
  CodeEditMain` and the hand-built `NSDocument`/`NSWindow` chain in `CodeEdit/CodeEditApp.swift`.
  Document-model decision (WP-S0): keep `CodeFileDocument` as the `NSDocument` model behind a
  `DocumentGroup` bridge, not a SwiftUI-native `ReferenceFileDocument` -- a measured prototype
  failed the autosave-debounce and same-`NSTextStorage`-reload gates -- with the single sanctioned
  document-layer AppKit bridge file `CodeFileDocumentBridge.swift` created by WP-S1; see
  docs/active_plans/decisions/document_architecture_decision.md.
- [ ] SwiftUI `Commands` menu replaces the hand-built `NSMenu` (`PlainEditorMainMenu`); every
  File/Edit/Find command reaches the active editor and keyboard shortcuts still work.
- [ ] AppKit survives only inside the isolated `TextView` bridge adapter
  (`PlainTextEditorView.swift` over `CodeEditTextView.TextView`), per the SwiftUI-first
  principle recorded in docs/HUMAN_GUIDANCE.md. Spike decision: SwiftUI's `TextEditor` failed
  the editor gates (keystroke p95 140.56 ms vs a 16 ms budget, span-apply 159.07 ms vs 50 ms,
  cursor collapses to end-of-file on every attribute write, and a ~1 MB document never mounts),
  so the TextKit bridge stays as the one replaceable adapter -- see
  docs/active_plans/decisions/text_engine_decision.md.
- [ ] Superseded AppKit shell code (`PlainEditorMainMenu`, the old `NSDocument`-driven window
  creation path, and any dead `PlainEditorCommands`) is deleted, not left dormant.

## Find and Replace (WP-F1)

Goal: give the editor a working in-document find/replace surface; today the Find menu items send
`NSTextView.performFindPanelAction` to a `TextView` that is a plain `NSView` and never responds.

- [x] Cmd-F opens a find bar with literal and regex modes. Evidence: `CodeEdit/Features/Find/`
  (`FindPanelView.swift`, `FindEngine.swift`) plus the WP-F1 patch 18 entry in
  docs/CHANGELOG.md (2026-07-10 day block).
- [x] Next/previous match navigation moves the visible selection. Evidence:
  `CodeEditTests/PackageSmoke/FindPanelTests.swift` (next/previous and wrap-around cases).
- [x] Replace and Replace All mutate the active document and are undoable as a single operation.
  Evidence: `FindPanelTests.swift` Replace All single-undo case.
- [x] The panel is ported from the CodeEditSourceEditor find implementation
  (`Packages/CodeEditSourceEditor`), not built from scratch. Evidence: WP-F1 patch 18 entry in
  docs/CHANGELOG.md documents the port; `Packages/` no longer contains `CodeEditSourceEditor`
  (deleted in WP-F1 patch 19).

## Theme data files (WP-F2)

Goal: move syntax colors out of hardcoded Swift and into the data-driven format already
specified in docs/THEME_FORMAT.md.

- [x] A loader reads themes from the docs/THEME_FORMAT.md YAML schema (schema already shipped;
  the loader and runtime wiring are not). Evidence: `CodeEdit/Features/Theming/ThemeParser.swift`
  plus the WP-F2 entry in docs/CHANGELOG.md (2026-07-10 day block).
- [x] Bundled default light and dark themes ship as data files, not Swift structs. Evidence:
  `CodeEdit/Features/Theming/Resources/Themes/standard.yaml`.
- [x] User themes load from `~/Library/Application Support/SwiftlyCodeEdit/Themes/` with live
  switching, no rebuild required. Evidence: `CodeEdit/Features/Theming/ThemeRepository.swift`
  plus the WP-F5 patch 15 entry in docs/CHANGELOG.md (theme-name change invalidates the
  resolved-theme cache so a just-edited user theme file is re-read).
- [x] The hardcoded `PlainSyntaxTheme` palette in `PlainSyntaxHighlighter.swift` is removed.
  Evidence: no `PlainSyntaxTheme` struct remains anywhere under `CodeEdit/`; the only surviving
  reference is a porting-history doc comment in `CodeEdit/Features/Theming/SyntaxTheme.swift:22`.

## User syntax definitions (WP-F3)

Goal: let users add a new highlighted language without rebuilding the app; today all 409 Kate
XML definitions are compiled into the bundle.

- [ ] A Kate XML file dropped into
  `~/Library/Application Support/SwiftlyCodeEdit/Syntax/` highlights a new language after a
  relaunch, with no rebuild.
- [ ] A user syntax file wins over a bundled file on name collision.
- [ ] A malformed user XML file is logged and skipped; the app keeps running.

## Clean Text menu (WP-F4)

Goal: grow Clean Text from the single trailing-whitespace-trim action shipped in Milestone 2
into the full safe cleaning set.

- [x] Normalize line endings to LF or CRLF. Evidence: `PlainEditorTextCleaner.normalizeLineEndings`
  plus the WP-F4 patch 1/2 entries in docs/CHANGELOG.md (2026-07-10 day block).
- [x] Ensure a final newline. Evidence: `PlainEditorTextCleaner.ensureFinalNewline`.
- [x] Convert tabs to spaces. Evidence: `PlainEditorTextCleaner.convertTabsToSpaces`.
- [x] Convert spaces to tabs. Evidence: `PlainEditorTextCleaner.convertSpacesToTabs`.
- [x] Normalize smart punctuation to ASCII as an explicit opt-in action (never applied silently).
  Evidence: `PlainEditorTextCleaner.normalizeSmartPunctuationToASCII`, wired as its own labeled
  Clean Text menu item in `CodeEdit/App/Commands/EditorCommands.swift`.
- [x] Each action is undoable and covered by a unit test with inline fixtures. Trailing-whitespace
  trim already shipped in Milestone 2 and is the one action already meeting this bar. Evidence:
  `PlainEditorTextCleanerTests.swift` (inline fixtures per transform) and
  `EditorCommandRouterRoutingTests.cleanLineEndingsToLFIsSingleUndoableOperation`.

## Proper settings dialog (WP-F5)

Goal: replace command-bar-only controls for static preferences with a standard macOS Settings
scene; candidate WP-F5, user-requested 2026-07-09, with execution detail to be added to
`docs/archive/scope_closure_plan.md`.

- [x] A standard macOS Settings scene (Cmd+,) built in SwiftUI per the SwiftUI-first principle in
  `docs/HUMAN_GUIDANCE.md`, replacing command-bar-only controls for static or permanent
  preferences. Closed 2026-07-10, WP-F5 review PASS: Settings scene (patches 15-16) built via
  the standard Cmd+, SwiftUI Settings scene.
- [x] Font family and size selection persisted across launches. Foundation already shipped: the
  `PlainEditor.fontFamily` and `PlainEditor.fontSize` AppStorage keys are currently driven from the
  command bar's A- and A+ controls. Closed 2026-07-10, WP-F5 review PASS: font family/size now
  live in the Settings scene with the same persisted AppStorage keys, gated by the
  `SETTINGS_APPLIED` fontSize marker in `scripts/plain_editor_smoke.sh`.
- [x] Theme selection surface that binds to the WP-F2 theme loader when it lands. Closed
  2026-07-10, WP-F5 review PASS: theme picker binds to the WP-F2 in-memory theme registry, gated
  by the `SETTINGS_APPLIED` theme marker in the smoke script.
- [x] Editor defaults for indentation (tabs versus spaces, width) and the default line ending for
  new files. Closed 2026-07-10, WP-F5 review PASS: indentation style/width and default line
  ending are persisted Settings-scene fields per the WP-F5 review.
- [x] Settings changes apply live to open windows without relaunch. Closed 2026-07-10, WP-F5
  review PASS: live-apply observability seam plus `SETTINGS_APPLIED` fontSize/theme gates in
  `scripts/plain_editor_smoke.sh` confirm changes reach open windows without relaunch.

## Large-file performance (WP-Q1 follow-on / WP-Q2)

Goal: keep typing responsive on large files; today every keystroke triggers a full-document
rehighlight and a full status recomputation.

- [x] Highlighting is viewport-first so a 1 MB-plus file paints fast on cold open. Evidence: the
  WP-Q6 entry in docs/CHANGELOG.md (2026-07-10 day block) describes
  `PlainSyntaxHighlightFullPass.swift`'s "viewport-first cold paint".
- [x] Keystroke-triggered rehighlighting is bounded to the edited region (edited-line window or
  visible range), not the whole document. Evidence: WP-Q6 `scheduleBoundedRehighlight` (edited
  line plus 40 context lines each side), `CodeEditTests/PackageSmoke/BoundedRehighlightTests.swift`.
- [ ] Status bar recomputation no longer rescans the full document on every keystroke. NOT met:
  the WP-Q2 follow-on entry in docs/CHANGELOG.md states the cursor scan is still "the sole
  O(document) work left after WP-Q2" -- it is now measured separately (`STATUS_REFRESH_MS`
  marker) but has not been eliminated or bounded.
- [x] A repeatable benchmark proves p95 keystroke handling under 16 ms on a 1 MB source file,
  recorded in `test-results/`. Evidence: WP-Q8 entry in docs/CHANGELOG.md, mutation p95 1.87 ms
  (PASS) recorded in `test-results/perf/keystroke_latency.txt`.

## Liquid Glass chrome (WP-G1)

Goal: move the command ribbon and status bar from legacy `.regularMaterial` to macOS 26
`glassEffect` styling per docs/LIQUID_GLASS.md.

- [x] Command ribbon adopts `glassEffect` per docs/LIQUID_GLASS.md. Superseded by a stronger
  fix: the custom ribbon was replaced with a native macOS 26 grouped-capsule `ToolbarItemGroup`
  toolbar (architect decision `docs/active_plans/decisions/native_toolbar_decision.md`), which
  adopts Liquid Glass automatically from the OS with no custom `glassEffect` call needed; the
  layout is now finalized at `window.toolbarStyle = .unified` plus a custom `ToolbarButtonLabel`
  horizontal icon+text row (`CodeFileView.swift`), 7 items across 4
  `ToolbarItemGroup(placement: .navigation)` clusters, and the base capsule glass carries a SHIP
  verdict (`docs/active_plans/reports/wp_g2_glass_evidence_report.md`). Note: the toolbar's color
  is native-OS-glass only -- a custom color tint behind the bridged `NSToolbar` was found
  architecturally infeasible (see the 2026-07-11 Decisions and Failures entry in
  docs/CHANGELOG.md), so the toolbar correctly tracks light/dark automatically but carries no
  accent tint; the status bar carries the chrome's accent color instead.
- [x] Status bar adopts `glassEffect` per docs/LIQUID_GLASS.md. The base glass
  (`PlainEditorStatusBar.body` in `CodeFileView.swift`,
  `.glassEffect(.regular.tint(glassTint), in: Rectangle())`) carries a SHIP verdict, and the
  status bar now also carries a working accent-color pop: `CodeFileWindowBridge` sets
  `window.backgroundColor` to a gentle accent blend (4% light / 7% dark) so the glass has real
  color to sample, per the 2026-07-11 entry in docs/CHANGELOG.md. Known limitation, not blocking:
  the backdrop color is resolved once at window creation and does not live-re-tint if the system
  appearance toggles while the window stays open.
- [x] The editor text surface itself is left untouched by glass styling; only chrome changes.
  Evidence: `docs/active_plans/reports/wp_g2_glass_evidence_report.md` records the editor body
  unchanged (`.textBackgroundColor`); no `glassEffect` call touches the text view.
- [ ] Captured evidence exists for light mode, dark mode, and reduced-transparency. Light and
  dark are captured (`docs/screenshots/glass_toolbar_light.png`,
  `docs/screenshots/glass_toolbar_dark.png`, regenerated with the final chrome via the new
  `scripts/capture_screenshots.sh`), but reduced-transparency has no captured screenshot
  evidence -- only an architecture guarantee (`@Environment(\.accessibilityReduceTransparency)`
  fallback to an opaque fill), per Part E of `docs/active_plans/reports/wp_g2_glass_evidence_report.md`.

## Document lifecycle correctness (candidate work packages from docs/active_plans/audits/document_lifecycle_audit.md)

Goal: close the four HIGH-severity findings from the pre-migration document lifecycle audit
before or during the SwiftUI shell migration.

- [ ] Undo/redo clears the document's dirty flag once the buffer matches the last-saved content,
  instead of `updateChangeCount(.changeDone)` firing unconditionally on every text-change
  callback including undo/redo replays.
- [ ] An external file change while the document has unsaved edits surfaces a conflict to the
  user instead of the current silent no-op (`presentedItemDidChange`'s guard falls through with
  no reload and no alert when `isDocumentEdited` is true).
- [ ] Reload surfaces decode errors instead of swallowing them with `try?`, so an external
  rewrite in an unsupported encoding produces a visible alert rather than a stale window with an
  already-advanced modification date.
- [ ] Reload resets the `TextView`'s undo stack after loading new content into the shared text
  storage, so a post-reload Undo cannot replay a stale operation against offsets that no longer
  match the current text.

---

## Milestone 3 verification

- [ ] `pytest tests/test_markdown_links.py` passes.
- [ ] `pytest tests/test_ascii_compliance.py` passes.
- [ ] `./build_debug.sh` passes.
- [ ] `./scripts/plain_editor_smoke.sh` passes.
- [ ] `swift test` passes.
- [ ] `docs/CHANGELOG.md` records each closed gap.
