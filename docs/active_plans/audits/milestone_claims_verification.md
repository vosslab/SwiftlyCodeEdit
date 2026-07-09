# Milestone claims verification audit

Audit date: 2026-07-09. Auditor: WP-V1 (scope_closure_plan.md). This is the
pre-fix evidence baseline: every command below ran against the repo before any
WP-V2 through WP-G2 fix landed, so future work packages can diff against it.

## Baseline verification commands

| Command | Result | Evidence file |
| --- | --- | --- |
| `./build_debug.sh` | PASS: `Build complete! (24.34s)`, exit 0 | `test-results/verification/build_debug.txt` |
| `swift test` (root package) | PASS: `Test run with 14 tests in 5 suites passed`, exit 0 | `test-results/verification/swift_test.txt` |
| `swift test --package-path Packages/CodeEditHighlighting` | PASS: `Test run with 5 tests in 1 suite passed`, exit 0 | `test-results/verification/swift_test_highlighting.txt` |
| `pytest tests/` | PASS: `4077 passed in 3.86s`, exit 0 | `test-results/verification/pytest.txt` |
| `./scripts/plain_editor_smoke.sh` | PASS: `Plain editor smoke passed`, exit 0, screenshot captured | `test-results/verification/smoke.txt` |
| `git diff --check` | PASS: exit 0, no output | run inline, not saved (no output to save) |
| `git status --porcelain docs/SCOPE.md` | PASS: exit 0, no output (no local diff) | run inline, not saved (no output to save) |

All five headline pass/fail claims in the "Latest validation snapshot" /
"Latest post-merge validation snapshot" blocks are numerically CONFIRMED: the
test counts (14/5, 5/1, 4077), the build success, and the smoke pass all
reproduce exactly as claimed. The problem this audit found is not that these
commands fail -- they pass -- it is that four specific claims about what the
passing commands prove are false or rationalized. See "Known-false claims"
below.

## Strict claim table

One row per checklist section-level claim, plus one row per individually named
false/rationalized claim from the audit brief. CONFIRMED means the claim was
independently reproduced with a command and its output. CORRECTED means the
claim as written is false or overstated; the true state and owning work
package are given.

| Claim | Source of truth | Evidence command | Result | Status | Owning WP |
| --- | --- | --- | --- | --- | --- |
| `./build_debug.sh` passes | MILESTONE1_CHECKLIST.md:174, MILESTONE2_CHECKLIST.md:729 | `./build_debug.sh` | `Build complete! (24.34s)`, exit 0 | CONFIRMED | -- |
| `./scripts/plain_editor_smoke.sh` passes with normal GUI permissions | MILESTONE1_CHECKLIST.md:175, MILESTONE2_CHECKLIST.md:730 | `./scripts/plain_editor_smoke.sh` | `Plain editor smoke passed`, exit 0, screenshot written | CONFIRMED (script does pass on this machine) | -- |
| `swift test` passes with 14 tests in 5 suites | MILESTONE1_CHECKLIST.md:171, MILESTONE2_CHECKLIST.md:726 | `swift test` | `Test run with 14 tests in 5 suites passed` | CONFIRMED | -- |
| `swift test --package-path Packages/CodeEditHighlighting` passes with 5 Kate XML highlighter tests | MILESTONE1_CHECKLIST.md:172, MILESTONE2_CHECKLIST.md:727 | `swift test --package-path Packages/CodeEditHighlighting` | `Test run with 5 tests in 1 suite passed` (suite "Kate XML syntax highlighter") | CORRECTED: count is real, but the suite exercises the dead `KateXMLSyntaxHighlighter` engine, not the live `KateContextRuleInterpreter` engine the app actually runs. See "Wrong-engine test coverage" below. | WP-V7 |
| `pytest tests/` passes with 4077 Python hygiene/doc tests | MILESTONE1_CHECKLIST.md:173, MILESTONE2_CHECKLIST.md:728 | `pytest tests/` | `4077 passed in 3.86s` | CONFIRMED | -- |
| `git diff --check` is clean | MILESTONE1_CHECKLIST.md:176, MILESTONE2_CHECKLIST.md:731 | `git diff --check` | exit 0, no output | CONFIRMED | -- |
| `docs/SCOPE.md` has no local diff | MILESTONE1_CHECKLIST.md:177, MILESTONE2_CHECKLIST.md:732 | `git status --porcelain docs/SCOPE.md` | exit 0, no output | CONFIRMED | -- |
| Build and Smoke Test section (M1 lines 5-9) | MILESTONE1_CHECKLIST.md:5-9 | `./build_debug.sh`; `./scripts/plain_editor_smoke.sh` | both pass | CONFIRMED | -- |
| Runtime Launch Path section (M1 lines 13-21) | MILESTONE1_CHECKLIST.md:13-21 | smoke runtime log | log lines "Plain editor launch path ready", "Loaded document:", "Created editor window", "PlainTextEditorView created", "PlainTextEditorView requested first responder" all present | CONFIRMED | -- |
| File-Backed Editor Path section (M1 lines 25-32) | MILESTONE1_CHECKLIST.md:25-32 | smoke runtime log | `PlainSyntaxHighlighter` logs show file text reaching the text storage; window title uses opened file name (per smoke script `-t` flag match) | CONFIRMED | -- |
| Editing Behavior section, Undo/Redo/Cut/Copy/Select All (M1 lines 36-43) | MILESTONE1_CHECKLIST.md:36-43 | smoke command self-test line | `insert=true undo=true redo=true selectAll=true copy=true cut=true paste=true cleanText=true cleanUndo=true cleanRedo=true` | CONFIRMED (self-test proves internal round trip only; see Paste correction below) | -- |
| Editing Behavior: Paste works | MILESTONE1_CHECKLIST.md:42 | `CodeEdit/CodeEditApp.swift:245,280-288` | `copiedText` private buffer is set on Copy/Cut and consulted with `copiedText ?? NSPasteboard.general.string(...)` on Paste, so Paste prefers the stale internal buffer over the system pasteboard | CORRECTED: Paste "works" only for round trips through this app's own Copy/Cut; pasting content copied from another app is silently overridden whenever `copiedText` is non-nil. Confirmed by reading `CodeEdit/CodeEditApp.swift:286-295`. | WP-V2 |
| Confirm Find works if it is in the current required path (M1 line 44) | MILESTONE1_CHECKLIST.md:44 | text of the item itself | item already states Find is deferred and only menu placeholders remain | CONFIRMED as-written (M1 does not claim Find works) | -- |
| Save Behavior section (M1 lines 48-56) | MILESTONE1_CHECKLIST.md:48-56 | smoke command self-test + package lifecycle test | `CodeFileDocumentLifecycleTests.lifecyclePersistsSyntheticEdit()` passed; smoke log shows Clean Text/save markers | CONFIRMED | -- |
| Menus and Commands: Find is registered if in required path (M1 line 71) | MILESTONE1_CHECKLIST.md:71 | smoke runtime log line 8 | `Main menu items:` log includes `[Find..., Find and Replace...]` | CONFIRMED text is present; see wider Find correction below | see WP-F1 row |
| Plain Editor Architecture Cleanup / Swift 6 Cleanup / Resource Warnings sections (M1 lines 75-105) | MILESTONE1_CHECKLIST.md:75-105 | `./build_debug.sh` output | build completes with only pre-existing deprecation warnings (`init(contentsOfFile:)`), no unhandled-resource warnings observed in this run | CONFIRMED | -- |
| Screenshot and GUI Evidence section (M1 lines 109-115) | MILESTONE1_CHECKLIST.md:109-115 | `scripts/plain_editor_smoke.sh:68-79` | script uses capture mode (`-f`), asserts `test -s "$SCREENSHOT_FILE"`, and exits non-zero (via `set -e`) on any failure -- matches "keep failures visible" claim for THIS section | CONFIRMED for this section; the mismatch is in `docs/SMOKE_TEST.md`'s "optional"/"non-fatal" wording, not here | -- |
| Automated Validation section (M1 lines 119-129) | MILESTONE1_CHECKLIST.md:119-129 | `scripts/plain_editor_smoke.sh:51-79` | script asserts every named marker via `wait_for_line`; screenshot artifact validated with `test -s` | CONFIRMED | -- |
| Documentation / Final Milestone Checks / SwiftPM Build Direction sections (M1 lines 133-167) | MILESTONE1_CHECKLIST.md:133-167 | `docs/CODE_ARCHITECTURE.md`, `docs/FILE_STRUCTURE.md`, `docs/SMOKE_TEST.md` exist; `./build_debug.sh` uses `swift build` | files present, build uses SwiftPM | CONFIRMED | -- |
| Milestone 2 Entry Criteria / Product Scope Alignment (M2 lines 26-49) | MILESTONE2_CHECKLIST.md:26-49 | `./build_debug.sh`; `./scripts/plain_editor_smoke.sh`; repo scan | both green; no terminal/Git/IDE source trees found under required build path | CONFIRMED | -- |
| Top Command Bar section (M2 lines 86-121) | MILESTONE2_CHECKLIST.md:86-121 | smoke runtime log | `Plain editor command ribbon ready`; command self-test proves New/Open/Save/Undo/Redo/Clean Text paths fire | CONFIRMED | -- |
| Bottom Status Bar section (M2 lines 141-177) | MILESTONE2_CHECKLIST.md:141-177 | smoke runtime log | `Plain editor status: cursor=... lines=... words=... chars=... indent=... encoding=UTF-8 lineEnding=LF syntax=Swift` present and updates after edits | CONFIRMED | -- |
| Command bar works in dark mode (M2 line 107) | MILESTONE2_CHECKLIST.md:107 | claim text vs. `docs/screenshots/codeedit_window.png` | only one screenshot exists in the repo, captured under the default (light) appearance; no dark-mode capture exists anywhere | CORRECTED: "Resolved through ... standard button styling" is a design argument, not evidence; no dark-mode screenshot or dark-mode smoke run backs the claim. | WP-G2 |
| Status bar works in dark mode (M2 line 163) | MILESTONE2_CHECKLIST.md:163 | same as above | same as above | CORRECTED, same reasoning as above | WP-G2 |
| App can run in dark mode (M2 line 188) | MILESTONE2_CHECKLIST.md:188 | same as above; `docs/screenshots/` directory listing | `docs/screenshots/codeedit_window.png` is the only screenshot artifact; smoke script (`scripts/plain_editor_smoke.sh`) never toggles or captures dark appearance | CORRECTED: dark mode is asserted "validated" but no dark-mode screenshot, log marker, or automated appearance-toggle check exists anywhere in the repo. The claim rests entirely on "semantic colors should adapt," which is a design argument, not evidence. | WP-G2 |
| Selection/caret/syntax/disabled-state readable in dark mode (M2 lines 196-202) | MILESTONE2_CHECKLIST.md:196-202 | same as above | same as above | CORRECTED, same reasoning | WP-G2 |
| Save screenshot evidence for dark mode when display access exists (M2 line 209) | MILESTONE2_CHECKLIST.md:209 | `docs/screenshots/` directory listing | no dark-mode screenshot file exists; item explicitly redefines the gate away ("not a separate Milestone 2 gate") rather than producing the requested evidence | CORRECTED: the checklist item asks for dark-mode screenshot evidence and the "Resolved" text explains why none was captured, which is not the same as satisfying the item. | WP-G2 |
| Liquid Glass choices work in dark mode (M2 line 243) | MILESTONE2_CHECKLIST.md:243 | same as above | same as above | CORRECTED, same reasoning | WP-G2 |
| Dark mode is validated (M2 Final Checks, line 702) | MILESTONE2_CHECKLIST.md:702 | same as above | same as above | CORRECTED: this is the headline claim in the Final Checks block; it should read "not validated with evidence" pending a real dark-mode capture. | WP-G2 |
| Syntax highlighting colors are theme-aware (M2 line 278) | MILESTONE2_CHECKLIST.md:278 | `CodeEdit/Features/Editor/Views/PlainSyntaxHighlighter.swift:104-171` | `PlainSyntaxTheme` is a hardcoded Swift struct with two fixed variants (`standard`, `rotated`) selected only by the `SYNTAX_THEME_VARIANT` env var; there is no theme file, no user-selectable theme, no light/dark-specific palette | CORRECTED: colors use semantic `NSColor` constants (so they adapt to light/dark automatically), but "theme-aware" implies data-driven/user-selectable theming, which does not exist yet. That is exactly the gap WP-F2 (theme data format and loader) is scoped to close. | WP-F2 |
| Report non-UTF-8 encodings when detectable / keep unknown encoding fallback readable and non-blocking (M2 lines 339-340) | MILESTONE2_CHECKLIST.md:339-340 | `CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift:126-143`, `CodeEdit/Features/Documents/CodeFileDocument/FileEncoding.swift:10-13` | `FileEncoding` supports only `utf8`, `utf16BE`, `utf16LE`; `read(from:ofType:)` silently `return`s with no thrown error and no content set when `NSString.stringEncoding` cannot match one of those three encodings | CORRECTED: a file in Latin-1, Windows-1252, or any encoding outside the three supported cases opens as a blank, un-erred window instead of "readable and non-blocking" -- it is silently empty, which a user cannot distinguish from an empty file. This is the "silent-blank non-UTF open" bug named in the audit brief. | WP-V3 |
| Confirm standard menu commands remain available, ... including File/Edit/Find entries (M2 line 657) | MILESTONE2_CHECKLIST.md:657 | `CodeEdit/CodeEditApp.swift:376-380,487-496`; `Packages/CodeEditTextView/Sources/CodeEditTextView/TextView/TextView.swift:37` | Both Find menu items send `#selector(NSTextView.performFindPanelAction(_:))`; the app's actual text-editing surface, `TextView`, is declared `open class TextView: NSView` (not `NSTextView`) and implements no `performFindPanelAction` method anywhere in `Packages/CodeEditTextView`; `NSApp.sendAction` finds no responder for the selector | CORRECTED: "available" here means "visible in the menu," not "functional." Clicking Find... or Find and Replace... does nothing observable -- no panel opens, no beep, no log line. This is the "dead Find menu items" issue named in the audit brief. | WP-F1 |
| Find and Replace section: active Find/Replace deferred, only menu placeholders present (M2 lines 472-494) | MILESTONE2_CHECKLIST.md:472-494 | same evidence as above | the checklist text itself already says "menu placeholders," which is consistent with the dead-selector finding above | CONFIRMED as accurately hedged; no correction needed here (the overclaim is in line 657, not this section) | -- |
| Clean Text Command section (M2 lines 404-428) | MILESTONE2_CHECKLIST.md:404-428 | smoke command self-test line | `cleanText=true cleanUndo=true cleanRedo=true` in the self-test summary; `PlainTextCleanerTests` swift test passed | CONFIRMED | -- |
| Undo and Redo Product Validation section (M2 lines 438-462) | MILESTONE2_CHECKLIST.md:438-462 | `UndoManagerRegistrationTests` swift test; smoke self-test | `typingAndUndoRedoUpdateTheTextView()` passed; self-test `undo=true redo=true` | CONFIRMED | -- |
| App Intents Smoke Hooks section (M2 lines 502-542) | MILESTONE2_CHECKLIST.md:502-542, APP_INTENTS_SMOKE_TEST_GOAL.md | `CodeFileDocumentLifecycleTests.lifecyclePersistsSyntheticEdit()` swift test | passed | CONFIRMED | -- |
| App Intents Smoke Test Goal: Status "Complete for the current milestone" | APP_INTENTS_SMOKE_TEST_GOAL.md:3-12 | same test + `./scripts/plain_editor_smoke.sh` | package test and live smoke both pass | CONFIRMED for the narrow goal as scoped (open/report/edit/save/reopen); does not certify Paste or non-UTF handling, which are separately corrected above | -- |
| Repo Cleanup During Milestone 2 (M2 lines 601-618) | MILESTONE2_CHECKLIST.md:601-618 | `grep -rln "KateXMLSyntaxHighlighter"`, `grep -rln "PlainEditorSyntaxStyler"` | confirms dead code exists (`PlainEditorSyntaxStyler.swift`), which the checklist itself does not claim to have removed (WP-V7/WP-P1 own that cleanup) | CONFIRMED as-written (no overclaim; cleanup is explicitly future work) | -- |
| Performance and Responsiveness section (M2 lines 628-646) | MILESTONE2_CHECKLIST.md:628-646 | smoke runtime log timings | `PlainSyntaxHighlighter finish ... elapsedMs=0` to `elapsedMs=3379` (first run cold, subsequent runs cached at 0-1ms) on a 10,474-character file | CONFIRMED | -- |
| Accessibility and Native Mac Behavior section (M2 lines 654-674), excluding line 657 | MILESTONE2_CHECKLIST.md:654-674 | smoke runtime log | standard SwiftUI buttons/text used; first-responder log lines present | CONFIRMED | -- |

## Known-false claims (explicit findings)

1. **Dead Find menu items.** `CodeEdit/CodeEditApp.swift:377,380,489,496` wire
   both Find menu items to `#selector(NSTextView.performFindPanelAction(_:))`.
   The live editing surface is `TextView`, declared at
   `Packages/CodeEditTextView/Sources/CodeEditTextView/TextView/TextView.swift:37`
   as `open class TextView: NSView`, not `NSTextView`, and no file under
   `Packages/CodeEditTextView` implements `performFindPanelAction`. Clicking
   either Find menu item is a silent no-op. Owning work package: WP-F1 (port
   find panel).

2. **"Non-fatal screenshot" claim versus a hard-fail script.**
   `docs/SMOKE_TEST.md:30,35` (not owned by this audit -- flagged here, not
   edited) describes screenshot capture as "optional" and records "the exact
   TCC denial if screenshots cannot be captured," implying a soft/non-fatal
   path. The actual script, `scripts/plain_editor_smoke.sh`, opens with
   `set -euo pipefail` (line 2), calls `exit 1` if the screenshot helper binary
   is missing (lines 68-71), and asserts `test -s "$SCREENSHOT_FILE"` with no
   `|| true` guard (line 77) -- any screenshot failure aborts the entire smoke
   run, not just the screenshot step, and there is no `--no-screenshot` flag
   anywhere in the script. Owning work package: WP-V4 (make smoke script
   honest).

3. **Dark mode "validated" with no dark capture.** Every dark-mode line in
   MILESTONE2_CHECKLIST.md (lines 107, 163, 188, 196, 198, 200, 202, 209, 243,
   702, and others) is marked resolved by citing semantic/system color usage,
   not a dark-mode screenshot or log assertion. `docs/screenshots/` contains
   exactly one file, `codeedit_window.png`, captured by the smoke script under
   the machine's default (light) appearance. No file, log line, or test
   toggles or captures dark appearance anywhere in the repo. Owning work
   package: WP-G2 (release evidence and docs close-out).

4. **Wrong-engine test coverage.** The 5 tests in
   `Packages/CodeEditHighlighting/Tests/CodeEditHighlightingTests/KateXMLSyntaxHighlighterTests.swift`
   exercise `KateXMLSyntaxHighlighter`
   (`Packages/CodeEditHighlighting/Sources/CodeEditHighlighting/KateXMLSyntaxHighlighter.swift`),
   which is used only by `CodeEdit/Features/Editor/Views/PlainEditorSyntaxStyler.swift`
   -- a file with no other reference anywhere in the app (confirmed by
   `grep -rln "PlainEditorSyntaxStyler\b"` returning only its own file). The
   live editor path is `CodeEdit/Features/Editor/Views/PlainSyntaxHighlighter.swift`,
   which calls `CodeEditSyntaxDefinitions.highlightSpans`, which dispatches to
   `KateContextRuleInterpreter` (an `enum` at
   `Packages/CodeEditSyntaxDefinitions/Sources/CodeEditSyntaxDefinitions/CodeEditSyntaxDefinitions.swift:575`).
   The 5 package tests certify a dead code path; the live engine has its own
   coverage under `CodeEditTests/PackageSmoke/PlainSyntaxHighlighterTests.swift`
   (5 tests, confirmed passing above), but the milestone snapshots cite the
   `CodeEditHighlighting` package tests as if they cover the same engine.
   Owning work package: WP-V7 (retarget highlighter tests to live engine; also
   delete the dead `KateXMLSyntaxHighlighter`/`PlainEditorSyntaxStyler` pair).

## Newly discovered bugs / follow-on work package candidates

- `CodeEdit/CodeEditApp.swift:280-295`: clipboard `Paste` prefers an internal
  `copiedText` buffer over `NSPasteboard.general`, so pasting content copied
  from another app is silently overridden by a stale internal value whenever
  one exists. Filed under WP-V2 (already an approved work package in the
  plan; this audit supplies the confirming evidence).
- `CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift:126-143`:
  `read(from:ofType:)` returns silently (no thrown error, no content set) when
  the file's encoding does not match `utf8`/`utf16BE`/`utf16LE`. This opens a
  blank, unlabeled window with no error indication for any Latin-1,
  Windows-1252, or other non-matching file. Filed under WP-V3 (already an
  approved work package; this audit supplies the confirming evidence).
- `CodeEdit/Features/Editor/Views/PlainEditorSyntaxStyler.swift` (whole file)
  is dead code: it is never constructed or referenced outside its own
  declaration. Filed under WP-V7 as a deletion target alongside the test
  retarget.
- `docs/SMOKE_TEST.md:30,35` documents screenshot capture as "optional" and
  non-fatal; this contradicts the actual script behavior (see finding 2
  above). This file is not in this audit's edit scope (only
  `MILESTONE1_CHECKLIST.md`, `MILESTONE2_CHECKLIST.md`,
  `APP_INTENTS_SMOKE_TEST_GOAL.md`, and this report are); flagging here so
  WP-V4 picks up the doc fix alongside the script fix.

## Corrections applied to the checklists

`MILESTONE1_CHECKLIST.md`:
- Line 42 (Paste works): annotated with the WP-V2 clipboard-buffer finding.
- Line 172 (Kate XML highlighter test count in the validation snapshot):
  annotated with the WP-V7 wrong-engine finding.

`MILESTONE2_CHECKLIST.md`:
- Lines 107, 163, 188, 196, 198, 200, 202, 209, 243, 702 (all dark-mode
  "resolved" claims): annotated with the WP-G2 no-capture-exists finding.
- Line 278 (theme-aware syntax colors): annotated with the WP-F2
  hardcoded-theme finding.
- Lines 339-340 (non-UTF encoding handling): annotated with the WP-V3
  silent-blank-open finding.
- Line 657 (Find menu commands "available"): annotated with the WP-F1
  dead-selector finding.
- Line 727 (Kate XML highlighter test count in the validation snapshot):
  annotated with the WP-V7 wrong-engine finding.

No checkboxes were unchecked outright; each is annotated in place with a
`Corrected 2026-07-09:` note giving the true state and the owning work
package, per the plan's acceptance criteria, since the underlying command
results genuinely pass and only the interpretation attached to them was
wrong.

## Scope note

This audit is evidence and correction only. No product Swift or Python source
was modified. The four confirmed WP-V2/WP-V3/WP-V4/WP-V7 issues, the WP-F1
dead Find selector, the WP-F2 hardcoded-theme gap, and the WP-G2 dark-mode
evidence gap all remain open until their owning work packages land a fix and
re-run these same verification commands.
