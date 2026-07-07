# Plain Editor Milestone To-Do Checklist

## Build and Smoke Test

- [x] Run `./build_debug.sh`.
- [x] Fix any build failure in the required plain-editor path.
- [x] Run `./scripts/plain_editor_smoke.sh`.
- [x] Fix any smoke harness failure.
- [x] Confirm both commands pass after each meaningful change.

## Runtime Launch Path

- [x] Confirm the app launches as a regular foreground app.
- [x] Confirm the app does not exit immediately.
- [x] Confirm the app opens a deterministic known source file during debug launch.
- [x] Confirm the opened file path is logged to `/tmp/codeedit_runtime.log`.
- [x] Confirm the loaded character count is logged.
- [x] Confirm editor window creation is logged.
- [x] Confirm editor view creation is logged.
- [x] Confirm first-responder request is logged.
- [x] Confirm editable state is logged.

## File-Backed Editor Path

- [x] Open a real source file through the plain-editor path.
- [x] Confirm source text reaches `CodeFileDocument`.
- [x] Confirm source text reaches `CodeFileView`.
- [x] Confirm source text reaches `PlainTextEditorView`.
- [x] Confirm source text appears in `CodeEditTextView.TextView`.
- [ ] Confirm syntax highlighting is visibly active in the live editor.
- [x] Confirm placeholder text appears only when no file text is loaded.
- [x] Confirm the window title uses the opened file name.

## Editing Behavior

- [x] Confirm the editor accepts keyboard focus.
- [ ] Confirm typing changes the document model.
- [ ] Confirm Undo works.
- [ ] Confirm Redo works.
- [ ] Confirm Cut works.
- [ ] Confirm Copy works.
- [ ] Confirm Paste works.
- [ ] Confirm Select All works.
- [ ] Confirm Find works if it is in the current required path.

## Save Behavior

- [x] Confirm Save writes the current document text to disk.
- [x] Confirm Save As works, or record it as deferred for this smoke pass.
- [x] Confirm edited text survives close and reopen.
  - [x] Add or update an automated file lifecycle check:
    - [x] load known text
    - [x] apply synthetic edit
    - [x] save to a temporary file
    - [x] reopen the temporary file
  - [x] assert the edit persisted

## Menus and Commands

- [x] Confirm basic app menus appear in a normal local GUI session.
- [x] Confirm Open is registered.
- [x] Confirm Save is registered.
- [x] Confirm Save As is registered or intentionally deferred.
- [x] Confirm Close is registered.
- [x] Confirm Undo is registered.
- [x] Confirm Redo is registered.
- [x] Confirm Cut is registered.
- [x] Confirm Copy is registered.
- [x] Confirm Paste is registered.
- [x] Confirm Select All is registered.
- [x] Confirm Find is registered if it is in the current required path.

## Plain Editor Architecture Cleanup

- [x] Keep `CodeEditApp.swift` on the plain editor launch path.
- [x] Keep `CodeFileDocument` limited to file open, save, autosave, and external-change handling.
- [x] Keep `CodeFileView` limited to connecting the document to the editor view.
- [x] Keep `PlainTextEditorView` limited to the editor bridge.
- [x] Keep `CodeEditTextView.TextView` as the current editing surface.
- [x] Remove remaining required-build references to the old workspace shell.
- [x] Remove remaining required-build references to source-control UI.
- [x] Remove remaining required-build references to LSP and semantic-token paths.
- [x] Remove remaining required-build references to terminal support.
- [x] Remove remaining required-build references to minimap and line-folding machinery.
- [x] Remove remaining required-build references to old SourceEditor facade behavior.
- [x] Remove or isolate old utility extensions that only support removed surfaces.

## Swift 6 Cleanup

- [x] Clean up remaining actor-isolation warnings in `CodeFileDocument`.
- [x] Clean up remaining sendability warnings in required-build files.
- [x] Confirm UI state and AppKit/TextKit mutation are main-actor owned.
- [x] Confirm any compatibility annotations are narrow and tied to AppKit/TextKit boundaries.
- [x] Rebuild after each ownership cleanup.

## Resource Warnings

- [x] Audit SwiftPM unhandled-resource warnings.
- [x] Declare required runtime resources explicitly.
- [x] Exclude shell-integration resources from the required path if they are outside scope.
- [x] Exclude preview-only resources from the required path if they are outside scope.
- [x] Confirm `default_keybindings.json` is declared if needed at runtime.
- [x] Confirm `Info.plist` handling is intentional for the current SwiftPM app path.
- [x] Confirm entitlements handling is intentional for the current SwiftPM app path.
- [ ] Reduce resource warnings to zero, or document each remaining warning as intentional.

## Screenshot and GUI Evidence

- [x] Confirm whether the current session has display access.
- [x] Confirm the app is a regular foreground app.
- [x] Confirm the editor window is ordered front and visible in a local GUI session.
- [x] Try `screencapture` when display access exists.
- [x] Try the external screenshot helper when display access exists.
- [x] Save screenshots under `test-results/gui_smoke/` when available.
- [x] Record the exact failure if screenshot capture is unavailable.
- [x] Keep automated validation passing even when screenshot capture is unavailable.

## Automated Validation

- [x] Keep `scripts/plain_editor_smoke.sh` deterministic.
- [x] Verify launch markers in the smoke harness.
- [x] Verify file load in the smoke harness.
- [x] Verify editor window creation in the smoke harness.
- [x] Verify editor view creation in the smoke harness.
- [x] Verify first-responder request in the smoke harness.
- [x] Verify editable state in the smoke harness.
- [x] Add or keep a file lifecycle smoke check.
- [x] Add or keep a command registration check if practical.
- [x] Add or keep runtime log assertions for the plain-editor path.

## Documentation

- [x] Update `docs/CHANGELOG.md` after each completed architectural cut.
- [x] Record build validation results.
- [x] Record runtime smoke validation results.
- [x] Record resource-warning decisions.
- [x] Record removed legacy surfaces as scope alignment.
- [x] Keep `docs/CODE_ARCHITECTURE.md` current with the actual required build path.
- [x] Keep `docs/FILE_STRUCTURE.md` current with the simplified repo structure.
- [x] Keep `docs/SMOKE_TEST.md` current with automated and local validation steps.

## Final Milestone Checks

- [x] `./build_debug.sh` passes.
- [x] `./scripts/plain_editor_smoke.sh` passes.
- [x] The app launches as a regular foreground app.
- [x] The app opens a deterministic file-backed editor window.
- [x] The editor receives non-empty file text.
- [x] The editor is editable.
- [x] The first-responder path is requested and logged.
- [x] A synthetic or direct edit updates the document model.
- [x] Save writes the edited text.
- [x] Reopen confirms the edit persisted.
- [x] Basic editor commands are registered.
- [x] Required runtime resources are declared or intentionally excluded.
- [x] Remaining warnings are fixed or intentionally documented.
- [x] Documentation reflects the current architecture.

## SwiftPM Build Direction

- [x] Keep `./build_debug.sh` based on `swift build`.
- [x] Keep `./build_release.sh` based on `swift build` where practical.
- [x] Remove required-build dependence on `xcodebuild`.
- [x] Confirm the plain-editor milestone builds through SwiftPM.
- [x] Confirm required dependencies are declared through `Package.swift`.
- [x] Confirm `Package.resolved` is committed for reproducible app builds.
- [x] Treat Xcode project support as optional unless it becomes required later.
