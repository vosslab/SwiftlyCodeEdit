# MS entry-criteria scout: modularity work packages

Read-only scout for the three modularity entry criteria added to milestone MS (SwiftUI shell migration) in docs/active_plans/active/scope_closure_plan.md (Milestone: MS SwiftUI architecture, line 152). Evidence gathered 2026-07-09 against the live (compiled) source and test tree only; the excluded legacy trees under CodeEdit/ and the non-dependency packages (CodeEditKit, CodeEditSourceEditor, WelcomeWindow) are out of scope because Package.swift never compiles or tests them (confirmed via Package.swift:37-97 exclude list and :103-108 the only real testTarget).

## Criterion 1: self-test hooks out of product views

### 1a. PlainEditorCommandSelfTest inside CodeFileView.swift
- CodeEdit/Features/Editor/Views/CodeFileView.swift:151-239: a private #if DEBUG-guarded enum (PlainEditorCommandSelfTest) lives in the same file as the product view CodeFileView. It drives a full undo/redo/select-all/copy/cut/paste/clean-text/restore sequence directly against the live TextView and NSPasteboard.general, gated by env var CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST.
- Call site: CodeFileView.swift:76-84, inside the view's onTextViewReady closure, already #if DEBUG guarded (lines 81-83). This is the exact call site the changelog (2026-07-09 Fixes and Maintenance) says previously broke the release build before the guard was added -- guard is present, but the code is still physically inside the view file.
- Natural extraction target: move PlainEditorCommandSelfTest into CodeEdit/Features/SmokeTesting/, next to PlainEditorSmokeIntents.swift (see 1c). View keeps only the one-line #if DEBUG call, mirroring how PlainEditorAppDelegate already delegates to logRuntimeBundleState()/logMenuState() (criterion 2) instead of inlining them.

### 1b. debugRuntimeLog calls scattered through product views
debugRuntimeLog (CodeEdit/Utils/DebugRuntimeLog.swift:1-25, already a standalone utility, not inside a view) is called directly from product view bodies and model types, not just dedicated smoke code:
- CodeFileView.swift:106-108 (.onAppear), :113/:116 (.onChange handlers), :122 (logFontSettings()), :217-219 and :267-269 (self-test summary + status refresh).
- CodeEdit/Features/Editor/Views/PlainSyntaxHighlighter.swift:109,152,165,170,216,249 (highlighter diagnostics).
- CodeEdit/Features/Editor/Views/PlainTextEditorView.swift:117,156 (view lifecycle).
- CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift:114,153,173 (document lifecycle).
- CodeEdit/Features/Support/UserDataDirectories.swift:76,97 (support helper, already outside a view).
- CodeEdit/CodeEditApp.swift: 11 call sites (see criterion 2), all inside app-shell/menu code, not a view body.
All are #if DEBUG guarded at the call site or inside debugRuntimeLog itself; none unguarded in release. PlainSyntaxHighlighter.swift/PlainTextEditorView.swift sites are diagnostic tracing, lower priority than 1a/1c, noted for a later single-logging-seam cleanup but not blocking for MS entry.

### 1c. PlainEditorSmokeIntents.swift -- already the right shape
CodeEdit/Features/SmokeTesting/PlainEditorSmokeIntents.swift (151 lines) is already isolated in its own Features/SmokeTesting/ module: PlainEditorSmokeIntentRunner enum plus 5 AppIntent structs (OpenKnownFileIntent, ReportEditorStateIntent, ApplySyntheticEditIntent, SaveCurrentDocumentIntent, ReopenAndVerifyIntent). Touches CodeFileDocument only via public API, holds its own private static state (lines 7-9), not #if DEBUG guarded (App Intents ship in release by design). This is the extraction-target pattern to copy for 1a.

### Work package sketch: WP-modularity-1 self-test extraction
- Touch points: CodeFileView.swift (delete lines 151-239, replace call site at line 82), new CodeEdit/Features/SmokeTesting/PlainEditorCommandSelfTest.swift.
- Acceptance criteria: CodeFileView.swift contains no type/enum beyond CodeFileView, PlainEditorFontSettings, PlainEditorChromeModel, PlainEditorCommandBar, PlainEditorStatusBar; self-test enum lives under Features/SmokeTesting/ with the same #if DEBUG guard and call contract (scheduleIfRequested(textView:)).
- Verification commands: swift build / swift build -c release / ./scripts/plain_editor_smoke.sh
- Dependency note: parallel with WP-S1 (pure file-move); do first if wall-clock allows.

## Criterion 2: CodeEditApp.swift split

CodeEdit/CodeEditApp.swift is 557 lines, 5 sections:
| Section | Lines | Contents |
| --- | --- | --- |
| Launch entry | 6-52 | CodeEditMain enum: @main, main(), --kill-after parsing, logLaunchToWindowIfNeeded() |
| App delegate/lifecycle | 54-277 | PlainEditorAppDelegate: launch finish, default-file open, debug bundle/menu logging (123-146, 262-276), all @objc menu-item forwarding (171-260) |
| Action routing | 279-352 | PlainEditorActionRouter: ObservableObject singleton (shared) both the AppKit menu and SwiftUI CodeFileView command bar call for undo/redo/cut/copy/paste/selectAll/cleanText |
| AppKit main menu | 354-438 | PlainEditorMainMenu: builds the literal NSMenu tree (app/File/Edit/Find) installed at CodeEditMain.main() line 21 |
| Dead SwiftUI Commands scaffold | 440-545 | PlainEditorCommands: Commands -- a complete SwiftUI Commands builder (New/Open/Save/Undo-Redo/Cut-Copy-Paste/Find/Clean Text) never referenced anywhere (grep -rn "PlainEditorCommands\b" returns only its own definition); no SwiftUI App struct exists for it to attach to |
| Extension | 547-557 | TextView.cleanText(_:) @objc shim, used by the AppKit menu action path |

Cross-references:
- CodeEditMain.main() needs PlainEditorAppDelegate (line 13) and PlainEditorMainMenu.make(appDelegate:) (menu).
- PlainEditorAppDelegate needs PlainEditorActionRouter.shared (line 56) for every menu-item method (206-260).
- PlainEditorMainMenu.make needs PlainEditorAppDelegate only as an AnyObject target/selector source (376-437) -- selector-name coupling only, not internals.
- PlainEditorCommands (dead) needs PlainEditorAppDelegate the same way (440-543).
- PlainEditorMainMenu is a pure leaf otherwise; PlainEditorActionRouter is a pure leaf (only depends on CodeEditTextView.TextView).

### Proposed 3-4 file split (matches existing Features/<Area>/ convention)
1. CodeEdit/CodeEditApp.swift (kept, ~55 lines): just CodeEditMain (6-52).
2. CodeEdit/Features/AppShell/PlainEditorAppDelegate.swift (new, ~225 lines): PlainEditorAppDelegate (54-277) + TextView.cleanText(_:) extension (547-557), since the extension only backs the delegate's cleanTextMenuItem action.
3. CodeEdit/Features/AppShell/PlainEditorActionRouter.swift (new, ~75 lines): PlainEditorActionRouter (279-352) alone -- the seam most likely to survive the SwiftUI migration unchanged, so isolating now means WP-S1 touches one small file.
4. CodeEdit/Features/AppShell/PlainEditorMainMenu.swift (new, ~85 lines): PlainEditorMainMenu (354-438) alone -- exactly the AppKit-only piece WP-S1 is scoped to replace, so its eventual deletion becomes a single-file diff.

Dependency direction after split: CodeEditApp.swift (launch) depends on PlainEditorAppDelegate and PlainEditorMainMenu; PlainEditorAppDelegate depends on PlainEditorActionRouter; PlainEditorMainMenu depends on PlainEditorAppDelegate only via @objc selector name. PlainEditorActionRouter and PlainEditorMainMenu have no mutual dependency -- no cycles.

### Flag: dead PlainEditorCommands fights the SwiftUI-first boundary
PlainEditorCommands (440-545) is dead code today but a complete, already-written SwiftUI Commands builder duplicating every menu item PlainEditorMainMenu provides via AppKit NSMenu. Per docs/HUMAN_GUIDANCE.md (SwiftUI-first architecture principle), once MS lands, hand-built NSMenu outside the isolated adapter is a defect, and PlainEditorMainMenu exists only because the app currently launches through NSApplication/NSMenu rather than a SwiftUI App + DocumentGroup. Two options:
- Delete PlainEditorCommands now as part of this work package (recommended) -- it is unused, and the plan's MS exit criteria already call for deleting superseded AppKit shell code as an obvious follow-on.
- Or move it into its own PlainEditorCommands.swift now if WP-S1 confirms this exact shape (same items, same shortcuts) is what it wants to keep for its .commands { } wiring.
Either way, do not leave it sitting inside the same file as the AppKit PlainEditorMainMenu it is meant to replace.

### Work package sketch: WP-modularity-2 CodeEditApp.swift split
- Touch points: CodeEditApp.swift (shrink to launch only), new PlainEditorAppDelegate.swift, PlainEditorActionRouter.swift, PlainEditorMainMenu.swift under Features/AppShell/; decide/execute PlainEditorCommands deletion or relocation.
- Acceptance criteria: CodeEditApp.swift contains only CodeEditMain; 4 extracted types compile/link per the dependency direction above (no new cycles); swift build -c release still succeeds (this file already caused one release-only break per changelog); smoke script green; dead PlainEditorCommands gone or explicitly relocated with a decision recorded in docs/CHANGELOG.md.
- Verification commands: swift build / swift build -c release / grep -rn "PlainEditorCommands" CodeEdit / ./scripts/plain_editor_smoke.sh
- Dependency note: before WP-S1 -- doing the split first means WP-S1 edits/deletes 2 small files instead of surgically extracting them from a 557-line file under time pressure.

## Criterion 3: sandboxed test fixtures

Scope: CodeEditTests/PackageSmoke/ (the only live test target, Package.swift:103-108) plus the 3 packages the root Package.swift actually depends on (CodeEditLanguages, CodeEditSyntaxDefinitions, CodeEditTextView).

### Already sandboxed (good pattern, no changes needed)
- CodeEditTests/PackageSmoke/CodeFileDocumentLifecycleTests.swift:7-13: private withTempDir helper creates a UUID-named directory under FileManager.default.temporaryDirectory, removes it in a defer; all 10 tests use it exclusively.
- CodeEditTests/PackageSmoke/UserDataDirectoriesTests.swift:99-101: makeTempRoot() returns a fresh UUID-named temp directory; every test passes it as overrideRoot: so none of the 6 tests touch the real Application Support path -- already the norm in this file, matching the pattern named in the dispatch brief.
- PlainEditorFontSettingsTests.swift and PlainEditorTextCleanerTests.swift: pure functions over local values, no filesystem/global-singleton touch at all.

### Needs conversion: process-wide singleton state, not sandboxed
- CodeEditTests/PackageSmoke/PlainEditorClipboardTests.swift:14-16: marked @Suite(.serialized), which shows the author already recognized a shared-state hazard, but the state itself is still 2 process-wide singletons: NSPasteboard.general (read/set directly at lines 31, 36, 55-56) and PlainEditorActionRouter.shared (registered via makeRegisteredTextView, line 19). .serialized only prevents the 3 tests in this one file from racing each other; it does not stop interference with a real user's clipboard if ever run interactively, or with any other test file touching the same singleton (Swift Testing .serialized is per-suite, not global).
- Packages/CodeEditTextView/Tests/CodeEditTextViewTests/KillRingTests.swift:6: `var ring = KillRing.shared` -- KillRing is a class (Packages/CodeEditTextView/Sources/CodeEditTextView/Utils/KillRing.swift:18-19), so this is not a value copy; test_killRingYank mutates the actual process-wide singleton (lines 7-27) before switching to a fresh local instance only partway through (line 18). Any other test touching KillRing.shared in the same process (e.g. via TextView.delete/.yank) can observe leftover state. This is an XCTest-era file (class KillRingTests: XCTestCase, line 4), so it also cannot pick up a .serialized trait the way newer Suite-based files can.
- Packages/CodeEditSyntaxDefinitions/Tests/CodeEditSyntaxDefinitionsTests/SyntaxDefinitionRepositoryConcurrencyTests.swift:6-17 deliberately exercises SyntaxDefinitionRepository.shared's process-wide, lock-guarded caches concurrently, with an explicit comment (lines 8-16) documenting this is intentional. This is a correct use of shared state as the thing under test, not a sandboxing gap -- excluded from the conversion list.

### Work package sketch: WP-modularity-3 sandboxed fixtures
- Touch points: PlainEditorClipboardTests.swift (isolate the pasteboard: swap NSPasteboard.general for a test-only NSPasteboard(name:) instance injected through PlainEditorActionRouter, or save/restore its prior contents the same way PlainEditorCommandSelfTest.run already does at CodeFileView.swift:171/234-237); KillRingTests.swift (stop touching .shared in test_killRingYank; use a fresh KillRing(capacity:) instance for every case, matching what test_killRingYankAndSelect at lines 31-46 already does correctly).
- Acceptance criteria: no test file under CodeEditTests/PackageSmoke/ or the 3 live packages' Tests/ directories reads or mutates NSPasteboard.general or KillRing.shared without an explicit save/restore or full replacement; PlainSyntaxHighlighterTests's and SyntaxDefinitionRepositoryConcurrencyTests's deliberate use of shared singletons stays as-is.
- Verification commands: swift test --filter PlainEditorClipboardTests / swift test --filter KillRingTests / swift test
- Dependency note: parallel with WP-S1 (pure test-fixture hygiene, no product-code coupling).

## Highest-risk coupling
The dead PlainEditorCommands SwiftUI Commands builder sitting in the same file as the live AppKit PlainEditorMainMenu it is meant to replace (CodeEditApp.swift:354-545). Zero references, zero test coverage, zero proof its menu items/shortcuts still match the live AppKit menu -- if WP-S1 reaches for it as a head start under time pressure, it risks shipping unverified menu behavior as the modernized replacement. Deciding delete-vs-relocate now, before WP-S1 starts, removes that trap.
