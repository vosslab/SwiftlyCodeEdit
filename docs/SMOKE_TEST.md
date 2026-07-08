# Plain Editor Smoke Test

Use this against a local debug build.

## Build

```bash
./build_debug.sh
```

## Live App Smoke

```bash
./scripts/plain_editor_smoke.sh
```

The smoke script launches the debug app against a temporary copy of
`CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift`.
It writes app and runtime logs under `test-results/plain_editor_smoke/`.

It asserts runtime log evidence for:

- deterministic file-backed launch
- editor window creation
- command ribbon and status bar creation
- Swift status mode, UTF-8 encoding, and LF line-ending reporting
- meaningful Swift syntax highlighting tokens and color count
- active-editor insert, Undo, Redo, Select All, Copy, Cut, and Paste
- Clean Text trailing space/tab trimming, plus Clean Text Undo and Redo
- optional screenshot capture when macOS screen-capture permission exists

The live smoke log is also the current validation source for light/dark and
Liquid Glass safety: the UI uses semantic AppKit/SwiftUI colors and materials,
keeps the editor content on the standard text background, and records the exact
TCC denial if screenshots cannot be captured.

## App Intents Smoke

The package smoke test also covers the narrow App Intents validation runner:

```bash
swift test --filter CodeFileDocumentLifecycleTests
```

The App Intents runner opens a known file, reports document state, applies a
synthetic edit, saves, reopens, and verifies the edit persisted. This is
smoke-test infrastructure, not a user-facing automation feature.
The reported state includes path, character count, word count, syntax mode,
indentation, encoding, and line-ending labels.

Known limitation: non-UTF encodings are reported when Foundation selects one of
the supported file encodings. Ambiguous BOM-less non-UTF files may still fall
back to readable UTF-8-oriented handling instead of blocking the editor.

The same package smoke suite verifies that Clean Text removes trailing spaces
and tabs from each line, saves the cleaned file, and reopens the cleaned text.
It also verifies CRLF/CR/LF labels, CRLF save/reopen preservation, known
encoding labels, and tab/space/unknown indentation labels.

## Deferred Surface

Find and Replace remain menu placeholders in Milestone 2. Active in-editor
Find, Replace, and regex behavior are deferred so the milestone can stay focused
on the lightweight plain-editor shell, status reporting, Clean Text, and Swift
syntax highlighting.

## Expected

- Source text is visible in the editor.
- The insertion point appears in the text view.
- Synthetic edits update the document.
- Clean Text removes trailing spaces and tabs from each line.
- Save writes edited text to disk.
- Reopen confirms edited text persisted.
- Open, Save, Close, Undo, Redo, Cut, Copy, Paste, Select All, and Find are present in the app menus.
