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
alone at start-of-run cleanup and is only removed immediately before a run
that will actually recapture it, so a `--no-screenshot` run or a run without
the screenshot helper never deletes the tracked file. It launches the debug
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

- deterministic file-backed launch
- editor window creation
- command ribbon and status bar creation
- Swift status mode, UTF-8 encoding, and LF line-ending reporting
- meaningful Swift syntax highlighting tokens and color count
- active-editor insert, Undo, Redo, Select All, Copy, Cut, and Paste
- Clean Text trailing space/tab trimming, plus Clean Text Undo and Redo

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
