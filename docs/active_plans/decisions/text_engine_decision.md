# Text engine decision (WP-S0b)

## Verdict

Outcome 2: Replaceable AppKit adapter (escape hatch). The measured evidence
shows the macOS 26 SwiftUI-native `TextEditor` bound to `AttributedString`
cannot yet deliver four specific user-facing editor behaviors reliably, so the
editor surface stays on the AppKit TextKit engine. That engine survives ONLY as
a narrow, isolated adapter around the editor surface with a documented swap
path, never as app architecture. The re-evaluation trigger is the next macOS
SDK.

The SwiftUI shell migration (WP-S1..S3: `App`, `DocumentGroup`, Commands) still
proceeds. Only the text-editing interior stays behind the adapter.

## Guiding principle

User decision, 2026-07-09: "SwiftUI-first, Swift-native, AppKit only as a
last-resort escape hatch, isolated behind a replaceable adapter." Less AppKit is
better is the north star. This spike weighs the two outcomes by measured
evidence, leaning SwiftUI wherever it is reliable:

- Outcome 1, SwiftUI-native editor surface: the measurements show
  `TextEditor`+`AttributedString` handles the code-editing workload reliably
  (gates pass with margin, cursor and scroll preserved). This is the preferred
  outcome when the evidence supports it.
- Outcome 2, Replaceable AppKit adapter (escape hatch): the measurements show
  specific behaviors SwiftUI cannot yet deliver reliably. The bridge survives
  only as a narrow, isolated, documented-swap-path adapter, with a
  re-evaluation trigger at the next macOS SDK.

The evidence below is reproducible reliability failures on named behaviors, so
this spike selects outcome 2.

## Behaviors that select outcome 2

Each item is a user-facing behavior the data demonstrates SwiftUI-native cannot
yet deliver reliably. Together they are the adapter's entire justification; the
adapter earns its place only for these, and only until the next SDK clears them.

1. Keystroke latency at size. Typing mid-document is about 140 ms p95 on a 14 KB
   file, roughly nine times the 16 ms budget, because each edit re-lays-out the
   whole value-type document through the SwiftUI-to-TextKit bridge.
2. Attribute-apply latency. Applying a full highlight color-run set is about 150
   to 270 ms, three to five times the 50 ms budget, and this cost lands on every
   async highlight pass.
3. Cursor and selection reset. Every programmatic attribute apply moves the
   caret from its mid-document position to the document end, on both a batched
   whole-document reassignment and a single in-place subrange edit. A code editor
   that yanks the caret to end-of-file on every highlight pass is unusable.
4. Large-document layout. Binding a ~1 MB document wedges the main thread in
   initial layout indefinitely; the editor never becomes interactive.

## What was measured

A throwaway SwiftUI SwiftPM app (macOS 26 target, Swift 6.3.3, macOS 26.5.2 on
MacBookPro18,3) mounts a single rich-text `TextEditor(text:selection:)` bound to
an `@Observable` model's `AttributedString` and `AttributedTextSelection`, in a
monospaced font. It loads two fixtures and drives four measurements per fixture
programmatically, printing greppable result lines and self-terminating.

- Small fixture: the repo smoke source `CodeFileDocument.swift`, copied in as a
  resource (13,919 characters).
- Large fixture: the small fixture tiled with comment banners up to ~1 MB
  (1,060,493 characters).

Prototype location (outside the repo tree): the session scratch directory
`textengine_spike/` SwiftPM package. Verification command: `swift run` in that
package launches the app headfully, prints the measurements below, and exits 0.

## Method per measurement

- p95 keystroke-to-render latency. Insert one character at the middle of the
  document by mutating the bound `AttributedString`, then time until the backing
  `NSTextView` (which SwiftUI commits `AttributedString` edits into, found by
  scanning the window view tree) reflects the longer string. That backing-store
  update is a concrete render-commit signal and also confirms the editor is
  mounted. Repeat 200 times on the small fixture; report p95 and mean in ms.
- Full span apply. Build a new `AttributedString` with one foreground-color run
  per roughly ten whitespace-delimited tokens (154 runs on the small fixture),
  walking a single moving index forward so the build is O(n), then assign it to
  the bound property in one batch. Time the pure build separately from the
  build-plus-assign-plus-commit total. This mirrors a real highlight pass, whose
  output is a full `[HighlightSpan]` set applied over the whole document.
- Cursor, selection, and scroll preservation. Set the insertion point to the
  document midpoint, apply the color runs, then read the selection's insertion
  offset back out and compare to the anchor; read the hosting `NSScrollView`
  content origin before and after. Both the batched whole-document reassignment
  and a single in-place subrange attribute edit are tested.
- Memory footprint. Read the process `phys_footprint` via `task_vm_info` (the
  same counter Xcode's memory gauge reports) after the fixture mounts.

The large fixture wedges the main thread during initial layout, so its metrics
are gathered differently: a background watchdog thread (which touches only the
process-wide mach memory counter, never main-thread-only UI API) polls a
main-queue-set flag. When the main thread does not drain its queue within 25 s
of binding the 1 MB document, the watchdog records the wedge, the footprint, and
the verdict, then exits the process.

## Measurements

Small fixture (13,919 characters), quoted verbatim from the `swift run` output:

```text
=== FIXTURE small (13919 chars) ===
MOUNTED small = true (backing store reflected full doc after 159.47 ms)
KEYSTROKE_P95_MS small = 140.56 (mean 133.34, n=200)
SPAN_APPLY small = 159.07 ms total, build 4.70 ms, runs 154
CURSOR_PRESERVED_BATCHED small = false (anchor offset 7059, after offset 14119)
CURSOR_PRESERVED_INPLACE small = false (anchor offset 7059, after offset 14119)
SCROLL_PRESERVED small = true (before (0.0, -32.0), after (0.0, -32.0))
FOOTPRINT small = 23.09 MB
```

Large fixture (1,060,493 characters, ~1 MB), quoted verbatim:

```text
NOTE large fixture bytes = 1060493, chars = 1060493
WATCHDOG large: 5s, main thread still wedged laying out 1 MB
WATCHDOG large: 10s, main thread still wedged laying out 1 MB
WATCHDOG large: 15s, main thread still wedged laying out 1 MB
WATCHDOG large: 20s, main thread still wedged laying out 1 MB
WATCHDOG large: 25s, main thread still wedged laying out 1 MB
=== FIXTURE large (1060493 chars, ~1 MB) ===
MOUNTED large = false (main thread wedged laying out 1 MB for > 25 s, never mounted)
KEYSTROKE_P95_MS large = n/a (editor never became interactive)
SPAN_APPLY large = n/a (editor never became interactive)
CURSOR_PRESERVED_BATCHED large = n/a
SCROLL_PRESERVED large = n/a
FOOTPRINT large = 102.89 MB (measured mid-wedge from the watchdog thread)
LARGE_VIABLE = false
```

Gate lines, judged on the small fixture per WP-S0b, quoted verbatim:

```text
GATE keystroke_p95 < 16.00 ms : FAIL (140.56 ms)
GATE span_apply < 50.00 ms : FAIL (159.07 ms)
GATE cursor_preserved : FAIL
GATE scroll_preserved : PASS
VERDICT FAIL
```

Only one of the four gates passes; a single narrow pass (scroll preserved) does
not clear the SwiftUI-native bar, which requires a decisive pass with margin on
all gates and no state-preservation red flags.

## Reading the results

- Keystroke latency is roughly 140 ms p95 on a 14 KB file, about nine times the
  16 ms budget. Because `AttributedString` is a value type, each mid-document
  edit copies and re-lays-out the whole document through the SwiftUI-to-TextKit
  bridge; the cost scales with document size rather than edit size. Across five
  runs the p95 stayed in a tight 138 to 148 ms band, so this is a fixed
  per-keystroke cost, not measurement noise.
- Full span apply is roughly 150 to 270 ms, three to five times the 50 ms
  budget. The build itself is cheap (about 3 to 5 ms); the cost is SwiftUI
  committing the reassigned `AttributedString` to the backing store. A real
  editor runs this after every async highlight pass, so this cost lands on every
  highlight.
- Cursor preservation fails decisively and is the hardest blocker. After both a
  batched whole-document reassignment and a single in-place subrange attribute
  edit, the insertion point moves from the mid-document anchor (offset 7059) to
  the document end (offset 14119). Selection indices are tied to a specific
  `AttributedString` value, so any programmatic attribute write collapses the
  selection to the end. The only selection-safe alternative, mutating color one
  run at a time in place, is O(n) per run and O(n squared) across a full
  document, which is itself non-viable at scale.
- The ~1 MB document never mounts. Binding it wedges the main thread in initial
  layout for longer than the 25 s observation window (an earlier run left it
  wedged past 160 s), with no interactive editor and about 103 MB of process
  memory mid-layout. The TextKit engine lays text out incrementally and opens
  large files immediately, which is exactly the workload this app targets.

## Consequences

- The editor surface keeps the AppKit TextKit engine, wrapped as a narrow,
  isolated adapter (`PlainTextEditorView` over `CodeEditTextView.TextView`).
  This adapter is an escape hatch around the editor surface only, not app
  architecture: the app shell, documents, and commands are SwiftUI.
- The adapter carries a documented swap path so the editor surface can move to
  SwiftUI-native when the evidence supports it. Keep the boundary small enough
  that swapping the interior does not touch the shell.
- The highlight pipeline continues to apply `[HighlightSpan]` foreground-color
  runs to the AppKit text storage, which preserves cursor, selection, and scroll
  and lays out incrementally.
- Re-evaluation trigger: the next macOS SDK. Re-run this spike's prototype
  against the new SDK. If all four gates pass with margin and cursor, selection,
  and scroll are preserved across a programmatic attribute apply, adopt outcome
  1 and retire the adapter.
