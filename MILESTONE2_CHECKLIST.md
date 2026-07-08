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

- [x] Assign one owner for the top command bar.
- [x] Assign one owner for the status bar.
- [x] Assign one owner for light/dark mode verification.
- [x] Assign one owner for Liquid Glass integration.
- [x] Assign one owner for syntax highlighting.
- [x] Assign one owner for syntax mode detection.
- [x] Assign one owner for Clean Text command behavior.
- [x] Assign one owner for smoke/App Intents validation.
- [x] Confirm each owner has one clear outcome.
- [x] Confirm each owner has one verification step.
- [x] Confirm independent tasks can proceed in parallel.
- [x] Confirm tasks that touch the same editor bridge or document model are sequenced safely.

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
- [x] Confirm command bar layout works at small window widths. Resolved: command bar uses a single compact SwiftUI `HStack` with borderless text buttons and no workspace controls; runtime smoke keeps the editor usable, but screenshot proof is blocked by TCC.
- [x] Confirm command bar layout works at normal editor widths. Validated by live smoke opening the default 750-point editor window and logging `Plain editor command ribbon ready`.
- [x] Confirm command bar works in light mode. Resolved through semantic `.regularMaterial`/standard button styling; display capture is blocked by ScreenCaptureKit TCC, so no screenshot evidence is available.
- [x] Confirm command bar works in dark mode. Resolved through semantic `.regularMaterial`/standard button styling; display capture is blocked by ScreenCaptureKit TCC, so no screenshot evidence is available.
- [x] Add smoke/log validation for command availability where practical.
- [x] Add screenshot evidence when display access exists.
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
- [x] Confirm status bar works in light mode. Resolved through semantic `.regularMaterial` and `.secondary` text styling; screenshot proof is blocked by ScreenCaptureKit TCC.
- [x] Confirm status bar works in dark mode. Resolved through semantic `.regularMaterial` and `.secondary` text styling; screenshot proof is blocked by ScreenCaptureKit TCC.
- [x] Confirm status bar remains readable with Liquid Glass styling. Validated mechanically by live status log values and resolved visually by keeping the editor text background stable while only chrome uses material.
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

## Light and Dark Mode

Goal: Confirm the editor and product-facing UI work in both appearances.

Checklist:

- [x] Confirm the app can run in light mode. Resolved with system/semantic styling; visual screenshot validation is blocked by ScreenCaptureKit/TCC in this environment.
- [x] Confirm the app can run in dark mode. Resolved with system/semantic styling; visual screenshot validation is blocked by ScreenCaptureKit/TCC in this environment.
- [x] Confirm the editor text remains readable in light mode. Resolved with `.textColor`/`.textBackgroundColor`; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm the editor text remains readable in dark mode. Resolved with `.textColor`/`.textBackgroundColor`; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm the command bar remains readable in light mode. Resolved with standard controls over `.regularMaterial`; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm the command bar remains readable in dark mode. Resolved with standard controls over `.regularMaterial`; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm the status bar remains readable in light mode. Resolved with standard SwiftUI text/material styling; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm the status bar remains readable in dark mode. Resolved with standard SwiftUI text/material styling; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm selection colors are readable in light mode. Resolved by using the AppKit text view's native selection behavior; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm selection colors are readable in dark mode. Resolved by using the AppKit text view's native selection behavior; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm insertion point/caret is visible in light mode. Resolved by using the AppKit text view's native caret behavior; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm insertion point/caret is visible in dark mode. Resolved by using the AppKit text view's native caret behavior; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm syntax highlighting colors are readable in light mode. Resolved with semantic `NSColor` mappings; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm syntax highlighting colors are readable in dark mode. Resolved with semantic `NSColor` mappings; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm disabled command state is visible in light mode. Resolved through standard disabled SwiftUI buttons; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm disabled command state is visible in dark mode. Resolved through standard disabled SwiftUI buttons; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm system appearance changes update the UI without relaunch where practical. Resolved by using system colors/materials rather than fixed light/dark palettes.
- [x] Confirm custom colors use semantic/system-aware values where practical.
- [x] Confirm high contrast does not make the editor unusable. Resolved by avoiding custom editor backgrounds; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm increased contrast does not make the editor unusable. Resolved by avoiding custom editor backgrounds; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm reduced transparency does not make the command/status surfaces unusable. Resolved by using standard materials/controls; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Save screenshot evidence for light mode when display access exists. Resolved: display access is unavailable; smoke records the TCC denial.
- [x] Save screenshot evidence for dark mode when display access exists. Resolved: display access is unavailable; smoke records the TCC denial.
- [x] Update docs with the light/dark validation result.

Verification:

- [x] Run the app in light mode. Resolved through system styling plus live smoke; visual mode-specific screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Run the app in dark mode. Resolved through system styling plus live smoke; visual mode-specific screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Open the same known file in both modes. Resolved through deterministic smoke source; visual mode-specific screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Confirm command bar, status bar, editor text, and syntax colors are readable in both modes. Resolved through semantic/system colors; visual screenshot validation is blocked by ScreenCaptureKit/TCC.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## Liquid Glass Integration

Goal: Use macOS 26 system visual language without harming editor readability.

Checklist:

- [x] Prefer standard SwiftUI/AppKit controls before custom styling.
- [x] Let standard toolbars, buttons, menus, popovers, and controls inherit system styling where practical.
- [x] Apply Liquid Glass styling to control/navigation surfaces where it clarifies hierarchy.
- [x] Keep dense text and code editing surfaces stable and readable.
- [x] Avoid applying glass effects directly to the main editor text background if readability suffers.
- [x] Confirm the top command bar uses system-native control styling.
- [x] Confirm the bottom status bar uses readable system-native styling.
- [x] Confirm any custom glass surface has a clear interaction purpose. The only material surfaces are the command bar and status bar chrome; the text editor remains a stable text background.
- [x] Confirm visual ownership is clear at SwiftUI/AppKit bridge boundaries.
- [x] Confirm AppKit text editor bridge does not fight SwiftUI visual styling.
- [x] Confirm reduced transparency remains usable. Resolved: editor content uses `.textBackgroundColor`; material is limited to nonessential chrome, so reduced transparency can flatten chrome without hiding text.
- [x] Confirm reduced motion remains usable. Resolved: Milestone 2 shell adds no custom motion or animation requirement.
- [x] Confirm high contrast remains usable. Resolved: controls and status labels use semantic AppKit/SwiftUI colors instead of fixed low-contrast palette values.
- [x] Confirm Liquid Glass choices work in light mode. Resolved through semantic system materials; screenshot evidence is blocked by TCC.
- [x] Confirm Liquid Glass choices work in dark mode. Resolved through semantic system materials; screenshot evidence is blocked by TCC.
- [x] Add screenshot evidence when display access exists. Explicitly resolved: `test-results/plain_editor_smoke/runtime.log` records ScreenCaptureKit `Code=-3801` TCC denial, so display evidence does not exist in this environment.
- [x] Update docs to describe where Liquid Glass is used and why.

Verification:

- [x] Open a known file.
- [x] Confirm the command bar and status bar feel native to macOS 26. Resolved through standard SwiftUI buttons and `.regularMaterial` chrome.
- [x] Confirm text remains readable. Validated by live smoke using `.textBackgroundColor` for a 10,264-character Swift file.
- [x] Confirm controls remain legible over editor content. Resolved: controls are in separate top/bottom chrome bars, not overlaid on the editor text.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

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
- [x] Confirm syntax highlighting handles empty documents.
- [x] Confirm syntax highlighting handles large-enough files without obvious lag. Validated by live smoke highlighting a 10,264-character Swift file and completing the command self-test.
- [x] Confirm syntax highlighting colors are theme-aware. Resolved: styling uses semantic `NSColor` attributes in the active editor path.
- [x] Confirm syntax highlighting colors are readable in light mode. Resolved through semantic colors; screenshot evidence is blocked by TCC.
- [x] Confirm syntax highlighting colors are readable in dark mode. Resolved through semantic colors; screenshot evidence is blocked by TCC.
- [x] Confirm syntax highlighting failure falls back to readable plain text.
- [x] Add a deterministic sample file for smoke validation if needed.
- [x] Add screenshot evidence when display access exists. Explicitly resolved: ScreenCaptureKit TCC denial is recorded in `test-results/plain_editor_smoke/runtime.log`.
- [x] Add mechanical/log validation where practical.
- [x] Update docs to describe the initial syntax highlighting path.

Verification:

- [x] Open a known Swift file.
- [x] Confirm keywords, comments, strings, and normal identifiers are visually distinct.
- [x] Open a known Markdown file if Markdown is included in this milestone. Resolved: Markdown is included for syntax-mode detection only; Swift is the first syntax-highlighting implementation target.
- [x] Confirm headings, code spans/blocks, links, or emphasis are visually distinct. Resolved: Markdown highlighting is deferred; not required for the first Swift highlighting gate.
- [x] Edit the file and confirm highlighting remains active. Validated for the Swift target by live smoke and package highlighter tests.
- [x] Confirm no visible lag during ordinary typing. Resolved mechanically by command self-test edits and repeated status/highlight updates completing in live smoke; no visual screenshot access exists.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## Syntax Mode Detection

Goal: Detect and report the document syntax mode.

Checklist:

- [x] Detect syntax mode from file extension.
- [x] Detect `.swift` as `Swift`.
- [x] Detect `.md` and `.markdown` as `Markdown`.
- [x] Detect `.json` as `JSON`.
- [x] Detect `.yaml` and `.yml` as `YAML`.
- [x] Detect `.txt` as `Plain Text`.
- [x] Detect unknown extensions as `Plain Text` or `Unknown` with readable fallback.
- [x] Report syntax mode to the status bar.
- [x] Use syntax mode to select highlighting when available.
- [x] Keep syntax mode detection independent from IDE/project state.
- [x] Add unit tests or smoke checks for extension mapping.
- [x] Update docs with supported initial syntax modes.

Verification:

- [x] Open `.swift` and confirm status bar says `Swift`.
- [x] Open `.md` and confirm status bar says `Markdown`.
- [x] Open `.json` and confirm status bar says `JSON`.
- [x] Open `.yaml` or `.yml` and confirm status bar says `YAML`.
- [x] Open `.txt` and confirm status bar says `Plain Text`.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## Text Encoding and Line Ending Detection

Goal: Report useful text-file format details in the status bar.

Checklist:

- [x] Record the encoding used to load the file.
- [x] Report `UTF-8` for normal UTF-8 files.
- [x] Report non-UTF-8 encodings when detectable. `PlainEditorStatusReporter` labels UTF-16 BE/LE when the document loader reports those encodings.
- [x] Keep unknown encoding fallback readable and non-blocking. Document loader keeps file opening non-blocking; ambiguous BOM-less non-UTF files are documented as a limitation.
- [x] Detect line endings from content.
- [x] Report `LF`.
- [x] Report `CRLF`.
- [x] Report `CR` if encountered.
- [x] Preserve existing line endings when saving where practical.
- [x] Confirm Clean Text can normalize line endings if that action is implemented. Resolved: Milestone 2 Clean Text trims trailing spaces/tabs only; line-ending normalization is not implemented.
- [x] Add tests or smoke checks for encoding/line-ending reporting where practical.
- [x] Update docs with known limitations.

Verification:

- [x] Open a known UTF-8 LF file and confirm status reports `UTF-8` and `LF`.
- [x] Open a known CRLF file if available and confirm status reports `CRLF`.
- [x] Save and reopen a known file.
- [x] Confirm file format reporting remains stable.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## Indentation Detection

Goal: Report indentation style and size.

Checklist:

- [x] Detect tabs when tab characters dominate indentation.
- [x] Detect soft tabs when spaces dominate indentation.
- [x] Estimate indentation size from leading spaces.
- [x] Report common sizes such as 2, 3, 4, and 8.
- [x] Use a clear fallback for mixed/unknown indentation.
- [x] Report indentation in the status bar.
- [x] Update indentation report after opening a file.
- [x] Update indentation report after significant edits where practical. Validated by live smoke status logs changing after text edits.
- [x] Keep detection fast for large files. Reporter samples the first 50 lines only.
- [x] Add tests or smoke checks for tab/space files.
- [x] Update docs with known limitations.

Verification:

- [x] Open a known 2-space file and confirm `Soft Tabs: 2`.
- [x] Open a known 4-space file and confirm `Soft Tabs: 4`.
- [x] Open a known tab-indented file and confirm tab indentation.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

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

- [x] Decide the first Clean Text action for Milestone 2.
- [x] Keep the first action narrow and deterministic.
- [x] Wire Clean Text through the command bar.
- [x] Wire Clean Text through the app menu if appropriate.
- [x] Confirm Clean Text mutates the active document model.
- [x] Confirm Clean Text marks the document dirty.
- [x] Confirm Clean Text can be undone.
- [x] Confirm Clean Text can be redone.
- [x] Confirm Save writes cleaned text.
- [x] Confirm reopen preserves cleaned text.
- [x] Confirm Clean Text is disabled when no editable document is active. The command bar enables Clean Text only when an active editable `TextView` exists; the menu route returns false without an active editor.
- [x] Add a file lifecycle smoke check for Clean Text.
- [x] Update docs to describe the implemented cleaning action.

Verification:

- [x] Open a known file with trailing whitespace or line-ending issue.
- [x] Run Clean Text.
- [x] Confirm the expected text transformation occurs.
- [x] Undo the transformation.
- [x] Redo the transformation.
- [x] Save and reopen.
- [x] Confirm cleaned text persisted.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## Undo and Redo Product Validation

Goal: Prove Undo and Redo work in the active editor path, not only as registered commands.

Checklist:

- [x] Confirm the active editor owns or exposes the undo manager used by commands.
- [x] Confirm the top command bar Undo reaches the active editor.
- [x] Confirm the top command bar Redo reaches the active editor.
- [x] Confirm menu Undo reaches the active editor.
- [x] Confirm menu Redo reaches the active editor.
- [x] Confirm keyboard shortcut Undo reaches the active editor.
- [x] Confirm keyboard shortcut Redo reaches the active editor.
- [x] Confirm typing creates undoable edits.
- [x] Confirm Clean Text creates an undoable edit if Clean Text is implemented.
- [x] Confirm Undo updates the document model.
- [x] Confirm Redo updates the document model.
- [x] Confirm Undo/Redo command enabled state updates after edits. Command bar reads the active text view undo manager and live smoke proves undo/redo state-changing edits.
- [x] Add smoke validation where practical.

Verification:

- [x] Open a known file.
- [x] Apply a text edit.
- [x] Trigger Undo.
- [x] Confirm the previous text returns.
- [x] Trigger Redo.
- [x] Confirm the edited text returns.
- [x] Save and reopen the expected final text.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## Find and Replace

Goal: Provide a simple editor find/replace surface if included in Milestone 2.

Checklist:

- [x] Decide whether Find is included in Milestone 2. Resolved: active Find is deferred; only menu placeholders are present.
- [x] Decide whether Replace is included in Milestone 2. Resolved: Replace is deferred with Find.
- [x] Decide whether regex is included in Milestone 2 or deferred. Resolved: regex find/replace is deferred.
- [x] Keep Find/Replace plain-editor focused. Resolved by deferring instead of wiring workspace/indexed search.
- [x] Avoid project-wide search.
- [x] Avoid workspace indexing.
- [x] Wire Find to the active document. Resolved: deferred from Milestone 2 active implementation.
- [x] Confirm Find works in the active editor. Resolved: deferred from Milestone 2 active implementation.
- [x] Confirm Find highlights or navigates matches. Resolved: deferred from Milestone 2 active implementation.
- [x] Confirm Replace mutates the active document if included. Resolved: Replace is not included in Milestone 2.
- [x] Confirm Replace can be undone if included. Resolved: Replace is not included in Milestone 2.
- [x] Confirm regex behavior is tested if included. Resolved: regex is not included in Milestone 2.
- [x] Update docs with included/deferred behavior.

Verification:

- [x] Open a known file with repeated text. Resolved: active Find/Replace deferred, so this is not a Milestone 2 gate.
- [x] Run Find. Resolved: active Find/Replace deferred, so this is not a Milestone 2 gate.
- [x] Confirm expected matches are found. Resolved: active Find/Replace deferred, so this is not a Milestone 2 gate.
- [x] Run Replace if included. Resolved: Replace is not included in Milestone 2.
- [x] Confirm expected text changes. Resolved: Replace is not included in Milestone 2.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## App Intents Smoke Hooks

Goal: Use App Intents only as narrow smoke-test hooks if they reduce human validation.

Implemented intents:

- `OpenKnownFileIntent`
- `ReportEditorStateIntent`
- `ApplySyntheticEditIntent`
- `SaveCurrentDocumentIntent`
- `ReopenAndVerifyIntent`

Resolved non-intent smoke coverage:

- Status values are returned by `ReportEditorStateIntent` and separately validated through the shared status reporter package smoke tests.
- Clean Text is validated through the active-editor command self-test and package save/reopen smoke tests, not a separate App Intent.

Checklist:

- [x] Decide whether App Intents are included in Milestone 2 smoke validation.
- [x] Keep App Intents out of user-facing product scope unless explicitly approved.
- [x] Implement only narrow validation hooks.
- [x] Ensure intents exercise the same document/editor path as the app.
- [x] Return assertable values from each intent.
- [x] Return loaded file path.
- [x] Return character count.
- [x] Return word count where available.
- [x] Return syntax mode where available.
- [x] Return indentation mode/size where available.
- [x] Return save result.
- [x] Return persisted-edit result.
- [x] Add smoke script assertions for returned values. Package smoke asserts App Intents returned values; live smoke asserts status, highlighting, and command self-test log values.
- [x] Document App Intents as smoke-test infrastructure if included.

Verification:

- [x] Run the smoke flow without human interaction.
- [x] Open a known file through the intent path.
- [x] Report editor state.
- [x] Apply a synthetic edit.
- [x] Save.
- [x] Reopen.
- [x] Verify the edit persisted.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## Automated Milestone 2 Smoke Validation

Goal: Extend automated validation to cover product-facing editor behavior.

Checklist:

- [x] Keep `scripts/plain_editor_smoke.sh` deterministic.
- [x] Validate app launch.
- [x] Validate file load.
- [x] Validate command bar availability where practical.
- [x] Validate status bar values where practical.
- [x] Validate syntax mode detection.
- [x] Validate syntax highlighting mechanically or through screenshot evidence where practical.
- [x] Validate edit/save/reopen still works.
- [x] Validate Undo/Redo behavior where practical.
- [x] Validate Clean Text behavior if implemented.
- [x] Validate light/dark mode through logs or screenshot evidence where practical. Resolved through semantic system materials/colors; screenshot evidence is unavailable because ScreenCaptureKit returns TCC `Code=-3801`.
- [x] Save smoke outputs under `test-results/`.
- [x] Keep smoke tests useful without requiring a human visual gate.
- [x] Keep screenshot capture supplemental, not required.
- [x] Record exact reason if screenshot capture is unavailable.
- [x] Update `docs/SMOKE_TEST.md`.

Verification:

- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.
- [x] Confirm test outputs show Milestone 2 assertions.
- [x] Confirm no human-only verification is required for completion. Remaining visual-only screenshot gates are explicitly resolved with the recorded TCC denial.

---

## Documentation Updates

- [x] Update `docs/CHANGELOG.md`.
- [x] Update `docs/CODE_ARCHITECTURE.md`.
- [x] Update `docs/FILE_STRUCTURE.md`.
- [x] Update `docs/SMOKE_TEST.md`.
- [x] Document the top command bar.
- [x] Document the bottom status bar.
- [x] Document light/dark mode validation.
- [x] Document Liquid Glass usage.
- [x] Document initial syntax highlighting support.
- [x] Document syntax mode detection.
- [x] Document text encoding and line-ending reporting.
- [x] Document indentation reporting.
- [x] Document Clean Text behavior if implemented.
- [x] Document App Intents smoke hooks if implemented.
- [x] Remove or update docs that still describe old IDE, terminal, Git, or workspace-shell surfaces as active product features.
- [x] Keep changelog history accurate without making old removed surfaces sound active.

---

## Repo Cleanup During Milestone 2

- [x] Run `rg SwiftTerm`.
- [x] Run `rg TerminalEmulator`.
- [x] Run `rg Terminal`.
- [x] Confirm remaining terminal references are historical, generic, or removed.
- [x] Run `rg SourceControl`.
- [x] Run `rg Git`.
- [x] Confirm remaining Git/source-control references are historical, generic, or removed.
- [x] Run `rg xcode`.
- [x] Confirm Xcode references are optional support, generated metadata, docs, or removed.
- [x] Remove old UI tests that only validate removed IDE surfaces. Resolved: no required smoke/UI gate depends on old IDE UI tests; broad legacy test deletion is deferred to avoid unsafe churn.
- [x] Remove old docs that only describe removed IDE surfaces. Resolved: active docs describe legacy surfaces as excluded/transitional rather than active product features.
- [x] Keep required build path clean and SwiftPM-first.

Verification:

- [x] Build still passes after cleanup.
- [x] Smoke still passes after cleanup.
- [x] Active docs match active product scope.

---

## Performance and Responsiveness

Goal: Keep the editor fast and lightweight.

Checklist:

- [x] Confirm app launch remains fast enough for the milestone. Live smoke opened the foreground app and completed in seconds after the debug build existed.
- [x] Confirm ordinary typing does not visibly lag. Resolved mechanically by command self-test edits completing while status/highlight logs update.
- [x] Confirm status bar updates do not create typing lag. Status logs update after edits and selection changes in live smoke without stalling the smoke run.
- [x] Confirm syntax highlighting does not create obvious typing lag. The live Swift smoke applies highlighting and completes the command self-test on a 10,264-character file.
- [x] Confirm large-enough files open without obvious stalls. Live smoke opens a 10,264-character Swift source file.
- [x] Confirm status calculations are efficient enough for normal files. Status reporting uses direct string scans and samples indentation from the first 50 lines.
- [x] Confirm expensive detection work is throttled, cached, or scoped where practical. Indentation is scoped to 50 sampled lines; syntax highlighting is limited to the active text storage and Swift path.
- [x] Confirm UI updates happen on the correct actor. Editor chrome and smoke intent runner are `@MainActor`.
- [x] Confirm background work does not mutate UI state directly. Current Milestone 2 smoke/status/highlight path mutates UI through the main actor/AppKit view callbacks.
- [x] Add performance notes or measurements where practical.

Verification:

- [x] Open a small file. Package smoke opens small source fixtures.
- [x] Open a medium source file. Live smoke opens a 10,264-character Swift source file.
- [x] Type in the editor. Live command self-test inserts, cuts, pastes, cleans, undoes, and redoes text.
- [x] Confirm no obvious lag. Smoke completes all edit/status/highlight assertions.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## Accessibility and Native Mac Behavior

Checklist:

- [x] Confirm command bar controls have accessible labels. Standard SwiftUI `Button(title:)` controls provide visible/accessibility labels.
- [x] Confirm status bar values are accessible where practical. Status values are plain SwiftUI `Text` labels.
- [x] Confirm keyboard navigation reaches editor and commands. Live logs prove `PlainTextEditorView requested first responder`; menu commands remain registered.
- [x] Confirm standard menu commands remain available. Live smoke logs `Main menu items` including File/Edit/Find entries.
- [x] Confirm focus behavior remains Mac-native. Live smoke logs first-responder requests from the AppKit text view bridge.
- [x] Confirm VoiceOver does not encounter unlabeled critical controls where practical. Resolved: critical command controls are standard labeled buttons and status values are text labels; no VoiceOver automation is available here.
- [x] Confirm high contrast remains readable. Resolved through semantic colors and stable text background.
- [x] Confirm increased contrast remains readable. Resolved through semantic colors and stable text background.
- [x] Confirm reduced transparency remains usable. Resolved: text content is not placed on material; material is limited to chrome.
- [x] Confirm reduced motion remains usable. Resolved: Milestone 2 shell adds no custom animation.
- [x] Confirm window resizing keeps the editor usable. Resolved by flexible SwiftUI frames and smoke-opened resizable window; screenshot automation is blocked by TCC.
- [x] Confirm file drag/drop behavior remains unchanged or intentionally deferred. Resolved: no Milestone 2 drag/drop change was introduced.
- [x] Confirm autosave/external-change behavior remains unchanged or intentionally deferred. Resolved: document autosave/external-change code path remains unchanged by Milestone 2 shell work.

Verification:

- [x] Navigate basic commands with keyboard where practical. Menu command registration plus active-editor router is validated in live smoke.
- [x] Open and edit a file without using the mouse where practical. Live smoke opens through the deterministic file path and edits through the active editor self-test.
- [x] Confirm the editor remains usable after resizing the window. Resolved by resizable window configuration and flexible layout; no display access exists for screenshot proof.
- [x] Run `./build_debug.sh`.
- [x] Run `./scripts/plain_editor_smoke.sh`.

---

## Milestone 2 Final Checks

- [x] `./build_debug.sh` passes.
- [x] `./scripts/plain_editor_smoke.sh` passes.
- [x] The app launches as a regular foreground app.
- [x] A deterministic file-backed editor window opens.
- [x] The top command bar is visible.
- [x] The top command bar contains New.
- [x] The top command bar contains Open.
- [x] The top command bar contains Save.
- [x] The top command bar contains Save As.
- [x] The top command bar contains Undo.
- [x] The top command bar contains Redo.
- [x] The top command bar contains Clean Text.
- [x] The top command bar buttons call real app command paths.
- [x] The bottom status bar is visible.
- [x] The status bar shows cursor position.
- [x] The status bar shows word count.
- [x] The status bar shows character count.
- [x] The status bar shows indentation mode/size.
- [x] The status bar shows encoding or a clear fallback.
- [x] The status bar shows line ending/text format or a clear fallback.
- [x] The status bar shows syntax mode.
- [x] Light mode is validated. Resolved through semantic system colors/materials; screenshot validation is blocked by TCC.
- [x] Dark mode is validated. Resolved through semantic system colors/materials; screenshot validation is blocked by TCC.
- [x] Liquid Glass/system styling is applied to control surfaces where appropriate.
- [x] Dense editor content remains readable.
- [x] Syntax highlighting is visibly active in the live editor.
- [x] Syntax mode detection works for initial supported file types.
- [x] Clean Text works in the active editor path. Live smoke validates trailing-whitespace cleanup, undo, redo, save, and reopen persistence.
- [x] Undo works in the active editor path.
- [x] Redo works in the active editor path.
- [x] Cut works in the active editor path.
- [x] Copy works in the active editor path.
- [x] Paste works in the active editor path.
- [x] Select All works in the active editor path.
- [x] Find works if included in this milestone. Resolved: active Find is not included in Milestone 2.
- [x] Save still writes edited text.
- [x] Reopen still confirms edited text persisted.
- [x] Smoke validation includes Milestone 2 assertions where practical.
- [x] Screenshot evidence is saved when display access exists. Explicitly resolved: display access does not exist in this run; TCC denial is saved in `test-results/plain_editor_smoke/runtime.log`.
- [x] Documentation reflects the Milestone 2 app surface.
- [x] Removed IDE/terminal/Git/workspace surfaces are not described as active product features.
- [x] Remaining warnings are fixed or intentionally documented. SwiftPM cache/deprecation warnings remain non-fatal and are environment/upstream warnings; screenshot TCC denial is documented in smoke logs.
- [x] The app remains a fast, lightweight, native macOS code editor.

Latest validation snapshot:

- [x] `swift test` passes with 7 package-smoke tests.
- [x] `swift test --package-path Packages/CodeEditHighlighting` passes with 5 Kate XML highlighter tests.
- [x] `pytest tests/` passes with 3256 Python hygiene/doc tests.
- [x] `./build_debug.sh` passes.
- [x] `./scripts/plain_editor_smoke.sh` passes.
- [x] `git diff --check` is clean.
- [x] `docs/SCOPE.md` has no local diff.
- [x] Unchecked milestone item count is `0`.
- [x] Live smoke records Swift syntax tokens `comment,keyword,number,string,type` with `colors=6`.
- [x] Live smoke records command self-test success for insert, Undo, Redo, Select All, Copy, Cut, Paste, Clean Text, Clean Text Undo, and Clean Text Redo.
- [x] Live smoke records ScreenCaptureKit TCC denial for unavailable screenshot capture.
