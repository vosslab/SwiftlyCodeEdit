## 2026-07-06

### Fixes and Maintenance

- Moved the plain editor viewport observer back into `CodeEditTextView` and exposed the helper for the app shell.
- Fixed the remaining Swift 6 concurrency blockers in the plain editor viewport observer and shared static helpers.
- Replaced the app entry's welcome-window launcher with a minimal plain-editor scene stub.
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
