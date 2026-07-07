# Milestone 2 To-Do Checklist

## Purpose

Milestone 2 turns the proven plain-editor foundation into the intended lightweight macOS code editor surface.

Milestone 1 proves that the app can launch, open a real file, display text, edit text, save text, reopen text, and validate the behavior automatically.

Milestone 2 makes the app visibly match the product goal:

- a simple top command bar
- a useful bottom status bar
- light and dark mode support
- Liquid Glass-aligned macOS 26 interface surfaces
- visible syntax highlighting
- syntax mode detection
- real text-cleaning commands
- automated smoke validation for the product-facing editor UI

Use atomic task decomposition. Each task should have one owner, one clear outcome, and one verification step. Dispatch independent tasks in parallel when they do not touch the same source files or behavior paths.

---

## Milestone 2 Entry Criteria

- [ ] Confirm Milestone 1 checklist is current.
- [ ] Confirm `./build_debug.sh` passes.
- [ ] Confirm `./scripts/plain_editor_smoke.sh` passes.
- [ ] Confirm the app launches as a regular foreground app.
- [ ] Confirm a deterministic file-backed editor window opens.
- [ ] Confirm edited text saves and persists after reopen.
- [ ] Confirm remaining Milestone 1 gaps are either closed or explicitly carried into Milestone 2.
- [ ] Confirm syntax highlighting is still marked incomplete unless it is visibly active in the live editor.
- [ ] Confirm this milestone does not reintroduce IDE, terminal, Git, source-control, or workspace-shell scope.

---

## Product Scope Alignment

- [ ] Confirm the app remains a text/code editor, not an IDE.
- [ ] Confirm built-in terminal support remains out of scope.
- [ ] Confirm Git/source-control support remains out of scope.
- [ ] Confirm project/workspace IDE surfaces remain out of scope.
- [ ] Confirm autocomplete remains low priority unless explicitly approved later.
- [ ] Confirm plugins/extensions remain low priority unless explicitly approved later.
- [ ] Confirm SwiftPM remains the required build path.
- [ ] Confirm Xcode project support, if retained, is optional.
- [ ] Confirm the app name and visible product language use `SwiftlyCodeEdit` where product-facing names are updated in this milestone.
- [ ] Confirm the tagline is available for product-facing surfaces: `A fast native code editor for macOS.`

---

## Atomic Dispatch Plan

- [ ] Assign one owner for the top command bar.
- [ ] Assign one owner for the status bar.
- [ ] Assign one owner for light/dark mode verification.
- [ ] Assign one owner for Liquid Glass integration.
- [ ] Assign one owner for syntax highlighting.
- [ ] Assign one owner for syntax mode detection.
- [ ] Assign one owner for Clean Text command behavior.
- [ ] Assign one owner for smoke/App Intents validation.
- [ ] Confirm each owner has one clear outcome.
- [ ] Confirm each owner has one verification step.
- [ ] Confirm independent tasks can proceed in parallel.
- [ ] Confirm tasks that touch the same editor bridge or document model are sequenced safely.

---

## Top Command Bar

Goal: Add a simple top command bar for core editor actions.

Required actions:

- New
- Open...
- Save
- Save As...
- Undo
- Redo
- Clean Text

Checklist:

- [ ] Add a top command bar to the plain-editor window.
- [ ] Use standard SwiftUI/AppKit controls where practical.
- [ ] Keep the command bar visually simple and Mac-native.
- [ ] Avoid workspace, Git, terminal, debugger, project navigator, or IDE toolbar actions.
- [ ] Wire `New` to the same document/new-file path as the menu command.
- [ ] Wire `Open...` to the same file-open path as the menu command.
- [ ] Wire `Save` to the same save path as the menu command.
- [ ] Wire `Save As...` to the same save-as path as the menu command.
- [ ] Wire `Undo` to the active editor undo path.
- [ ] Wire `Redo` to the active editor redo path.
- [ ] Wire `Clean Text` to a real text-cleaning action or keep it visibly disabled until implemented.
- [ ] Confirm command bar buttons do not duplicate fake behavior.
- [ ] Confirm disabled commands appear disabled when unavailable.
- [ ] Confirm keyboard shortcuts still work when the command bar exists.
- [ ] Confirm menu commands still work when the command bar exists.
- [ ] Confirm command bar state updates after opening a file.
- [ ] Confirm command bar state updates after editing a file.
- [ ] Confirm command bar state updates after saving a file.
- [ ] Confirm command bar layout works at small window widths.
- [ ] Confirm command bar layout works at normal editor widths.
- [ ] Confirm command bar works in light mode.
- [ ] Confirm command bar works in dark mode.
- [ ] Add smoke/log validation for command availability where practical.
- [ ] Add screenshot evidence when display access exists.
- [ ] Update docs to describe the command bar.

Verification:

- [ ] Open a known file.
- [ ] Edit the file.
- [ ] Use command bar Save.
- [ ] Reopen and confirm the edit persisted.
- [ ] Use command bar Undo and Redo.
- [ ] Confirm Undo and Redo affect the active editor.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Bottom Status Bar

Goal: Add a document-driven bottom status bar.

Required fields:

- cursor position
- word count
- character count
- indentation mode and size
- text encoding
- line ending / text format
- syntax mode

Checklist:

- [ ] Add a bottom status bar to the plain-editor window.
- [ ] Keep the status bar compact and readable.
- [ ] Keep the status bar document-driven.
- [ ] Update the status bar when a file opens.
- [ ] Update the status bar when text changes.
- [ ] Update the status bar when selection/cursor position changes.
- [ ] Show cursor position.
- [ ] Show total line count or current line context if available.
- [ ] Show word count.
- [ ] Show character count.
- [ ] Show indentation mode, such as `Soft Tabs` or `Tabs`.
- [ ] Show indentation size, such as `2`, `3`, or `4`.
- [ ] Detect indentation mode from file content where practical.
- [ ] Detect indentation size from file content where practical.
- [ ] Show text encoding, such as `UTF-8`.
- [ ] Detect text encoding from file load metadata where practical.
- [ ] Show line ending or text format, such as `LF`, `CRLF`, or `CR`.
- [ ] Detect line ending from file content where practical.
- [ ] Show syntax mode, such as `Swift`, `Markdown`, `JSON`, `YAML`, or `Plain Text`.
- [ ] Confirm provisional/unknown values are clearly labeled.
- [ ] Confirm status bar values do not block editing if detection fails.
- [ ] Confirm status bar works in light mode.
- [ ] Confirm status bar works in dark mode.
- [ ] Confirm status bar remains readable with Liquid Glass styling.
- [ ] Add smoke/log validation for status values where practical.
- [ ] Add screenshot evidence when display access exists.
- [ ] Update docs to describe the status bar.

Verification:

- [ ] Open a known Markdown file and confirm syntax mode is `Markdown`.
- [ ] Open a known Swift file and confirm syntax mode is `Swift`.
- [ ] Open a known plain text file and confirm syntax mode is `Plain Text`.
- [ ] Edit a known file and confirm word/character counts update.
- [ ] Move the cursor and confirm cursor position updates.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Light and Dark Mode

Goal: Confirm the editor and product-facing UI work in both appearances.

Checklist:

- [ ] Confirm the app can run in light mode.
- [ ] Confirm the app can run in dark mode.
- [ ] Confirm the editor text remains readable in light mode.
- [ ] Confirm the editor text remains readable in dark mode.
- [ ] Confirm the command bar remains readable in light mode.
- [ ] Confirm the command bar remains readable in dark mode.
- [ ] Confirm the status bar remains readable in light mode.
- [ ] Confirm the status bar remains readable in dark mode.
- [ ] Confirm selection colors are readable in light mode.
- [ ] Confirm selection colors are readable in dark mode.
- [ ] Confirm insertion point/caret is visible in light mode.
- [ ] Confirm insertion point/caret is visible in dark mode.
- [ ] Confirm syntax highlighting colors are readable in light mode.
- [ ] Confirm syntax highlighting colors are readable in dark mode.
- [ ] Confirm disabled command state is visible in light mode.
- [ ] Confirm disabled command state is visible in dark mode.
- [ ] Confirm system appearance changes update the UI without relaunch where practical.
- [ ] Confirm custom colors use semantic/system-aware values where practical.
- [ ] Confirm high contrast does not make the editor unusable.
- [ ] Confirm increased contrast does not make the editor unusable.
- [ ] Confirm reduced transparency does not make the command/status surfaces unusable.
- [ ] Save screenshot evidence for light mode when display access exists.
- [ ] Save screenshot evidence for dark mode when display access exists.
- [ ] Update docs with the light/dark validation result.

Verification:

- [ ] Run the app in light mode.
- [ ] Run the app in dark mode.
- [ ] Open the same known file in both modes.
- [ ] Confirm command bar, status bar, editor text, and syntax colors are readable in both modes.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Liquid Glass Integration

Goal: Use macOS 26 system visual language without harming editor readability.

Checklist:

- [ ] Prefer standard SwiftUI/AppKit controls before custom styling.
- [ ] Let standard toolbars, buttons, menus, popovers, and controls inherit system styling where practical.
- [ ] Apply Liquid Glass styling to control/navigation surfaces where it clarifies hierarchy.
- [ ] Keep dense text and code editing surfaces stable and readable.
- [ ] Avoid applying glass effects directly to the main editor text background if readability suffers.
- [ ] Confirm the top command bar uses system-native control styling.
- [ ] Confirm the bottom status bar uses readable system-native styling.
- [ ] Confirm any custom glass surface has a clear interaction purpose.
- [ ] Confirm visual ownership is clear at SwiftUI/AppKit bridge boundaries.
- [ ] Confirm AppKit text editor bridge does not fight SwiftUI visual styling.
- [ ] Confirm reduced transparency remains usable.
- [ ] Confirm reduced motion remains usable.
- [ ] Confirm high contrast remains usable.
- [ ] Confirm Liquid Glass choices work in light mode.
- [ ] Confirm Liquid Glass choices work in dark mode.
- [ ] Add screenshot evidence when display access exists.
- [ ] Update docs to describe where Liquid Glass is used and why.

Verification:

- [ ] Open a known file.
- [ ] Confirm the command bar and status bar feel native to macOS 26.
- [ ] Confirm text remains readable.
- [ ] Confirm controls remain legible over editor content.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Syntax Highlighting

Goal: Implement visible syntax highlighting in the active plain-editor path.

Checklist:

- [ ] Confirm syntax highlighting is not counted complete until visible in the live editor.
- [ ] Choose the first supported syntax mode for implementation.
- [ ] Use Swift or Markdown as the first deterministic smoke target.
- [ ] Keep syntax definitions data-driven where practical.
- [ ] Avoid compiled parser packages for individual languages.
- [ ] Avoid tree-sitter as a required dependency.
- [ ] Confirm syntax highlighting runs through the active editor path.
- [ ] Confirm syntax highlighting does not rely on removed SourceEditor facade behavior.
- [ ] Confirm syntax highlighting does not rely on old IDE/workspace paths.
- [ ] Confirm syntax highlighting applies after opening a file.
- [ ] Confirm syntax highlighting applies after editing a file.
- [ ] Confirm syntax highlighting updates after text changes where practical.
- [ ] Confirm syntax highlighting handles empty documents.
- [ ] Confirm syntax highlighting handles large-enough files without obvious lag.
- [ ] Confirm syntax highlighting colors are theme-aware.
- [ ] Confirm syntax highlighting colors are readable in light mode.
- [ ] Confirm syntax highlighting colors are readable in dark mode.
- [ ] Confirm syntax highlighting failure falls back to readable plain text.
- [ ] Add a deterministic sample file for smoke validation if needed.
- [ ] Add screenshot evidence when display access exists.
- [ ] Add mechanical/log validation where practical.
- [ ] Update docs to describe the initial syntax highlighting path.

Verification:

- [ ] Open a known Swift file.
- [ ] Confirm keywords, comments, strings, and normal identifiers are visually distinct.
- [ ] Open a known Markdown file if Markdown is included in this milestone.
- [ ] Confirm headings, code spans/blocks, links, or emphasis are visually distinct.
- [ ] Edit the file and confirm highlighting remains active.
- [ ] Confirm no visible lag during ordinary typing.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Syntax Mode Detection

Goal: Detect and report the document syntax mode.

Checklist:

- [ ] Detect syntax mode from file extension.
- [ ] Detect `.swift` as `Swift`.
- [ ] Detect `.md` and `.markdown` as `Markdown`.
- [ ] Detect `.json` as `JSON`.
- [ ] Detect `.yaml` and `.yml` as `YAML`.
- [ ] Detect `.txt` as `Plain Text`.
- [ ] Detect unknown extensions as `Plain Text` or `Unknown` with readable fallback.
- [ ] Report syntax mode to the status bar.
- [ ] Use syntax mode to select highlighting when available.
- [ ] Keep syntax mode detection independent from IDE/project state.
- [ ] Add unit tests or smoke checks for extension mapping.
- [ ] Update docs with supported initial syntax modes.

Verification:

- [ ] Open `.swift` and confirm status bar says `Swift`.
- [ ] Open `.md` and confirm status bar says `Markdown`.
- [ ] Open `.json` and confirm status bar says `JSON`.
- [ ] Open `.yaml` or `.yml` and confirm status bar says `YAML`.
- [ ] Open `.txt` and confirm status bar says `Plain Text`.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Text Encoding and Line Ending Detection

Goal: Report useful text-file format details in the status bar.

Checklist:

- [ ] Record the encoding used to load the file.
- [ ] Report `UTF-8` for normal UTF-8 files.
- [ ] Report non-UTF-8 encodings when detectable.
- [ ] Keep unknown encoding fallback readable and non-blocking.
- [ ] Detect line endings from content.
- [ ] Report `LF`.
- [ ] Report `CRLF`.
- [ ] Report `CR` if encountered.
- [ ] Preserve existing line endings when saving where practical.
- [ ] Confirm Clean Text can normalize line endings if that action is implemented.
- [ ] Add tests or smoke checks for encoding/line-ending reporting where practical.
- [ ] Update docs with known limitations.

Verification:

- [ ] Open a known UTF-8 LF file and confirm status reports `UTF-8` and `LF`.
- [ ] Open a known CRLF file if available and confirm status reports `CRLF`.
- [ ] Save and reopen a known file.
- [ ] Confirm file format reporting remains stable.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Indentation Detection

Goal: Report indentation style and size.

Checklist:

- [ ] Detect tabs when tab characters dominate indentation.
- [ ] Detect soft tabs when spaces dominate indentation.
- [ ] Estimate indentation size from leading spaces.
- [ ] Report common sizes such as 2, 3, 4, and 8.
- [ ] Use a clear fallback for mixed/unknown indentation.
- [ ] Report indentation in the status bar.
- [ ] Update indentation report after opening a file.
- [ ] Update indentation report after significant edits where practical.
- [ ] Keep detection fast for large files.
- [ ] Add tests or smoke checks for tab/space files.
- [ ] Update docs with known limitations.

Verification:

- [ ] Open a known 2-space file and confirm `Soft Tabs: 2`.
- [ ] Open a known 4-space file and confirm `Soft Tabs: 4`.
- [ ] Open a known tab-indented file and confirm tab indentation.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Clean Text Command

Goal: Add the first real text-cleaning behavior.

Candidate first actions:

- trim trailing whitespace
- normalize line endings
- ensure final newline
- convert tabs to spaces
- convert spaces to tabs
- normalize Unicode

Checklist:

- [ ] Decide the first Clean Text action for Milestone 2.
- [ ] Keep the first action narrow and deterministic.
- [ ] Wire Clean Text through the command bar.
- [ ] Wire Clean Text through the app menu if appropriate.
- [ ] Confirm Clean Text mutates the active document model.
- [ ] Confirm Clean Text marks the document dirty.
- [ ] Confirm Clean Text can be undone.
- [ ] Confirm Clean Text can be redone.
- [ ] Confirm Save writes cleaned text.
- [ ] Confirm reopen preserves cleaned text.
- [ ] Confirm Clean Text is disabled when no editable document is active.
- [ ] Add a file lifecycle smoke check for Clean Text.
- [ ] Update docs to describe the implemented cleaning action.

Verification:

- [ ] Open a known file with trailing whitespace or line-ending issue.
- [ ] Run Clean Text.
- [ ] Confirm the expected text transformation occurs.
- [ ] Undo the transformation.
- [ ] Redo the transformation.
- [ ] Save and reopen.
- [ ] Confirm cleaned text persisted.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Undo and Redo Product Validation

Goal: Prove Undo and Redo work in the active editor path, not only as registered commands.

Checklist:

- [ ] Confirm the active editor owns or exposes the undo manager used by commands.
- [ ] Confirm the top command bar Undo reaches the active editor.
- [ ] Confirm the top command bar Redo reaches the active editor.
- [ ] Confirm menu Undo reaches the active editor.
- [ ] Confirm menu Redo reaches the active editor.
- [ ] Confirm keyboard shortcut Undo reaches the active editor.
- [ ] Confirm keyboard shortcut Redo reaches the active editor.
- [ ] Confirm typing creates undoable edits.
- [ ] Confirm Clean Text creates an undoable edit if Clean Text is implemented.
- [ ] Confirm Undo updates the document model.
- [ ] Confirm Redo updates the document model.
- [ ] Confirm Undo/Redo command enabled state updates after edits.
- [ ] Add smoke validation where practical.

Verification:

- [ ] Open a known file.
- [ ] Apply a text edit.
- [ ] Trigger Undo.
- [ ] Confirm the previous text returns.
- [ ] Trigger Redo.
- [ ] Confirm the edited text returns.
- [ ] Save and reopen the expected final text.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Find and Replace

Goal: Provide a simple editor find/replace surface if included in Milestone 2.

Checklist:

- [ ] Decide whether Find is included in Milestone 2.
- [ ] Decide whether Replace is included in Milestone 2.
- [ ] Decide whether regex is included in Milestone 2 or deferred.
- [ ] Keep Find/Replace plain-editor focused.
- [ ] Avoid project-wide search.
- [ ] Avoid workspace indexing.
- [ ] Wire Find to the active document.
- [ ] Confirm Find works in the active editor.
- [ ] Confirm Find highlights or navigates matches.
- [ ] Confirm Replace mutates the active document if included.
- [ ] Confirm Replace can be undone if included.
- [ ] Confirm regex behavior is tested if included.
- [ ] Update docs with included/deferred behavior.

Verification:

- [ ] Open a known file with repeated text.
- [ ] Run Find.
- [ ] Confirm expected matches are found.
- [ ] Run Replace if included.
- [ ] Confirm expected text changes.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## App Intents Smoke Hooks

Goal: Use App Intents only as narrow smoke-test hooks if they reduce human validation.

Candidate intents:

- `OpenKnownFileIntent`
- `ReportEditorStateIntent`
- `ApplySyntheticEditIntent`
- `SaveCurrentDocumentIntent`
- `ReopenAndVerifyIntent`
- `ReportStatusBarIntent`
- `RunCleanTextIntent`

Checklist:

- [ ] Decide whether App Intents are included in Milestone 2 smoke validation.
- [ ] Keep App Intents out of user-facing product scope unless explicitly approved.
- [ ] Implement only narrow validation hooks.
- [ ] Ensure intents exercise the same document/editor path as the app.
- [ ] Return assertable values from each intent.
- [ ] Return loaded file path.
- [ ] Return character count.
- [ ] Return word count where available.
- [ ] Return syntax mode where available.
- [ ] Return indentation mode/size where available.
- [ ] Return save result.
- [ ] Return persisted-edit result.
- [ ] Add smoke script assertions for returned values.
- [ ] Document App Intents as smoke-test infrastructure if included.

Verification:

- [ ] Run the smoke flow without human interaction.
- [ ] Open a known file through the intent path.
- [ ] Report editor state.
- [ ] Apply a synthetic edit.
- [ ] Save.
- [ ] Reopen.
- [ ] Verify the edit persisted.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Automated Milestone 2 Smoke Validation

Goal: Extend automated validation to cover product-facing editor behavior.

Checklist:

- [ ] Keep `scripts/plain_editor_smoke.sh` deterministic.
- [ ] Validate app launch.
- [ ] Validate file load.
- [ ] Validate command bar availability where practical.
- [ ] Validate status bar values where practical.
- [ ] Validate syntax mode detection.
- [ ] Validate syntax highlighting mechanically or through screenshot evidence where practical.
- [ ] Validate edit/save/reopen still works.
- [ ] Validate Undo/Redo behavior where practical.
- [ ] Validate Clean Text behavior if implemented.
- [ ] Validate light/dark mode through logs or screenshot evidence where practical.
- [ ] Save smoke outputs under `test-results/`.
- [ ] Keep smoke tests useful without requiring a human visual gate.
- [ ] Keep screenshot capture supplemental, not required.
- [ ] Record exact reason if screenshot capture is unavailable.
- [ ] Update `docs/SMOKE_TEST.md`.

Verification:

- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.
- [ ] Confirm test outputs show Milestone 2 assertions.
- [ ] Confirm no human-only verification is required for completion.

---

## Documentation Updates

- [ ] Update `docs/CHANGELOG.md`.
- [ ] Update `docs/CODE_ARCHITECTURE.md`.
- [ ] Update `docs/FILE_STRUCTURE.md`.
- [ ] Update `docs/SMOKE_TEST.md`.
- [ ] Document the top command bar.
- [ ] Document the bottom status bar.
- [ ] Document light/dark mode validation.
- [ ] Document Liquid Glass usage.
- [ ] Document initial syntax highlighting support.
- [ ] Document syntax mode detection.
- [ ] Document text encoding and line-ending reporting.
- [ ] Document indentation reporting.
- [ ] Document Clean Text behavior if implemented.
- [ ] Document App Intents smoke hooks if implemented.
- [ ] Remove or update docs that still describe old IDE, terminal, Git, or workspace-shell surfaces as active product features.
- [ ] Keep changelog history accurate without making old removed surfaces sound active.

---

## Repo Cleanup During Milestone 2

- [ ] Run `rg SwiftTerm`.
- [ ] Run `rg TerminalEmulator`.
- [ ] Run `rg Terminal`.
- [ ] Confirm remaining terminal references are historical, generic, or removed.
- [ ] Run `rg SourceControl`.
- [ ] Run `rg Git`.
- [ ] Confirm remaining Git/source-control references are historical, generic, or removed.
- [ ] Run `rg xcode`.
- [ ] Confirm Xcode references are optional support, generated metadata, docs, or removed.
- [ ] Remove old UI tests that only validate removed IDE surfaces.
- [ ] Remove old docs that only describe removed IDE surfaces.
- [ ] Keep required build path clean and SwiftPM-first.

Verification:

- [ ] Build still passes after cleanup.
- [ ] Smoke still passes after cleanup.
- [ ] Active docs match active product scope.

---

## Performance and Responsiveness

Goal: Keep the editor fast and lightweight.

Checklist:

- [ ] Confirm app launch remains fast enough for the milestone.
- [ ] Confirm ordinary typing does not visibly lag.
- [ ] Confirm status bar updates do not create typing lag.
- [ ] Confirm syntax highlighting does not create obvious typing lag.
- [ ] Confirm large-enough files open without obvious stalls.
- [ ] Confirm status calculations are efficient enough for normal files.
- [ ] Confirm expensive detection work is throttled, cached, or scoped where practical.
- [ ] Confirm UI updates happen on the correct actor.
- [ ] Confirm background work does not mutate UI state directly.
- [ ] Add performance notes or measurements where practical.

Verification:

- [ ] Open a small file.
- [ ] Open a medium source file.
- [ ] Type in the editor.
- [ ] Confirm no obvious lag.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Accessibility and Native Mac Behavior

Checklist:

- [ ] Confirm command bar controls have accessible labels.
- [ ] Confirm status bar values are accessible where practical.
- [ ] Confirm keyboard navigation reaches editor and commands.
- [ ] Confirm standard menu commands remain available.
- [ ] Confirm focus behavior remains Mac-native.
- [ ] Confirm VoiceOver does not encounter unlabeled critical controls where practical.
- [ ] Confirm high contrast remains readable.
- [ ] Confirm increased contrast remains readable.
- [ ] Confirm reduced transparency remains usable.
- [ ] Confirm reduced motion remains usable.
- [ ] Confirm window resizing keeps the editor usable.
- [ ] Confirm file drag/drop behavior remains unchanged or intentionally deferred.
- [ ] Confirm autosave/external-change behavior remains unchanged or intentionally deferred.

Verification:

- [ ] Navigate basic commands with keyboard where practical.
- [ ] Open and edit a file without using the mouse where practical.
- [ ] Confirm the editor remains usable after resizing the window.
- [ ] Run `./build_debug.sh`.
- [ ] Run `./scripts/plain_editor_smoke.sh`.

---

## Milestone 2 Final Checks

- [ ] `./build_debug.sh` passes.
- [ ] `./scripts/plain_editor_smoke.sh` passes.
- [ ] The app launches as a regular foreground app.
- [ ] A deterministic file-backed editor window opens.
- [ ] The top command bar is visible.
- [ ] The top command bar contains New.
- [ ] The top command bar contains Open.
- [ ] The top command bar contains Save.
- [ ] The top command bar contains Save As.
- [ ] The top command bar contains Undo.
- [ ] The top command bar contains Redo.
- [ ] The top command bar contains Clean Text.
- [ ] The top command bar buttons call real app command paths.
- [ ] The bottom status bar is visible.
- [ ] The status bar shows cursor position.
- [ ] The status bar shows word count.
- [ ] The status bar shows character count.
- [ ] The status bar shows indentation mode/size.
- [ ] The status bar shows encoding or a clear fallback.
- [ ] The status bar shows line ending/text format or a clear fallback.
- [ ] The status bar shows syntax mode.
- [ ] Light mode is validated.
- [ ] Dark mode is validated.
- [ ] Liquid Glass/system styling is applied to control surfaces where appropriate.
- [ ] Dense editor content remains readable.
- [ ] Syntax highlighting is visibly active in the live editor.
- [ ] Syntax mode detection works for initial supported file types.
- [ ] Clean Text works or is intentionally deferred with disabled UI.
- [ ] Undo works in the active editor path.
- [ ] Redo works in the active editor path.
- [ ] Cut works in the active editor path.
- [ ] Copy works in the active editor path.
- [ ] Paste works in the active editor path.
- [ ] Select All works in the active editor path.
- [ ] Find works if included in this milestone.
- [ ] Save still writes edited text.
- [ ] Reopen still confirms edited text persisted.
- [ ] Smoke validation includes Milestone 2 assertions where practical.
- [ ] Screenshot evidence is saved when display access exists.
- [ ] Documentation reflects the Milestone 2 app surface.
- [ ] Removed IDE/terminal/Git/workspace surfaces are not described as active product features.
- [ ] Remaining warnings are fixed or intentionally documented.
- [ ] The app remains a fast, lightweight, native macOS code editor.
