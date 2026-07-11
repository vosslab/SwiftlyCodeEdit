# Plain Editor Smoke Test

Use this against a local debug build.

## Build

```bash
./build_debug.sh
```

`build_debug.sh` launches the freshly built app with `--kill-after=5` to
confirm it starts, then lets it quit itself after 5 seconds; it does not leave
a stray instance running. Any `CodeEdit` launch (including a normal user
launch) accepts `--kill-after=N` to auto-quit N seconds after the launch path
finishes; without the flag, the app behaves normally and never auto-quits.

## Live App Smoke

```bash
./scripts/plain_editor_smoke.sh
```

The smoke script `rm -f`s its own stale artifacts (runtime log, prior smoke
source copy) before every run, so a pass always reflects that run's evidence,
not leftovers from an earlier one. The git-tracked screenshot file is left
alone entirely unless a capture attempt actually produces a non-empty file:
the helper writes to a `mktemp` scratch path first, and only a confirmed
non-empty capture is `mv`d over the tracked screenshot, so a `--no-screenshot`
run, a run without the screenshot helper, or a TCC-denied capture never
deletes or blanks the tracked file. It launches the debug
app against a temporary copy of
`CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift`, passing
`--kill-after=N` so the launched instance always quits itself rather than
lingering in the Dock, even if the script is interrupted before its own
cleanup `kill` runs. It writes app and runtime logs under
`test-results/plain_editor_smoke/`. After a run, `pgrep -x CodeEdit` returns
nothing. The script always reports its own final exit status to stderr as
`SMOKE_EXIT=<code>`, on both success and failure, so callers never need
redirection or a wrapper to learn the result.

### Hard gates

A failure in any of these fails the whole run:

- the `SHELL=SwiftUI` marker, proving the running shell is the SwiftUI `App`
  entry point (`SwiftlyCodeEditApp`), not the retired AppKit `CodeEditMain`
  enum
- deterministic file-backed launch
- editor window creation
- native toolbar and status bar creation
- Swift status mode, UTF-8 encoding, and LF line-ending reporting
- meaningful Swift syntax highlighting tokens and color count
- the full active-editor command self-test line: insert, Undo, Redo, Select
  All, Copy, Cut, Paste, Clean Text (plus its own Undo/Redo), and all four
  Clean Text sub-cleaners (line endings, final newline, tabs-to-spaces,
  spaces-to-tabs, and smart punctuation)
- the Settings live-apply markers (WP-F5): the `SETTINGS_APPLY_SELF_TEST`
  seam (enabled by `CODEEDIT_SETTINGS_APPLY_SELF_TEST=1`) performs a real
  post-mount font-size and theme change through the same `@AppStorage` path
  the Settings window uses, so `SETTINGS_APPLIED key=fontSize` and
  `SETTINGS_APPLIED key=theme` must both appear from their view-application
  sites (the font set on the text view, the theme colors applied), never from
  the storage write; the seam then restores the prior values and logs
  `SETTINGS_APPLY_SELF_TEST fontRestored=true themeRestored=true`, proving the
  live change reversed and left the user's stored preferences untouched
- the appearance/accessibility marker (WP-G1b): the app is launched with
  `-PlainEditor.forceReduceTransparency YES` and
  `-PlainEditor.forceIncreaseContrast YES` (NSArgumentDomain launch arguments,
  never `defaults write` against the real `com.apple.universalaccess`
  preferences), and the runtime log's `APPEARANCE_MODE=<light|dark>
  reduceTransparency=<0|1> increaseContrast=<0|1>` marker must appear reporting
  both forced flags as `1`; the mode half reflects the real system appearance
  and is not forced by this script
- the Commands-menu item inventory: the runtime log's `Main menu items:`
  line is parsed per top-level menu (File, Edit, Find, Format) and each
  first-party item below must be present in its own menu -- File (New,
  Open..., Save, Save As..., Close), Edit (Undo, Redo, Cut, Copy, Paste,
  Select All, Clean Text), Find (Find..., Find and Replace...), and Format
  (Font and Text Options). The check tolerates macOS's own menu injections
  (Writing Tools, AutoFill, Start Dictation, Emoji & Symbols, and blank
  separators in the Edit menu) since those vary by OS version and are not
  part of this app's Commands declaration; only a missing first-party item
  fails the run.

### Optional diagnostic: screenshot

Screenshot capture depends on machine-local tooling
(`~/nsh/easy-screenshot/run.sh`) and the macOS screen-recording TCC grant,
neither of which is a repo correctness concern. It never fails the run:

- Pass `--no-screenshot` to disable it outright; the run prints
  `SKIPPED: screenshot capture disabled by --no-screenshot`.
- If the helper script is missing, the run prints
  `SKIPPED: screenshot capture, missing helper <path>` and continues.
- If the helper runs but the screen-recording permission is denied (no file
  produced), the run prints
  `SKIPPED: screenshot capture, helper ran but produced no file (likely denied
  screen-recording permission)` and continues.
- Otherwise the screenshot is captured and its runtime log line is asserted
  like any other hard-gate marker.

A green run always states explicitly whether the screenshot was captured or
skipped, and why, so the pass reflects exactly what it proved. When captured,
the live smoke log is also the current validation source for light/dark and
Liquid Glass safety: the UI uses semantic AppKit/SwiftUI colors and materials
and keeps the editor content on the standard text background.

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

Supported decodings are UTF-8, UTF-16 BE, UTF-16 LE, Windows-1252, and ISO
Latin-1, so ordinary single-byte text files (for example Latin-1 or
Windows-1252) open as real text with their actual encoding shown in the status
bar. Encoding contract: an opened editor window always contains either real
decoded text or an explicit error alert, never a silent blank. A file whose
bytes match none of the supported decodings raises a decode error and opens
nothing; the status bar reports "Unknown" for that case rather than claiming
"UTF-8". The lifecycle suite covers the Latin-1, Windows-1252, and
undecodable-error paths.

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
