# Code architecture

## Architecture boundary

SwiftUI-first, Swift-native, AppKit only as a last-resort escape hatch: SwiftUI owns app
lifecycle, document scenes, the Commands menu, chrome, settings, and panels. AppKit is used only
when a specific user-facing behavior cannot be achieved reliably in SwiftUI or pure Swift
(IME/text-input edge cases, native undo integration, accessibility gaps, responder-chain
behavior), and every such use is isolated behind a replaceable adapter. AppKit must never be the
app architecture; `NSDocument`, hand-built `NSMenu`, `NSWindowController`, and delegate-chain
patterns outside the isolated editor-surface adapter are defects once the SwiftUI migration
lands. See [HUMAN_GUIDANCE.md](HUMAN_GUIDANCE.md) for the decision record.

## Overview

This repo is being cut over to a lightweight macOS text editor, not a full IDE. The required path is the plain editor shell, file-backed editing, saving/reopening, command and status bars, Clean Text, syntax highlighting, and data-driven syntax definitions.

SwiftUI owns the app shell. AppKit and TextKit own the editor surface through a narrow bridge in `PlainTextEditorView` and `CodeEditTextView`.

## Major components

- [SwiftlyCodeEditApp.swift](../CodeEdit/App/SwiftlyCodeEditApp.swift): the single SwiftUI `App` `@main` entry point (Settings scene plus File commands). Document windows are hosted through `NSDocumentController` under this plain `App` scene, not `DocumentGroup`.
- [CodeFileDocumentBridge.swift](../CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocumentBridge.swift): the single sanctioned document-layer AppKit boundary -- the launch-path app delegate, `NSDocumentController` document actions, and the `NSWindowController`+`NSHostingController` window hosting that `CodeFileDocument.makeWindowControllers()` delegates into.
- [CodeEditApp.swift](../CodeEdit/CodeEditApp.swift): WP-S4 deleted the hand-built AppKit shell (`PlainEditorAppDelegate`, `PlainEditorMainMenu`, `PlainEditorActionRouter`) this file used to hold; only the `CodeEditMain` enum remains, and only for its `launchStartNanoseconds`/`logLaunchToWindowIfNeeded` statics, which still back the `LAUNCH_TO_WINDOW_MS` marker read by the document bridge.
- [CodeFileView.swift](../CodeEdit/Features/Editor/Views/CodeFileView.swift): document-to-editor bridge used by the plain editor surface.
- [PlainTextEditorView.swift](../CodeEdit/Features/Editor/Views/PlainTextEditorView.swift): AppKit/TextKit wrapper around `CodeEditTextView.TextView`.
- `CodeEdit/Features/Editor/PlainEditorTextCleaner.swift`: deterministic text-cleaning helpers used by the Clean Text command.
- `CodeEdit/Features/Editor/PlainEditorStatusReporter.swift`: shared status-label logic for cursor, words, indentation, encoding, line endings, and language labels.
- [CodeFileDocument.swift](../CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift): document model for open, edit, autosave, and external-change handling.
- `CodeEditHighlighting`: shared highlighting model and Kate XML interpreter.
- `CodeEditTextView`: local text-view package that provides the editable text surface.
- `CodeEditLanguages`: language metadata used for syntax selection.
- `CodeEditSyntaxDefinitions`: syntax definition data files and the display-free syntax-highlight
  pipeline (see below).
- `DefaultThemes`: theme data files.

`Packages/CodeEditSourceEditor` was never a build dependency in
[Package.swift](../Package.swift); it was retained on disk only as the harvest source for WP-F1
(porting find-panel behavior into `CodeEdit/Features/Find/`) and was deleted once that port
landed (WP-F1 patch 19).

## Syntax-highlight pipeline

`CodeEditSyntaxDefinitions` exposes the highlight pipeline as separately callable, display-free
stages ("ammeter" seams: each stage can be timed in isolation, like a meter clamped onto a
circuit). `CodeEditSyntaxDefinitions.highlightSpans(text:language:)` composes all three for the
common case; each stage is also public on its own:

- Parse: Kate XML text -> `SyntaxDefinition` (`parseDefinition(kateXML:)` for an uncached, single
  parse; `definition(forLanguage:)` for the cached lookup used in production, via
  `SyntaxDefinitionRepository`).
- Interpret: text + `SyntaxDefinition` -> `[TokenRun]` (`tokenRuns(text:definition:)`), walking the
  Kate context/rule state machine and emitting UTF-16 `location`/`length` offsets directly (no
  `String.Index` work in this stage).
- Span-map: `[TokenRun]` -> `[HighlightSpan]` (`spans(from:in:)`), resolving each token run's
  UTF-16 range to a `String.Index` range once and carrying the UTF-16 `nsRange` forward on the
  span so later consumers never reconvert.

Attribute application (`[HighlightSpan]` -> `NSTextStorage` attributes) is the one display-side
stage, and it lives in the app's `PlainSyntaxHighlighter`, outside this package.

Two process-wide caches keep repeated passes cheap: a `FirstCharFilter` prefilter skips a rule's
regex whenever the current UTF-16 code unit is provably not a character the rule's pattern can
start with, and `CompiledRegexCache` shares compiled `NSRegularExpression` instances across every
open document and pass instead of recompiling per interpreter run.

Each stage is independently timeable via the headless benchmark
(`scripts/highlight_benchmark.sh`), which prints per-stage `HIGHLIGHT_BENCH_STAGES` timings
(`parseMs`/`interpretMs`/`spanMapMs`) alongside the overall `HIGHLIGHT_BENCH` totals line and
writes both to the `test-results/perf/highlight_cold_pass.txt` artifact.

### Dirty-range contract and bounded rehighlight

Per-keystroke highlighting is bounded to a region, not the whole document (WP-Q6). The document
model (`CodeFileDocument`) owns change tracking and broadcasts a typed edited-range payload,
`EditedTextChange`, on every text mutation:

- `.range(replacedRange:newLength:)` for a bounded edit (typing, paste, undo, redo, find-replace,
  and Clean Text, which replaces the whole buffer in one call and so arrives as a whole-buffer
  range edit, not `.fullInvalidation`).
- `.fullInvalidation` for an external reload, where the document's read path replaces the buffer
  via `setString` and reinterprets the whole document itself.

`CodeFileView` subscribes with `addEditObserver` and routes each `.range` edit to
`PlainSyntaxHighlighter.rehighlight(...)`. This edited-range broadcast is the single highlight
driver for edits; `onTextChange` no longer schedules a highlight, so exactly one bounded pass runs
per edit (the former double-highlight is removed). `PlainSyntaxHighlighter.rehighlight` reinterprets
only a region around the edit (the edited line plus a fixed context window), extracts just that
region's substring (so `storage.string` is never copied in full on a keystroke), and paints
foreground colors over just that region; NSTextStorage shifts the attributes outside the region to
follow the edit. A whole-buffer range edit (Clean Text) is detected as a whole-document region and
delegates to the full path. On cold open, a large document paints its viewport region first, then
interprets the whole document in the background under the same per-storage generation counter, so a
newer edit supersedes the pair and a superseded task is cancelled rather than left running.

Because the Kate interpreter is stateful (its context stack depends on all preceding text), a
bounded region that begins inside a long multi-line string or comment can mis-color its head; the
context window is a pragmatic mitigation, and a total collapse is caught by the hue-family gate.
Small documents (below the bounded threshold) always take the well-tested full-document path.

## Required build path

The plain-editor build should compile the app shell, editor view chain, settings, welcome/about surfaces, and shared UI helpers needed by the editor.

Required path:

- App shell and scene setup.
- Plain file-backed window shell for the editor.
- Plain editor view bridge.
- Document model, autosave, and external file-change reload.
- Top toolbar and bottom status bar.
- Clean Text trailing space/tab trimming.
- Context-preserving Kate XML syntax highlighting for Swift.
- Syntax mode and text-format reporting.
- Deterministic live smoke and App Intents package smoke validation.
- Smoke output saved under `test-results/plain_editor_smoke/`.
- Data bundles for themes and syntax definitions.

## Outside this milestone

These surfaces remain legacy or optional during the cutover:

- Source control.
- Find/replace beyond the standard menu placeholder.
- LSP and semantic-token plumbing.
- Navigator UI.
- Inspector UI.
- Activity/task/notification chrome tied to the old IDE shell.
- Terminal and utility panes not required for the plain editor path.
- Old `SourceEditor`-style editor surfaces that duplicate the plain text editor path.

## Ownership split

- SwiftUI owns app structure, windows, commands, and standard controls.
- AppKit owns the text view bridge and other narrow platform behaviors.
- TextKit owns the actual editor editing mechanics through `CodeEditTextView`.
- Data files own syntax definitions and themes so new content can be added without rebuilding app logic.
- App Intents in this repo are smoke-test hooks only, not a user-facing automation product surface.

## Undo manager ownership

Each `CodeEditTextView.TextView` owns a single `CEUndoManager` (its `_undoManager`);
that text view's undo manager is the one undo owner for the document. The pre-migration
answer was "ad hoc, wired in `PlainEditorActionRouter`"; after the SwiftUI migration the
undo manager belongs to the text view the adapter (`PlainTextEditorView`) hosts, and
`EditorCommandRouter`/the toolbar route Undo and Redo through that same
`TextView.undoManager`. No SwiftUI `\.environment(\.undoManager)` is set, so no second
competing stack exists. On an external-change reload the document mutates the shared
`NSTextStorage` in place (preserving object identity) and broadcasts `.fullInvalidation`;
`CodeFileView`'s reload observer -- the editor layer that holds the undo manager -- clears
that now-stale stack (`clearStack()`) so a post-reload Undo is a clean no-op rather than a
replay against mismatched offsets. The document never touches the undo manager directly.

## Product shell styling

The shell keeps Liquid Glass/system styling on control chrome only. The top
toolbar is a native macOS 26 `.unified` Liquid Glass toolbar (see the M9
toolbar architecture section below); the bottom status bar uses a tinted
`.glassEffect`, with a reduce-transparency opaque fallback for accessibility.
The editor content remains on `NSColor.textBackgroundColor` so dense code
stays readable in light, dark, high contrast, and reduced-transparency
contexts.

## M9 native toolbar architecture

The top chrome is a SwiftUI `.toolbar` declared on the hosted content
(`editorToolbar()` in `CodeFileView.swift`) and bridged into the host
`NSWindow`'s native `NSToolbar` by setting
`hostingController.sceneBridgingOptions = [.toolbars, .title]` in the
sanctioned document bridge (`CodeFileDocumentBridge.swift`). This is the
supported "SwiftUI content in an AppKit-hosted window" path: toolbar item
code stays pure SwiftUI, and the AppKit change is the single
`sceneBridgingOptions` line.

`window.toolbarStyle = .unified` keeps the toolbar to a narrow integrated
band rather than the system default's taller expanded style. Each item uses
a custom `ToolbarButtonLabel` -- an `HStack` that lays the icon and text out
side by side -- because the system's default `Label` stacks the text below
the icon, producing a taller row than the single-row layout this shell
wants. Items are grouped under `ToolbarItemGroup(placement: .navigation)` (4
groups, 7 items: New/Open, Save/Save As, Undo/Redo, Clean Text) so the row
docks at the leading edge, right after the traffic lights, instead of the
system default's trailing float.

The status bar's accent tint is fed by `window.backgroundColor`, set once at
window-creation time to a gentle accent blend
(`NSColor.controlAccentColor.blended(withFraction:of:)` against
`.windowBackgroundColor`) in `CodeFileWindowBridge.installWindowController`;
`PlainEditorStatusBar`'s `.glassEffect(.regular.tint(...))` samples that
backdrop to produce its visible color pop.

The bridged toolbar cannot take a custom color tint: it is window-server
chrome outside the SwiftUI paintable region, so it cannot sample color
composited by the hosted SwiftUI content or by `NSWindow.backgroundColor`
the way the status bar's glass does. The toolbar therefore ships with OS
Liquid Glass only. See
[docs/active_plans/decisions/native_toolbar_decision.md](active_plans/decisions/native_toolbar_decision.md)
for the full decision record.

## Known gaps

- The target still contains legacy folders that are being removed from the required build path.
- Some old feature trees remain in the repo for reference while the plain-editor cutover finishes.
- Light/dark visual validation uses semantic system materials and colors. Screenshot evidence still depends on display access; current smoke logs record ScreenCaptureKit TCC denial when capture is unavailable.
- Find and Replace are menu placeholders only in Milestone 2. Active in-editor find/replace and regex behavior are deferred.
- Ambiguous BOM-less non-UTF files may not be reliably distinguished by Foundation's current decoding path; the editor keeps the fallback non-blocking.
