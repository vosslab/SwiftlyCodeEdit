# Native toolbar decision

Architect decision for converting the editor's top chrome from the custom
`PlainEditorCommandBar` ribbon to a native macOS 26 Liquid Glass toolbar.
Read-only design record; no production code changed by this doc.

Status: decided (architect, 2026-07-10). Reversible by the user at review time.

## Question

The user chose "refactor the top chrome to a native toolbar" over keeping the
custom ribbon. The top chrome today is `PlainEditorCommandBar` in
`CodeEdit/Features/Editor/Views/CodeFileView.swift`: a flat full-width `HStack`
of borderless text buttons (New / Open / Save / Save As, Undo / Redo, Clean
Text, and transient font controls A- / A+ / Reset plus a "13 pt" indicator)
carrying `.glassEffect(in: Rectangle())`. That draws glass but is not the
macOS 26 grouped-capsule toolbar. This touches the AppKit-quarantine boundary,
so the approach needs an architect decision before an implementer starts.

## Grounding

- App shell: `CodeEdit/App/SwiftlyCodeEditApp.swift` is the single `@main`
  SwiftUI `App`. It declares a `Settings` scene and attaches `EditorCommands()`
  as `Commands`. There is no `WindowGroup` or `DocumentGroup`. Document windows
  are hosted by AppKit.
- Window hosting: `CodeFileWindowBridge.installWindowController(for:)` in
  `CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocumentBridge.swift`
  builds a plain `NSWindow` (styleMask `.titled`, `.closable`,
  `.miniaturizable`, `.resizable`, `.fullSizeContentView`), sets
  `window.contentViewController = NSHostingController(rootView:
  WindowCodeFileView(codeFile: document))`, and shows it through
  `NSDocumentController`. This bridge file is the sanctioned document-layer
  AppKit boundary (allowlist item (c), architect decision 2026-07-09).
- Hosted SwiftUI tree: `WindowCodeFileView` -> `CodeFileView`, whose `body` is a
  `VStack` of ribbon, optional find bar, editor, and status bar.
- Actions already have a shared, AppKit-free routing layer:
  - Document actions (New / Open / Save / Save As / Close) call
    `ShellDocumentActions` (plain-Swift helpers in the bridge).
  - Editor actions (Undo / Redo, Cut / Copy / Paste / Select All, the Clean
    Text set) call `EditorCommandRouter` (an `@Observable @MainActor` router in
    `CodeEdit/App/Commands/EditorCommandRouter.swift`).
  - The SwiftUI `Commands` menu (`CodeEdit/App/Commands/EditorCommands.swift`)
    already owns every keyboard shortcut and calls the same two routers.
- AppKit allowlist (plan Resolved decisions): AppKit symbols are permitted only
  in `PlainTextEditorView.swift`, `Packages/CodeEditTextView/**`, the sanctioned
  document bridge, and test code. The `WP-S4` grep gate validates against this
  allowlist.
- `docs/SWIFT_STYLE.md` section 1 (SwiftUI owns toolbars), section 3 (standard
  components pick up Liquid Glass automatically; prefer them over custom
  chrome), section 7 (narrow adapter boundary), section 14 (no dormant
  compatibility layers).
- `docs/LIQUID_GLASS.md` is the primary Liquid Glass reference and governs the
  toolbar-glass approach here: section 1 (use standard system components first;
  toolbars listed), section 2 (toolbars are the top glass surface; content stays
  legible), section 8 (SwiftUI owns glass styling; AppKit bridges do not split
  visual responsibility), and sections 10-12 (verify glass with on-screen
  evidence, avoid offscreen/cached capture paths, guarantee contrast). The
  implementer must read `docs/LIQUID_GLASS.md` in full, especially sections 1,
  2, 8, 10, 11, and 12, before building the toolbar and before capturing
  evidence.

## Decision 1: approach

Use a SwiftUI `.toolbar` declared on the hosted content, bridged to the host
`NSWindow`'s toolbar by setting `sceneBridgingOptions` on the existing
`NSHostingController` inside `CodeFileWindowBridge`. Item definitions live in
SwiftUI (`ToolbarItem` / `ToolbarItemGroup` in `CodeFileView`); the only AppKit
change is one line in the already-sanctioned bridge:

```swift
let hostingController = NSHostingController(rootView: WindowCodeFileView(codeFile: document))
hostingController.sceneBridgingOptions = [.toolbars, .title]
window.contentViewController = hostingController
```

`NSHostingController.sceneBridgingOptions` (macOS 14+, so available on the
macOS 26 target) makes a SwiftUI `.toolbar` inside the hosted view populate the
enclosing window's `NSToolbar`. On macOS 26 a standard toolbar renders the
grouped rounded-capsule Liquid Glass clusters automatically; `ToolbarItemGroup`
produces the capsule grouping. This is the correct native path given the
`NSDocumentController` hosting: the window is AppKit, but the toolbar content
stays SwiftUI, matching `docs/SWIFT_STYLE.md` sections 1 and 3.

Why this over a hand-built `NSToolbar` in the bridge: an `NSToolbar` path needs
`NSToolbarDelegate`, item identifiers, and `NSToolbarItemGroup` construction --
materially more AppKit, against "less AppKit is better", section 1's "SwiftUI
owns toolbars", and `docs/LIQUID_GLASS.md` sections 1 and 13 ("use standard
SwiftUI components first; treat AppKit as deprecated"). Both are native; the
SwiftUI-first path adds one AppKit line instead of a delegate. It stays inside
the allowlist because the one AppKit symbol touched (`sceneBridgingOptions`)
sits in the sanctioned bridge file; the `WP-S4` grep gate stays green.

Glass ownership (governs both the primary and fallback paths). The toolbar glass
comes from the OS applying Liquid Glass automatically to a STANDARD toolbar
(`docs/LIQUID_GLASS.md` sections 1 and 2: standard components adopt the material
automatically; toolbars are the top glass surface). Do NOT hand-apply
`.glassEffect` to the toolbar or its items, and do NOT own toolbar glass in the
AppKit bridge -- section 8 forbids splitting visual responsibility across the
SwiftUI and AppKit layers. In the SwiftUI path the standard `.toolbar` picks up
glass automatically; in the fallback path a STANDARD `NSToolbar` likewise picks
up OS glass automatically, so neither layer applies a custom glass effect to the
toolbar. This keeps the code editor (the content layer) calm and legible while
the control layer carries the glass, per sections 2, 3, and 4.

Bounded contingency (pre-approved, same allowlist): the bridged-toolbar API is
known to be finicky with manually built windows. If the implementer's build and
on-screen verification shows the bridged toolbar does not populate or does not
render glass (empty toolbar, items missing, no capsules), the pre-approved
fallback is a hand-built `NSToolbar` with `NSToolbarItemGroup` constructed in
`CodeFileWindowBridge` (same sanctioned file, same allowlist), still driving
`ShellDocumentActions` / `EditorCommandRouter`. The implementer reports which
path shipped; they do not need a fresh decision to take the fallback, but they
must record it in the changelog and the WP verification note.

## Decision 2: action and shortcut preservation

Every current action becomes a toolbar `Button` that calls the exact function
the ribbon calls today, so behavior is unchanged:

| Toolbar item | Calls | Enabled when |
| --- | --- | --- |
| New | `ShellDocumentActions.newDocument()` | always |
| Open | `ShellDocumentActions.openDocumentWithPanel()` | always |
| Save | `ShellDocumentActions.saveActiveDocument()` | `codeFile.isDocumentEdited` |
| Save As | `ShellDocumentActions.saveActiveDocumentAs()` | `codeFile.isDocumentEdited` |
| Undo | `EditorCommandRouter.shared.undo(on: activeTextView)` | `undoManager.canUndo` |
| Redo | `EditorCommandRouter.shared.redo(on: activeTextView)` | `undoManager.canRedo` |
| Clean Text | `EditorCommandRouter.shared.cleanText(on: activeTextView)` | `activeTextView.isEditable` |

The ribbon targets its own window's `activeTextView` directly (not key-window
resolution); the bridged toolbar is likewise per-window (one hosted tree per
window), so it keeps the same `on: activeTextView` targeting and the same
`canSave` / `canUndo` / `canRedo` / `canCleanText` bindings already computed in
`CodeFileView.body`.

Keyboard shortcuts are untouched. Shortcuts live on the SwiftUI `Commands` menu
(`EditorCommands.swift`), not on toolbar items; `EditorCommands.swift` is not
modified by this work. No shortcut moves to the toolbar, so there is no shortcut
a toolbar "cannot represent" -- toolbar items are pure click targets, and the
menu remains the single shortcut owner. Cmd+N/O/S/Shift+S/W, Cmd+Z/Shift+Z,
Cmd+X/C/V/A, Cmd+F, Cmd+Opt+F, and the Format menu's Cmd+=/-/0 all stay bound
exactly as today.

## Decision 3: transient font controls (A- / A+ / Reset + size indicator)

Recommendation: do not carry the A- / A+ / Reset text buttons or the "N pt"
indicator into the toolbar. They are already fully covered:

- The Format menu (`EditorCommands.swift`, WP-F6) has Increase Size (Cmd+=),
  Decrease Size (Cmd+-), and Reset Size (Cmd+0), calling the same
  `PlainEditorFontSettings` step functions the ribbon's A- / A+ buttons call.
- The Settings scene (WP-F5) owns font family and size as persisted
  preferences.

The plan's Resolved decisions kept A- / A+ / Reset only as "transient,
high-frequency shortcuts" in the ribbon, and explicitly allow removing ribbon
elements that distract from the "clean, simple editor" scope goal as a named
change. This toolbar refactor is that named change. Folding font-size access
into the already-shipped Format menu and Settings keeps the top chrome to the
document and edit actions and yields a cleaner grouped-capsule toolbar.

This is a recommendation the user can override. If at-a-glance font-size access
in the toolbar is wanted, the acceptable alternative is a single toolbar item
(one `Stepper` or a compact control), not the three text buttons plus a
separate indicator. That single control would be additive and can be a later
follow-up rather than part of this WP.

## Decision 4: bottom status bar

Keep the status bar unchanged. The uniform toolbar is the TOP bar only; the
status bar is separate bottom chrome and is not replaced by the toolbar. It
stays a SwiftUI bottom bar in `CodeFileView` and keeps its current
`.glassEffect(in: Rectangle())`. The plan's M9 / WS-9A already treated the
status bar as a glass control layer with captured light/dark/reduced-
transparency evidence, so overturning that here would discard evidenced work for
no reason. The status bar is out of scope for this toolbar WP; the implementer
does not touch it.

No glass-on-glass concern (`docs/LIQUID_GLASS.md` section 11): the toolbar is top
chrome and the status bar is bottom chrome, never stacked, so keeping the status
bar's SwiftUI-owned `.glassEffect` does not sit a glass surface over the toolbar
glass. Each samples the content layer between them independently.

## Decision 5: old ribbon removal

Remove `PlainEditorCommandBar` and its `.glassEffect(in: Rectangle())` once the
toolbar lands. It is not left dormant (`docs/SWIFT_STYLE.md` section 14). The
`VStack` in `CodeFileView.body` drops the `PlainEditorCommandBar` row; the find
bar row, editor, and status bar remain. The `canSave` / `canUndo` / `canRedo` /
`canCleanText` values that fed the ribbon now feed the toolbar items.

Two coupling points the implementer must handle in the removal patch:

- The DEBUG marker `debugRuntimeLog("Plain editor command ribbon ready")` in
  `CodeFileView.onAppear` and any smoke gate on that exact string
  (`scripts/plain_editor_smoke.sh`, `docs/SMOKE_TEST.md`) are updated to a
  toolbar-ready marker in the same patch, so the smoke script and the doc move
  together.
- `PlainEditorCommandSelfTest` drives `EditorCommandRouter` directly, not the
  ribbon view, so it stays valid unchanged and its all-true self-test line must
  still appear.

## Verdict on the AppKit boundary

The approach adds zero new AppKit files and one AppKit line
(`sceneBridgingOptions`) inside the already-sanctioned
`CodeFileDocumentBridge.swift`. Toolbar item code is pure SwiftUI in
`CodeFileView`. The `WP-S4` AppKit-allowlist grep gate stays green. This
reduces custom chrome (removes a hand-rolled glass `HStack`) in favor of a
standard system component, satisfying `docs/SWIFT_STYLE.md` sections 1, 3, 7,
and 14.

## Work breakdown

One work package, one `expert_coder`, two sequential patches. Sizing is small:
the routing layer and enabled-state bindings already exist; the work is
declaring toolbar items over them, one bridge line, and deleting the ribbon.

### Patch 1: native toolbar build and wiring

- Set `hostingController.sceneBridgingOptions = [.toolbars, .title]` in
  `CodeFileWindowBridge.installWindowController` (the one AppKit line).
- Add `.toolbar { ... }` to `CodeFileView` with `ToolbarItemGroup` clusters:
  New / Open, then Save / Save As, then Undo / Redo, then Clean Text -- each
  item a `Button` calling the mapped router function from Decision 2 with the
  listed enabled-state binding. Use SF Symbols where they read clearly; keep
  labels available for accessibility.
- Leave `PlainEditorCommandBar` in place for this patch so nothing regresses
  while the toolbar is proven.
- Acceptance: build zero-warning; `swift test` green (only the known
  lifecycle expected-fails); smoke markers preserved (`SHELL=SwiftUI`,
  `Main menu items:` with File/Edit/Find/Format items, the command self-test
  all-true line, `LAUNCH_TO_WINDOW_MS=`, status-bar markers); launch-time
  median stays under 1000 ms; every toolbar item invokes its action against the
  focused window's editor with the correct enabled state.

### Patch 2: ribbon removal and evidence

- Remove `PlainEditorCommandBar` and its `.glassEffect(in: Rectangle())` from
  `CodeFileView`; drop the ribbon row from the `VStack`.
- Rename/retire the `Plain editor command ribbon ready` marker to a
  toolbar-ready marker and update `scripts/plain_editor_smoke.sh` and
  `docs/SMOKE_TEST.md` in the same patch.
- Capture glass evidence of the NEW toolbar following the `docs/LIQUID_GLASS.md`
  section 10 evidence protocol, not a bare screenshot. Specifically:
  - Capture-path hazard: the DEBUG `-PlainEditor.captureWindowTo` window
    self-capture uses `cacheDisplay` / `bitmapImageRepForCachingDisplay`, which
    section 10 names as an offscreen/cached path that can render glass FLAT GRAY
    even when the live app is correct. Do not treat that self-capture as glass
    proof on its own. Prefer a real on-screen capture
    (`screencapture -l <window-id>`) of the live window. If the agent
    environment denies screen-recording (TCC) so only the cacheDisplay path is
    available, validate the path first (render one known-glass view and one flat
    control through it; if they look identical, the path is not compositing the
    live backdrop) and flag that the on-screen capture must be run by the human
    for a final glass verdict.
  - Backdrop: scroll multi-color syntax-highlighted code so it reaches under the
    toolbar's bottom edge; glass over plain white or an empty document is
    nearly invisible by design (section 10 matrix) and proves nothing.
  - Differential proof: capture once normally and once with Reduce Transparency
    on; the reduced capture must be visibly more opaque. Add a `.regularMaterial`
    control comparison; if the glass capture is indistinguishable from it, glass
    is not rendering.
  - Light and dark captures, each labeled with the effective appearance queried
    at capture time (section 10 step 6).
  - Contrast: any label rendered over glass must measure at least 4.5:1
    (3:1 for 18pt+), per sections 10 and 12.
  - Then `image_evaluator` assesses the captures. Record which toolbar path
    shipped (bridged SwiftUI vs the fallback `NSToolbar`).
- Acceptance: same build/test/smoke gate as Patch 1, plus the ribbon is gone
  (grep confirms `PlainEditorCommandBar` no longer defined) and the toolbar
  glass evidence is filed under `docs/active_plans/reports/`.

### Verification gate (both patches)

- `./build_debug.sh` from a clean `.build`: "Build complete!", zero new
  warnings.
- `swift test`: green with only the known lifecycle expected-fails.
- `./scripts/plain_editor_smoke.sh`: `SMOKE_EXIT=0` with the preserved markers
  above, including the command self-test all-true line and the Main-menu
  item checks.
- Glass evidence of the new toolbar (Patch 2) captured per the
  `docs/LIQUID_GLASS.md` section 10 protocol above (real on-screen capture
  preferred over the cacheDisplay self-capture; differential reduce-transparency
  and `.regularMaterial` control; multi-color code under the toolbar edge;
  light+dark labeled by queried appearance), assessed by `image_evaluator`.
- The implementer launches the built binary via a LITERAL absolute path,
  `/Users/vosslab/nsh/SwiftlyCodeEdit/.build/debug/SwiftlyCodeEdit ...`, never
  `$(...)` command substitution (the permissions hook rejects it).
- The implementer records the change in `docs/CHANGELOG.md` per `AGENTS.md`.

## Blockers

None. The `NSDocumentController` hosting does not make a native toolbar
infeasible: `sceneBridgingOptions` is the supported bridge for exactly this
"SwiftUI content in an AppKit-hosted window" shape, and the pre-approved
`NSToolbar` fallback stays inside the existing allowlist if the bridge proves
unreliable at verify time. No larger shell change is required.

## Amendment: item layout choices

Once the toolbar shipped, the implementer settled three further user-directed
layout choices that were only recorded as code comments rather than in this
decision record: `window.toolbarStyle = .unified` (`CodeFileDocumentBridge.swift`)
keeps the toolbar to a narrow integrated band instead of the system default's
taller expanded style; each item's icon and text lay out side by side via a
custom `ToolbarButtonLabel` `HStack` (`CodeFileView.swift`), because the
system's default `Label` stacks the text below the icon and produces a taller
row than this single-row layout wants; and the items dock at the leading
edge, right after the traffic lights, via
`ToolbarItemGroup(placement: .navigation)` rather than the system default's
trailing float. These three choices are captured here so the rationale is not
only discoverable from source comments.
