## 2026-07-07

### Fixes and Maintenance

- Explicitly show and order the default document window when the plain-editor file document creates it, restoring visible launch for the smoke path.
- Extended `scripts/plain_editor_smoke.sh` with an optional `~/nsh/easy-screenshot/run.sh --application CodeEdit --preview` confirmation so smoke validation proves a window is actually visible.
- Split the plain-editor work into foundation and product-UI milestones so the remaining behavior gaps stay explicit.
- Added a shared plain-editor action router scaffold and routed the plain-editor commands through the same document action methods used by the app shell.
- Added a `New` command to the plain-editor command group and kept `Clean Text` disabled as a placeholder until the real text-cleaning action exists.
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
