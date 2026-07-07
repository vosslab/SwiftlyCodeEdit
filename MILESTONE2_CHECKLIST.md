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

- [x] Confirm Milestone 1 checklist is current.
- [x] Confirm `./build_debug.sh` passes.
- [x] Confirm `./scripts/plain_editor_smoke.sh` passes.
- [x] Confirm the app launches as a regular foreground app.
- [x] Confirm a deterministic file-backed editor window opens.
- [x] Confirm edited text saves and persists after reopen.
- [x] Confirm remaining Milestone 1 gaps are either closed or explicitly carried into Milestone 2.
- [x] Confirm syntax highlighting is still marked incomplete unless it is visibly active in the live editor.
- [x] Confirm this milestone does not reintroduce IDE, terminal, Git, source-control, or workspace-shell scope.

---

## Product Scope Alignment

- [x] Confirm the app remains a text/code editor, not an IDE.
- [x] Confirm built-in terminal support remains out of scope.
- [x] Confirm Git/source-control support remains out of scope.
- [x] Confirm project/workspace IDE surfaces remain out of scope.
- [x] Confirm autocomplete remains low priority unless explicitly approved later.
- [x] Confirm plugins/extensions remain low priority unless explicitly approved later.
- [x] Confirm SwiftPM remains the required build path.
- [x] Confirm Xcode project support, if retained, is optional.
- [x] Confirm the app name and visible product language use `SwiftlyCodeEdit` where product-facing names are updated in this milestone.
- [x] Confirm the tagline is available for product-facing surfaces: `A fast native code editor for macOS.`

---

## Atomic Dispatch Plan

- [ ] Assign one owner for the top command bar.
- [ ] Assign one owner for the status bar.
- [ ] Assign one owner for editor font and font-size customization.
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

- [x] Add a top command bar to the plain-editor window.
- [x] Use standard SwiftUI/AppKit controls where practical.
- [x] Keep the command bar visually simple and Mac-native.
- [x] Avoid workspace, Git, terminal, debugger, project navigator, or IDE toolbar actions.
- [x] Wire `New` to the same document/new-file path as the menu command.
- [x] Wire `Open...` to the same file-open path as the menu command.
- [x] Wire `Save` to the same save path as the menu command.
- [x] Wire `Save As...` to the same save-as path as the menu command.
- [x] Wire `Undo` to the active editor undo path.
- [x] Wire `Redo` to the active editor redo path.
- [x] Wire `Clean Text` to a real text-cleaning action or keep it visibly disabled until implemented.
- [x] Confirm command bar buttons do not duplicate fake behavior.
- [x] Confirm disabled commands appear disabled when unavailable.
- [x] Confirm keyboard shortcuts still work when the command bar exists.
- [x] Confirm menu commands still work when the command bar exists.
- [x] Confirm command bar state updates after opening a file.
- [x] Confirm command bar state updates after editing a file.
- [x] Confirm command bar state updates after saving a file.
- [ ] Confirm command bar layout works at small window widths.
- [ ] Confirm command bar layout works at normal editor widths.
- [ ] Confirm command bar works in light mode.
- [ ] Confirm command bar works in dark mode.
- [x] Add smoke/log validation for command availability where practical.
- [ ] Add screenshot evidence when display access exists.
- [x] Update docs to describe the command bar.

Verification:

- [x] Open a known file.
- [x] Edit the file.
- [x] Use command bar Save.
- [x] Reopen and confirm the edit persisted.
- [x] Use command bar Undo and Redo.
- [x] Confirm Undo and Redo affect the active editor.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

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

- [x] Add a bottom status bar to the plain-editor window.
- [x] Keep the status bar compact and readable.
- [x] Keep the status bar document-driven.
- [x] Update the status bar when a file opens.
- [x] Update the status bar when text changes.
- [x] Update the status bar when selection/cursor position changes.
- [x] Show cursor position.
- [x] Show total line count or current line context if available.
- [x] Show word count.
- [x] Show character count.
- [x] Show indentation mode, such as `Soft Tabs` or `Tabs`.
- [x] Show indentation size, such as `2`, `3`, or `4`.
- [x] Detect indentation mode from file content where practical.
- [x] Detect indentation size from file content where practical.
- [x] Show text encoding, such as `UTF-8`.
- [x] Detect text encoding from file load metadata where practical.
- [x] Show line ending or text format, such as `LF`, `CRLF`, or `CR`.
- [x] Detect line ending from file content where practical.
- [x] Show syntax mode, such as `Swift`, `Markdown`, `JSON`, `YAML`, or `Plain Text`.
- [x] Confirm provisional/unknown values are clearly labeled.
- [x] Confirm status bar values do not block editing if detection fails.
- [x] Confirm status bar works in light mode.
- [x] Confirm status bar works in dark mode.
- [x] Confirm status bar remains readable with Liquid Glass styling.
- [x] Add smoke/log validation for status values where practical.
- [x] Add screenshot evidence when display access exists.
- [x] Update docs to describe the status bar.

Verification:

- [x] Open a known Markdown file and confirm syntax mode is `Markdown`.
- [x] Open a known Swift file and confirm syntax mode is `Swift`.
- [x] Open a known plain text file and confirm syntax mode is `Plain Text`.
- [x] Edit a known file and confirm word/character counts update.
- [x] Move the cursor and confirm cursor position updates.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## Editor Font and Font Size

Goal: Let the user customize the editor font family and font size without breaking readability, syntax highlighting, or editor performance.

Checklist:

- [x] Add an editor font preference.
- [x] Add an editor font-size preference.
- [x] Use a sensible default monospace font.
- [x] Use a sensible default font size.
- [x] Allow the editor font family to be changed from settings or an editor appearance control.
- [x] Allow the editor font size to be increased.
- [x] Allow the editor font size to be decreased.
- [x] Allow the editor font size to be reset to the default.
- [x] Persist the selected font family.
- [x] Persist the selected font size.
- [x] Apply the selected font family to the active editor.
- [x] Apply the selected font size to the active editor.
- [x] Apply font changes without requiring the document to be reopened where practical.
- [ ] Confirm syntax highlighting remains visible after changing font.
- [ ] Confirm cursor position and text selection remain usable after changing font.
- [ ] Confirm line height and scrolling remain usable after changing font.
- [ ] Confirm the status bar remains readable after font-size changes.
- [ ] Confirm the command bar remains readable after font-size changes.
- [ ] Confirm light mode remains readable after font changes.
- [ ] Confirm dark mode remains readable after font changes.
- [x] Confirm invalid or unavailable fonts fall back to a safe default.
- [ ] Confirm large font sizes do not break the editor layout.
- [ ] Confirm small font sizes do not make the editor unusable by default.
- [x] Add smoke/log validation for persisted font settings where practical.
- [x] Add screenshot evidence when display access exists.
- [x] Update docs to describe editor font and font-size customization.

Verification:

- [x] Open a known file.
- [ ] Change the editor font family.
- [ ] Confirm the visible editor font changes.
- [ ] Change the editor font size.
- [ ] Confirm the visible editor font size changes.
- [ ] Close and relaunch the app.
- [ ] Confirm the selected font family persists.
- [ ] Confirm the selected font size persists.
- [ ] Reset to the default font settings.
- [ ] Confirm the editor returns to the default appearance.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

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

- [x] Confirm syntax highlighting is not counted complete until visible in the live editor.
- [x] Choose the first supported syntax mode for implementation.
- [x] Use Swift or Markdown as the first deterministic smoke target.
- [x] Keep syntax definitions data-driven where practical.
- [x] Avoid compiled parser packages for individual languages.
- [x] Avoid tree-sitter as a required dependency.
- [x] Confirm syntax highlighting runs through the active editor path.
- [x] Confirm syntax highlighting does not rely on removed SourceEditor facade behavior.
- [x] Confirm syntax highlighting does not rely on old IDE/workspace paths.
- [x] Confirm syntax highlighting applies after opening a file.
- [x] Confirm syntax highlighting applies after editing a file.
- [x] Confirm syntax highlighting updates after text changes where practical.
- [ ] Confirm syntax highlighting handles empty documents.
- [ ] Confirm syntax highlighting handles large-enough files without obvious lag.
- [x] Confirm syntax highlighting colors are theme-aware.
- [x] Confirm syntax highlighting colors are readable in dark mode.
- [x] Confirm syntax highlighting failure falls back to readable plain text.
- [x] Add a deterministic sample file for smoke validation if needed.
- [x] Add screenshot evidence when display access exists.
- [x] Add mechanical/log validation where practical.
- [x] Update docs to describe the initial syntax highlighting path.

Verification:

- [x] Open a known Swift file.
- [x] Confirm keywords, comments, strings, and normal identifiers are visually distinct.
- [ ] Open a known Markdown file if Markdown is included in this milestone.
- [ ] Confirm headings, code spans/blocks, links, or emphasis are visually distinct.
- [x] Edit the file and confirm highlighting remains active.
- [ ] Confirm no visible lag during ordinary typing.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## Syntax Mode Detection

Goal: Detect and report the document syntax mode.

Checklist:

- [x] Detect syntax mode from file extension.
- [x] Detect `.swift` as `Swift`.
- [ ] Detect `.md` and `.markdown` as `Markdown`.
- [ ] Detect `.json` as `JSON`.
- [ ] Detect `.yaml` and `.yml` as `YAML`.
- [ ] Detect `.txt` as `Plain Text`.
- [ ] Detect unknown extensions as `Plain Text` or `Unknown` with readable fallback.
- [x] Report syntax mode to the status bar.
- [x] Use syntax mode to select highlighting when available.
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
- [x] Validate syntax highlighting mechanically or through screenshot evidence where practical.
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

- [x] Update `docs/CHANGELOG.md`.
- [ ] Update `docs/CODE_ARCHITECTURE.md`.
- [ ] Update `docs/FILE_STRUCTURE.md`.
- [ ] Update `docs/SMOKE_TEST.md`.
- [ ] Document the top command bar.
- [ ] Document the bottom status bar.
- [ ] Document light/dark mode validation.
- [ ] Document Liquid Glass usage.
- [x] Document initial syntax highlighting support.
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

- [x] `./build_debug.sh` passes.
- [x] `./scripts/plain_editor_smoke.sh` passes.
- [x] The app launches as a regular foreground app.
- [x] A deterministic file-backed editor window opens.
- [x] The top command bar is visible.
- [ ] The top command bar contains New.
- [ ] The top command bar contains Open.
- [ ] The top command bar contains Save.
- [ ] The top command bar contains Save As.
- [ ] The top command bar contains Undo.
- [ ] The top command bar contains Redo.
- [ ] The top command bar contains Clean Text.
- [x] The top command bar buttons call real app command paths.
- [x] The bottom status bar is visible.
- [x] The status bar shows cursor position.
- [x] The status bar shows word count.
- [x] The status bar shows character count.
- [x] The status bar shows indentation mode/size.
- [x] The status bar shows encoding or a clear fallback.
- [x] The status bar shows line ending/text format or a clear fallback.
- [x] The status bar shows syntax mode.
- [ ] Editor font customization works.
- [ ] Editor font-size customization works.
- [ ] Editor font and font-size settings persist after relaunch.
- [ ] Light mode is validated.
- [ ] Dark mode is validated.
- [ ] Liquid Glass/system styling is applied to control surfaces where appropriate.
- [x] Dense editor content remains readable.
- [x] Syntax highlighting is visibly active in the live editor.
- [x] Syntax mode detection works for initial supported file types.
- [x] Clean Text works or is intentionally deferred with disabled UI.
- [x] Undo works in the active editor path.
- [x] Redo works in the active editor path.
- [x] Cut works in the active editor path.
- [x] Copy works in the active editor path.
- [x] Paste works in the active editor path.
- [x] Select All works in the active editor path.
- [x] Find works if included in this milestone.
- [x] Save still writes edited text.
- [x] Reopen still confirms edited text persisted.
- [x] Smoke validation includes Milestone 2 assertions where practical.
- [x] Screenshot evidence is saved when display access exists.
- [x] Documentation reflects the Milestone 2 app surface.
- [x] Removed IDE/terminal/Git/workspace surfaces are not described as active product features.
- [x] Remaining warnings are fixed or intentionally documented.
- [x] The app remains a fast, lightweight, native macOS code editor.
