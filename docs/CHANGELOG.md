## 2026-07-09

### Additions and New Features

- Added the WP-V1 independent verification audit report at `docs/active_plans/audits/milestone_claims_verification.md`, covering 40 milestone claims with 26 confirmed and 14 corrected against evidence.
- Added live-engine tests for `#pop!ctx` stack transitions and step-budget truncation in `Packages/CodeEditSyntaxDefinitions/Tests/`.
- Added `PlainEditorClipboardTests` with three tests, including an external-pasteboard regression guard.
- Added four encoding lifecycle tests covering Latin-1, Windows-1252, short-high-byte fallback, and undecodable-input failure.
- Added two cleaner edge-case tests covering lone CR line endings and a final line without a trailing newline.
- Added a validation-only `--kill-after=N` CLI flag to the app.
- Made the smoke script print `SMOKE_EXIT=<code>` to stderr on every exit.
- Added a 32-way concurrent `highlightSpans` regression test proving `SyntaxDefinitionRepository`'s lock-guarded lazy loading returns identical spans under concurrency.
- WP-Q3: the app logs `LAUNCH_TO_WINDOW_MS=<n>` (measured from the start of `main()` to the first document window ordered front); new `tests/e2e/e2e_launch_time.py` launches the built app five times with `--kill-after=3`, parses the marker, reports min/median/max, and fails when the median exceeds the 1000 ms budget; baseline recorded at `test-results/perf/launch_time.txt` (median 173 ms on MacBookPro18,3); the smoke script gates on the marker line.
- WP-Q4: new `tests/e2e/e2e_screenshot_colors.py` crops a 10% border from the smoke screenshot, quantizes colors, separates grayscale from chromatic buckets, bins chromatic buckets into 30-degree hue families, and fails below 3 hue families; the smoke script runs it as a hard gate on the screenshot-captured branch (current capture: 4 hue families, the dominant three being green, blue, and orange).
- Added `scripts/make_app_icon.py`, which generates the app icon programmatically with Pillow: a lightning bolt between angle-bracket chevrons, flat two-tone (charcoal navy tile, electric yellow glyphs), rendering all macOS iconset sizes and assembling `Resources/SwiftlyCodeEdit.icns` with Pillow's native ICNS writer (no `iconutil` dependency); a 512px preview is saved at `docs/screenshots/app_icon_preview.png`, and the image-evaluator assessment (verdict SHIP after an inset/chevron rework) is recorded at `docs/active_plans/reports/app_icon_assessment.md`.
- Added `scripts/make_app_bundle.sh`, which assembles `build/SwiftlyCodeEdit.app` from the SwiftPM binary (release by default, `debug` argument accepted), writing Info.plist (CFBundleName/DisplayName SwiftlyCodeEdit, identifier org.vosslab.SwiftlyCodeEdit, icon wired, version read from `VERSION`) and validating it with `plutil -lint`; documented in `docs/DEVELOPER_USAGE.md`.
- WP-Q1: split the Kate syntax pipeline into separately callable display-free public stages on `CodeEditSyntaxDefinitions` (`parseDefinition` -> `definition(forLanguage:)` -> `tokenRuns` -> spans producing `[HighlightSpan]` with an additive `nsRange` field); the headless benchmark now prints `HIGHLIGHT_BENCH` plus per-stage `HIGHLIGHT_BENCH_STAGES` (parseMs=6 interpretMs=54 spanMapMs=2), recorded in `test-results/perf/highlight_cold_pass.txt`.
- Added WP-F0's shared `CodeEdit/Features/Support/UserDataDirectories.swift` helper defining the Application Support path policy (themes/syntax subdirectories, test-override root), with `UserDataDirectoriesTests` covering 7 tests.
- Added `docs/THEME_FORMAT.md` (WP-F2 Patch A): a versioned YAML theme schema with light/dark variants, token keys drawn from `HighlightToken` plus Kate `styleName` refinements, a fallback chain, and a required background field.
- Added `docs/HUMAN_GUIDANCE.md` recording the SwiftUI-first architecture principle (AppKit only as a last-resort escape hatch behind a replaceable adapter) and working-style guidance; linked from `AGENTS.md`; `docs/CODE_ARCHITECTURE.md` gained an "Architecture boundary" section.
- Reworked `scripts/make_app_icon.py` to write the ICNS purely with Pillow (no `iconutil`); final geometry reworked to a 10% inset with the chevron angle restored, with preview evidence saved under `docs/screenshots/`.

### Behavior or Interface Changes

- Changed paste to always read `NSPasteboard.general` directly; removed the private `copiedText` buffer so pasting external-app content is no longer overridden by a stale internal value.
- Changed non-UTF file opening to decode via Windows-1252 or Latin-1 fallback, or present a real error alert, instead of silently opening a blank document.
- Changed the status bar to report "Unknown" instead of falsely claiming "UTF-8" when no decoding was actually applied.
- Reclassified smoke screenshot capture as an optional diagnostic step with explicit `SKIPPED: <reason>` lines and a `--no-screenshot` flag.
- Changed `build_debug.sh` and the smoke script to launch the app with `--kill-after` so validation runs never leave stray instances in the Dock.
- Removed the font-family dropdown from the editor command ribbon; the persisted `PlainEditor.fontFamily` setting and the font size controls remain.
- Renamed the product to SwiftlyCodeEdit: the executable product name in Package.swift, the app menu title and Quit item, and launch/kill tooling (`build_debug.sh`, `build_release.sh`, the smoke script, `tests/e2e/e2e_launch_time.py`); the target name and `CodeEdit/` source directory are deliberately kept as-is to avoid cascading `@testable import` breakage, with the directory rename owed to the purge work package.

### Fixes and Maintenance

- Fixed app-icon over-padding in `scripts/make_app_icon.py`: bracket vertices and arm tips (including rounded stroke caps) and the bolt tips now land exactly on the 10% content-inset lines, so the glyph spans ~80% of tile width/height instead of ~62%; bolt keeps its 0.34/0.62 width-to-height ratio and clears the right bracket by ~175 px at master size.
- Fixed a double `finishPlainEditorLaunch()` invocation on launch.
- Fixed a CRLF grapheme-cluster bug in `PlainEditorTextCleaner` where CRLF-terminated lines were never trimmed because Swift merges `\r\n` into a single `Character`.
- Deleted the destructive `PlainTextCleaner`, which mapped codepoints above U+00FF to `?`.
- Deleted the dead `PlainEditorSyntaxStyler` and its wrong-engine `KateXMLSyntaxHighlighter` test suite.
- Retargeted cleaner tests to the live `PlainEditorTextCleaner` and renamed the test file to match.
- Fixed the `.gitignore` bare `PackageSmoke` pattern that had kept the entire `CodeEditTests/PackageSmoke` suite untracked.
- Moved the first syntax highlight off the main thread: span computation now runs in a detached background task with attribute application back on the main actor, using generation-based coalescing and stale-result guards, so the document window appears immediately instead of beachballing roughly 3-6 seconds behind a synchronous cold highlight during window construction.
- WP-Q0b: fixed intermittent syntax highlighting by replacing the highlighter's global generation counter and span cache with per-document state keyed per `NSTextStorage` in a weak-key `NSMapTable`, so one window's request can no longer strand another window's in-flight compute; external-change reloads now schedule a highlight after `setString` (they bypass the text-change notification); a computed result that finds the text drifted with no newer request recomputes and applies instead of leaving the document unhighlighted; covered by a new two-document concurrency test (suite now 28 tests in 6 suites).
- Fixed a release-configuration build failure: `CodeFileView.swift` called the DEBUG-only `PlainEditorCommandSelfTest` outside any `#if DEBUG` guard, compiling in debug but breaking `swift build -c release`; the call site is now guarded.
- Removed a pasted Formula 1 standings table accidentally saved into `CodeFileDocument.swift`: a live editor session had the real source file open during manual paste testing, and the 2-second autosave wrote it to disk (also stripping the trailing newline); the appended text broke the release build and leaked into the smoke screenshot.
- Declared `numpy` in a new root `pip_requirements.txt` (alongside `pillow`) for `tests/e2e/e2e_screenshot_colors.py`; added inline bandit B108 waivers in `tests/e2e/e2e_launch_time.py` for the fixed `/tmp/codeedit_runtime.log` path contract written by `DebugRuntimeLog.swift`.
- Clarified `tests/e2e/e2e_screenshot_colors.py` output: it now prints `chromatic_buckets_total` and `chromatic_buckets_printed` separately so a single dominant printed bucket can no longer look contradictory next to the hue-family count.
- WP-Q1: fixed the cold-highlight regression, 6293 ms down to 67 ms on the ~1400-line smoke fixture; the root cause was an O(n^2) step-budget guard recomputing `text.count` per interpreter step, not regex compilation. Added a `FirstCharFilter` ASCII-bitmap prefilter (skips roughly 83% of regex attempts, with a conservative analyzer bailing to always-run), a UTF-16 `NSString` backing with lockstep offset tracking, and a process-wide `CompiledRegexCache` (warm reopen 0 ms).
- WP-Q1 review fixes: POSIX bracket expressions (`[[:cntrl:]]` and similar) are no longer misparsed by the filter analyzer, which now bails to always-run (a regression test is proven to fail without the fix); the match-jump path now advances the grapheme cursor and UTF-16 offset from one walk, eliminating a mid-cluster desync risk (covered by a unicode fixture test spanning emoji, CJK, and combining marks).
- Fixed silent corruption of BOM-less UTF-16 files on open: `CodeFileDocument.decode` gained a plausibility pre-check (4KiB pair sampling) so interleaved-NUL UTF-16 is no longer misread as UTF-8; the lifecycle test matrix was extended to 10 tests, including bomless UTF-16 cases.
- Fixed a stale `CodeEdit.xcodeproj` reference in the README.

### Decisions and Failures

- Corrected milestone checklist claims in place with `Corrected 2026-07-09:` annotations, covering the dead Find menu, dark mode never captured, overstated theme-awareness, wrong-engine test coverage, and a silent-blank encoding case mislabeled as a handled limitation.
- Noted that the entire package-smoke test suite had never been in git history due to the `.gitignore` pattern.
- Accepted WP-V3 decode-fallback breadth and recorded it in the plan: the Windows-1252 fallback rejects only 5 byte values, with BOM-less UTF-16 coverage owed in WP-S3.
- Accepted WP-V4 quality nits as polish debt: `SMOKE_EXIT` is not printed on pre-launch usage errors, and a malformed `--kill-after` value silently disables the backstop.
- Investigated a spec-review must-fix alleging an unsynchronized data race in `SyntaxDefinitionRepository` and found it already closed in HEAD: an `NSLock` guards all mutable state. Kept the internal lock instead of converting to an actor, because an actor would force async through the highlight API for no correctness gain.
- WP-Q4 first metric counted 15 "significant colors" that were mostly grayscale antialiasing ramps; reworked to a hue-family metric so the gate proves chromatic syntax coloring, not gray shades.
- WP-Q0b quality review accepted two polish items into WP-Q1: an iteration cap on the drift-recompute loop, and a comment on the compute task's intentional bounded strong capture of the storage.
- Resolved the `Packages/CodeEditHighlighting` open question as KEEP: the WP-P1 scout confirmed live dependence (`HighlightSpan` used by `PlainSyntaxHighlighter.swift` and `CodeFileView.swift`) via a nested dependency in `Packages/CodeEditSyntaxDefinitions/Package.swift`.
- WP-P3 spec review flagged "CodeEdit" strings in Feedback/WindowCommands/Settings/SourceControl trees as MUSTFIX; overruled with evidence, since all live in Package.swift-excluded, never-compiled trees already on the WP-P1 deletion list; the compiled-files-only audit scope stands.
- WP-S0b spike verdict FAIL: SwiftUI `TextEditor`+`AttributedString` cannot meet editor gates (caret collapses to EOF on any programmatic attribute write; keystroke p95 140.56 ms against a 16 ms gate; a 1 MB document wedges the main thread). The TextKit bridge stays as the replaceable AppKit adapter under the SwiftUI-first principle, to be re-evaluated against the next macOS SDK. Decision record: `docs/active_plans/decisions/text_engine_decision.md`.
- Deferred large-file (~1 MB+) cold-highlight performance (WP-Q1): these files remain multi-second cold until viewport-first highlighting lands, deferred to a future large-file work package.

### Developer Tests and Notes

- Ran a read-only document lifecycle audit ahead of milestone MS and found 4 HIGH findings (undo never clears the dirty flag; a dirty document's external change is silently dropped, a lost-update; reload swallows decode errors via `try?`; reload does not reset the undo stack), 2 MEDIUM, and 2 LOW findings; also confirmed `UndoManagerRegistration.swift` is dead code. Report: `docs/active_plans/audits/document_lifecycle_audit.md`.

## 2026-07-07

### Fixes and Maintenance

- Fixed the merged syntax-definition package layout so SwiftPM processes only XML files from the active Kate vendor resource tree and the live highlighter loads Swift XML from that same bundle path.
- Restored visible syntax highlighting by keeping the XML-based Kate colors applied through the final smoke view state, and restored the historical filename-based screenshot capture command.
- Changed fresh plain-editor document windows to a 960 x 600 landscape default and made the command self-test restore the original selection instead of leaving Select All highlighted in screenshots.
- Made the distribution-clean debug build path recreate SwiftPM's artifact directory, silence false-positive clean-script `find` output, and route `CodeEditTextView` viewport notifications through main AppKit selectors.
- Replaced the direct SwiftPM launch entry with an AppKit application main for the plain-editor path so the smoke harness can exercise the same file-backed document window lifecycle without relying on a SwiftUI settings-only scene.
- Restored the full package-smoke test target source set so SwiftPM includes every `CodeEditTests/PackageSmoke` test file instead of warning about unhandled tests.
- Added a context-preserving Kate XML Swift syntax highlighter and wired it into the live plain-editor path so Swift files receive semantic color spans in `NSTextStorage`.
- Added smoke-log validation requiring Swift comment, keyword, number, string, and type highlighting with multiple distinct readable colors in the active editor.
- Added focused Swift Testing package tests proving Kate context handling keeps keywords inside comments and strings from being flattened into global keyword matches, empty input is safe, language mismatch falls back to plain text, and re-highlighting reflects changed text.
- Added a focused Kate XML regression test for block-comment context popping so numbers, keywords, and types inside block comments stay comments while normal Swift rules resume after `*/`.
- Added a latest validation snapshot to the Milestone 2 checklist covering Swift tests, Python tests, build, live smoke, scope cleanliness, syntax tokens, command self-test, and screenshot TCC disposition.
- Added a latest validation snapshot to the Milestone 1 checklist covering Swift tests, Python tests, build, live smoke, scope cleanliness, editor readiness, command self-test, and screenshot TCC disposition.
- Corrected the Milestone 2 App Intents checklist section to list only implemented intents and document status/Clean Text smoke coverage through the actual package and live-editor paths.
- Added a debug-only plain-editor command self-test to the smoke path that exercises insert, Undo, Redo, Select All, Copy, Cut, and Paste against a temporary Swift source file.
- Routed plain-editor menu and command-bar editing commands through the shared active-editor action router so Undo, Redo, Cut, Copy, Paste, and Select All operate on the live `TextView`.
- Implemented the first Clean Text action as deterministic per-line trailing space/tab trimming through the active editor, with smoke coverage for Clean Text, undo, redo, save, and reopen persistence.
- Added narrow App Intents smoke-test hooks plus package validation for opening a known file, reporting state, applying a synthetic edit, saving, reopening, and verifying persistence without display access.
- Added package smoke coverage for Markdown, JSON, YAML, plain-text, and unknown-extension syntax mode detection, with unknown files falling back to plain text.
- Added shared plain-editor status reporting tests for CRLF, CR, LF, UTF-8, UTF-16 LE, soft tabs, tabs, and unknown indentation fallback.
- Saved plain-editor smoke logs under `test-results/plain_editor_smoke/` and asserted UTF-8/LF status reporting in the live smoke path.
- Documented the current non-UTF status-reporting limitation for ambiguous BOM-less files instead of treating encoding detection as complete for every byte pattern.
- Documented Milestone 2's active Find/Replace deferral, Liquid Glass/system-material usage, smoke output location, and status-reporting validation coverage.
- Ignored generated `test-results/` smoke artifacts while keeping the smoke output path documented.
- Removed the remaining terminal-emulator model files from the active SwiftPM executable source list.
- Removed the unused shell client from the active SwiftPM executable path so workspace-shell behavior stays out of scope.
- Pruned unused legacy LSP, extension, database, async, and log package dependencies from the active SwiftPM executable manifest.
- Removed the unused root `SnapshotTesting` dependency from the active package-smoke test target.
- Excluded the unused `World` and timeout helper from the active SwiftPM executable path after shell/LSP cleanup.
- Marked the App Intents smoke-test goal complete with evidence from the package smoke runner and live plain-editor smoke gate, replacing remaining future-oriented smoke-goal wording.
- Tightened the final Milestone 2 checklist evidence for Clean Text now that the command is implemented and smoke-validated.
- Restored the SwiftPM package-smoke lifecycle test file referenced by the root package manifest and added a target-local `CodeEditLanguages` resource placeholder so required builds no longer fail on missing declared inputs.
- Switched the deterministic debug/smoke source file to `CodeFileDocument.swift` so live validation contains comments, keywords, strings, numbers, types, identifiers, and normal text.
- Kept optional screenshot confirmation non-fatal in the plain-editor smoke script when macOS screen-capture permission is unavailable.
- Narrowed the root SwiftPM test target to `CodeEditTests/PackageSmoke` so legacy test files outside the active package-smoke path no longer produce unhandled-file warnings.
- Fixed `docs/FILE_STRUCTURE.md` local links so Markdown link hygiene passes for same-folder docs and generated directories.
- Replaced remaining repo-wide non-ISO decorative glyphs and test fixture names with ASCII-safe equivalents so the Python hygiene suite can run cleanly.
- Explicitly show and order the default document window when the plain-editor file document creates it, restoring visible launch for the smoke path.
- Extended `scripts/plain_editor_smoke.sh` with an optional `~/nsh/easy-screenshot/run.sh --application CodeEdit --preview` confirmation so smoke validation proves a window is actually visible.
- Split the plain-editor work into foundation and product-UI milestones so the remaining behavior gaps stay explicit.
- Added a shared plain-editor action router scaffold and routed the plain-editor commands through the same document action methods used by the app shell.
- Added a `New` command to the plain-editor command group and later replaced the `Clean Text` placeholder with the implemented trailing-whitespace cleanup action.
- Added a visible top command ribbon and bottom status bar scaffold to the plain-editor file view so the app has the intended product shell shape.
- Added provisional status values for cursor position, word count, character count, indentation, encoding, line ending, and syntax mode.
- Added runtime log evidence for the plain-editor command ribbon and status bar so smoke validation can assert the visible shell exists.
- Extended `scripts/plain_editor_smoke.sh` to check the new ribbon and status-bar runtime markers.

## 2026-07-06

### Fixes and Maintenance

- Removed the terminal utility UI test from the active UI-test tree because the milestone excludes terminal behavior.
- Removed the terminal-emulator source tree, the SwiftTerm utility extension, and the Xcode package references so the active repo surface matches the plain-editor scope.
- Added a SwiftPM debug-lane direct-open path that initializes `CodeFileDocument` from a known source URL instead of depending on `NSDocumentController` document registration.
- Logged the live bundle metadata, Swift UTType mapping, and document-controller class list so the plain-editor smoke path can prove the runtime document-type state.
- Made the plain-editor smoke harness start from a clean `CodeEdit` process so it validates a single deterministic launch lane.
- Added a SwiftPM package smoke test target for the `CodeFileDocument` lifecycle path so save/reopen verification runs on the Swift build path.
- Logged the live menu bar during debug launch so the plain-editor smoke run can verify command registration from runtime evidence.
- Captured a live CodeEdit screenshot at `test-results/gui_smoke/editor_window.png` after verifying the app window stayed open long enough for helper-based capture.
- Fixed the plain-editor launch crash by moving `presentedItemDidChange()` back onto the main actor instead of forcing isolated access from the file-presenter queue.
- Moved the plain editor viewport observer back into `CodeEditTextView` and exposed the helper for the app shell.
- Fixed the remaining Swift 6 concurrency blockers in the plain editor viewport observer and shared static helpers.
- Replaced the app entry's welcome-window launcher with a minimal plain-editor scene stub.
- Added a plain-editor launch smoke-run that boots the built executable directly and leaves the app running instead of exiting immediately.
- Added deterministic runtime logs, a plain-editor smoke harness, and a smoke checklist for the file-backed editor path.
- Added a focused CodeFileDocument lifecycle test covering load, synthetic edit, save, and reopen persistence.
- Declared the plain-editor runtime resources explicitly and excluded shell-integration/preview artifacts from the required build path.
- Trimmed the executable manifest to drop the welcome-window package from the app target.
- Added `docs/RELATED_PROJECTS.md` from local repo evidence and bounded sibling-project discovery.
- Replaced the upstream README with a shorter fork-focused front page.
- Linked the README to the docs that already exist in this repository.
- Wired the plain text editor to report text edits directly so the document can mark changes without the removed content-coordinator bridge.
- Trimmed `CodeFileDocument` to use only plain file-path state for file-change detection in this lane.
- Removed the stale `CodeFileView` dependency on the removed content-coordinator subscription.
- Added a root `build.sh` wrapper for `xcodebuild` on the `CodeEdit` scheme.
- Split the build helper into `build_debug.sh` and `build_release.sh` to match the app workflow.
- Added an early Xcode simulator-component check so build scripts fail with a clearer message when Xcode is incomplete.
- Vendored the CodeEdit-owned Swift packages into `Packages/` and rewired the project to use local package paths.
- Replaced the runtime `ZIPFoundation` dependency with a local unzip helper backed by the system `unzip` tool.
- Added a new `CodeEditHighlighting` package skeleton to define the app-facing syntax highlight span model and protocol.
- Wired `CodeEditSourceEditor` to depend on the new shared highlighting package boundary.
- Added a resource-only `CodeEditSyntaxDefinitions` package skeleton for declarative syntax definition files.
- Made the debug and release build scripts interruptible by trapping `INT` and `TERM`.
- Added a syntax-rule-set comparison note to keep the format decision explicit.
- Added a removal plan so cleanup can proceed in a bounded order.
- Added a data-first directory layout for the syntax-definition bundle.
- Added an audit note to bound the remaining cleanup surface.
- Made the keybindings modifier-key environment default immutable so the plain-editor lane stays Swift 6 concurrency-safe.
- Switched `LocalizedStringKey.helloWorld` to a computed value so the localization helper stays Swift 6 concurrency-safe.
- Removed the default parser-backed provider from the editor entry points.
- Reduced `CodeEditLanguages` to metadata-only source files in the package target.
- Removed parser references from the source editor package docs and comments.
- Removed Sparkle and SwiftLintPlugin from the required build graph and stubbed the updater entry point.
- Switched the debug and release helper scripts from Xcode build invocation to SwiftPM build invocation.
- Continued the SwiftPM-first, source-first refactor toward a smaller editor/highlighting boundary.
- Added `docs/CODE_ARCHITECTURE.md` and `docs/FILE_STRUCTURE.md` to explain the plain-editor cutover and repo layout.
- Removed `SwiftTerm` from the executable dependency graph because the milestone scope excludes a built-in terminal.
- Continued cutting the executable target away from the legacy workspace shell so the app can boot through the plain editor path.
