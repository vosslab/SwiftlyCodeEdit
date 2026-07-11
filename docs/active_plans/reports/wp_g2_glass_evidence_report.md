# WP-G2 glass evidence report

Automated visual-acceptance evidence for the macOS 26 Liquid Glass chrome
(WS-9B / M9). Capture and assessment only; no source, test, smoke-script, or
changelog edits were made. Grounded in docs/LIQUID_GLASS.md (section 10 capture
hazards and expected-appearance matrix; sections 2/5/8 chrome glass; sections
7/9/12 accessibility) and the glass-expert skill evidence protocol.

## Verdict

- Toolbar glass: SHIP.
- Status bar glass: SHIP.

The native macOS 26 grouped-capsule Liquid Glass renders on the toolbar and the
custom `glassEffect` renders on the status bar. Both read as translucent glass
material (not flat opaque fills) and both keep the app's own text legible in
light and dark mode. The one caveat, documented in full below, is that the
backdrop-color-differential proof reads zero at both chrome bands because in
this window layout no colored content composites behind either band; liveness
therefore rests on the material's visual signature, not on a chromatic tint
delta.

## Capture environment

| Field | Value |
| --- | --- |
| OS | macOS 26.5.2 |
| Hardware | MacBookPro18,3 |
| Toolchain | Apple Swift 6.3.3 (swiftlang-6.3.3.1.3) |
| Build | ./build_debug.sh -> Build complete |
| App | .build/debug/SwiftlyCodeEdit (debug) |
| Editor font | 15pt, forced per-process via -PlainEditor.fontSize 15 (never persisted) |
| Capture path | live on-screen easy-screenshot run.sh (not offscreen render) |
| Image size | 1920 x 1200 px |

## Appearance-force proof (part B)

Each launch forced the per-process appearance with `-AppleInterfaceStyle`
(volatile NSArgumentDomain, never persisted; no `defaults write`). The runtime
marker at /tmp/codeedit_runtime.log confirmed the effective mode:

- Light launch marker line:
  `APPEARANCE_MODE=light reduceTransparency=0 increaseContrast=0`
- Dark launch marker line:
  `APPEARANCE_MODE=dark reduceTransparency=0 increaseContrast=0`

The forced style flips the marker as intended, so light and dark captures are
verified to have run in the mode claimed.

## Screenshots

All captures render the editor at 15pt so code wraps near 100 columns rather
than the earlier tight ~50-60 columns.

| File | Mode | Fixture | Purpose |
| --- | --- | --- | --- |
| docs/screenshots/glass_toolbar_light.png | light | varied tokens | part C light |
| docs/screenshots/glass_toolbar_dark.png | dark | varied tokens | part C dark |
| docs/screenshots/glass_backdrop_green_light.png | light | green comments | part D backdrop A |
| docs/screenshots/glass_backdrop_red_light.png | light | red strings | part D backdrop B |

All four are live on-screen captures of the window titled by the fixture
basename, showing the native toolbar capsule at top and the custom glass status
bar at bottom.

## Legibility and contrast read (part C)

Both part-C captures show green comments, blue keywords, cyan types, red
strings, magenta numbers, and orange function names over the editor body, with
the glass chrome above and below. WCAG contrast was sampled from the captures
(percentile text-vs-background tails; conservative because anti-aliased edge
pixels drag the text tail toward the background).

| Surface | Mode | Text RGB | Glass BG RGB | WCAG ratio | Note |
| --- | --- | --- | --- | --- | --- |
| Status bar (app text) | light | (112,112,112) | (252,252,252) | 4.83:1 | pass, normal text >= 4.5:1 |
| Status bar (app text) | dark | (163,164,163) | (26,27,26) | 6.91:1 | pass |
| Toolbar glyph (enabled) | light | (76,76,76) | (253,253,253) | 8.45:1 | pass |
| Toolbar glyph (enabled) | dark | light gray on (29,29,29) | -- | legible | system-rendered |

The status bar carries the app's own custom text and clears 4.5:1 in both
modes. The toolbar glyphs are standard system SF Symbols in a standard toolbar,
so their contrast is OS-managed; the enabled New/Open glyphs are clearly
legible in both modes and disabled glyphs are appropriately dimmed by the
system. Visual inspection of the zoomed dark toolbar confirms the enabled
glyphs are legible.

## Backdrop-color-differential result (part D)

The same window was captured twice in light mode with two backdrops whose top
rows highlight to different dominant hues: a comment-dominated fixture (green)
and a string-dominated fixture (red). Both fixtures pack their colored top rows
directly under the toolbar edge at 15pt. Mean RGB was measured over three
bands; `spread` is max-min channel gap (0 = neutral gray, large = chromatic
tint).

| Band | Green-backdrop mean | Red-backdrop mean | Euclidean delta | Reading |
| --- | --- | --- | --- | --- |
| Toolbar capsule (y 30-100) | (245.0,245.0,245.0) spread 0.0 | (245.0,245.0,245.0) spread 0.0 | 0.0 | pixel-identical, neutral |
| Status bar (y 1150-1195) | (239.1,239.1,239.1) spread 0.0 | (239.2,239.2,239.2) spread 0.0 | 0.1 | neutral, effectively identical |
| Content row 1 (y 100-150) | (241.9,249.2,242.0) spread 7.3 | (248.3,231.5,231.0) spread 17.3 | 21.8 | actual code text, not chrome |

Honest finding: the tint delta at both chrome bands is ~0 and hue-neutral
(spread 0.0). This is NOT evidence the glass is a flat opaque fill, and NOT a
missed live-compositing capture (the captures are real on-screen grabs, and the
content band directly proves live colored pixels were present: green vs red
diverge there). It is a layout property: in this window the colored editor
content does not composite behind either chrome band. The native toolbar sits
in the title-bar region with a neutral inset above the first content row, and
the status bar is a discrete bottom row in the VStack with the editor above it,
not behind it. Neither glass surface has colored content to sample, so the
backdrop-differential is inconclusive-by-layout here rather than a pass or a
fail.

Liveness is instead established by the material's visual signature (see part
below), which a flat opaque bar would not produce.

## Why the glass is live, not opaque

Per docs/LIQUID_GLASS.md section 10, over a plain near-white backdrop correct
Liquid Glass is "nearly invisible; faint edge highlight only" and over a dark
backdrop shows a "subtle rim light." The zoomed chrome crops match exactly:

- Light toolbar: a soft translucent rounded capsule around the button cluster
  with a faint luminous edge, lighter than and blended into the title bar
  (not a hard-edged solid rectangle).
- Dark toolbar: a subtle rounded panel slightly lighter than the dark title
  bar with a rim-light edge and light-gray glyphs.
- Status bar: a light translucent panel with a softened corner carrying the
  secondary-gray metrics text.

A flat opaque fill would render as a hard uniform rectangle with no edge
highlight and no light/dark rim adaptation; the captured chrome shows the
adaptive translucent material in both modes. The toolbar is the OS grouped
`ToolbarItemGroup` capsule, which adopts Liquid Glass automatically on the
macOS 26 SDK (section 1).

## Reduced transparency (part E, architecture note, not a capture)

Reduced transparency is intentionally not screenshot-gated. Two reasons:

- The toolbar uses standard system `ToolbarItemGroup` controls, which inherit
  the OS Reduce Transparency handling automatically (docs/LIQUID_GLASS.md
  section 1: standard framework components adopt the appearance and behavior).
  No app code is needed for the toolbar to fall back to an opaque treatment
  when the user enables Reduce Transparency.
- The app's debug appearance markers force only the reported accessibility
  flag in the volatile argument domain; they do not, and must not, change the
  real systemwide `com.apple.universalaccess` state. A true reduced-transparency
  render differential would require toggling the system setting, which is out
  of scope for automated evidence. The differential belongs to a manual
  accessibility audit, per docs/LIQUID_GLASS.md sections 7, 9, and 12.

For custom glass (the status bar), the durable guarantee named in section 12 is
to read `@Environment(\.accessibilityReduceTransparency)` and replace glass
with an opaque fill; that layered fix is a code concern for WS-9A, not a
capture, and is flagged here as the one accessibility follow-up worth
confirming in the status bar implementation.

### Reduced-transparency capture update

The status-bar half of the reduced-transparency fallback is now captured
automatically, without a System Settings toggle. `CodeFileWindowBridge`
(CodeFileDocumentBridge.swift, DEBUG only) reads the existing
`-PlainEditor.forceReduceTransparency YES` launch argument through
`PlainEditorAppearanceMarker.overrideBool` and injects it into the hosted
SwiftUI tree via an app-local `forcedReduceTransparencyForStatusBar`
environment key (SwiftUI's own `\.accessibilityReduceTransparency` has no
writable key path in this SDK, so it cannot be set directly with
`.environment()`). `PlainEditorStatusBar` (CodeFileView.swift) reads the
override and falls back to the real `\.accessibilityReduceTransparency`
whenever it is nil, so an ordinary launch (argument absent) still tracks the
live system setting exactly as before.

Captures: `docs/screenshots/glass_statusbar_reduced_light.png` and
`glass_statusbar_reduced_dark.png`, both launched with
`-PlainEditor.forceReduceTransparency YES` over the same varied-tokens
fixture used for `glass_toolbar_light.png`. Both show the status bar's
opaque tinted `background(opaqueTintedFill)` path rather than
`.glassEffect`. A pixel diff between the reduced-light capture and
`glass_toolbar_light.png`, restricted to the status-bar band, shows a
non-zero difference across the whole band (mean absolute channel diff
~17 of 255), confirming the override changes what actually renders rather
than a no-op. The visible contrast is modest because the status bar sits
over the window's own near-white background tint in this layout, which
docs/LIQUID_GLASS.md section 10 documents as an expected "nearly invisible"
backdrop for glass regardless of state; the differential shows up as a
lighter, less saturated band rather than a dramatic before/after look.

The toolbar half stays OS-owned and not screenshot-gated, unchanged from the
reasoning above: `ToolbarItemGroup` is a standard system component, so its
own Reduce Transparency handling is inherited automatically and is not a key
present in `NSArgumentDomain`(no `defaults write` substitute exists for it).

## Toolbar-distraction verdict

The chrome does not distract from the clean, simple editor goal. The toolbar is
a single quiet monochrome capsule of icon buttons in the title bar, and the
status bar is a thin row of secondary-gray metrics. Both are neutral and
recede; the only saturated color in the window is the syntax-highlighted code,
which is exactly where the user's attention belongs (docs/LIQUID_GLASS.md
sections 2-4: controls stay glassy and quiet, content stays legible and is the
focus). The ribbon-removal trigger in the plan's Resolved decisions is not
met: the chrome is appropriately quiet, so no distraction-driven removal is
warranted.

## Verification results

| Check | Result |
| --- | --- |
| ./build_debug.sh | Build complete (pass) |
| APPEARANCE_MODE=light marker | captured and quoted |
| APPEARANCE_MODE=dark marker | captured and quoted |
| light + dark + 2 backdrop PNGs saved | yes, under docs/screenshots/, 15pt |
| e2e_screenshot_colors.py on light PNG | chromatic_hue_families=4 (floor 3), exit 0 |
| backdrop-differential measured | yes, ~0.0 at both chrome bands (layout-inconclusive) |

## Post-pop re-capture (glass-pop tint/gradient)

Re-captured after the glass-pop change landed (tinted status-bar glass plus a
top accent gradient band the toolbar is meant to refract). Same forced-mode,
live on-screen easy-screenshot path. Both appearance markers confirmed:

- Light: `APPEARANCE_MODE=light reduceTransparency=0 increaseContrast=0`
- Dark: `APPEARANCE_MODE=dark reduceTransparency=0 increaseContrast=0`

New captures overwrote `docs/screenshots/glass_toolbar_light.png` and
`docs/screenshots/glass_toolbar_dark.png` (both non-black, 1920 x 1200).

### Tint read (max-min channel spread; prior state was 0.0 = neutral)

| Chrome band | Light | Dark | Reading |
| --- | --- | --- | --- |
| Toolbar capsule (y 28-95) | (245,245,245) spread 0.0 | (32,32,32) spread 0.0 | neutral, no color pop |
| Top accent band (y 40-56) | (243,242,239) spread 4.5 | (34,34,34) spread 0.0 | faint warm in light only, borderline |
| Status bar (y 1150-1195) | (222,234,218) spread 15.9 | (39,40,39) spread 1.0 | green pop in light; none in dark |

The green measured in the status band is an applied tint, not composited
content: the editor body directly above it (y 1100-1140) reads neutral white
(spread 0.0), so nothing green sits behind the bar to refract.

### Contrast (WCAG, status-bar text over tinted glass)

| Surface | Mode | Text | Glass BG | Ratio | Result |
| --- | --- | --- | --- | --- | --- |
| Status bar | light | (90,102,86) | (230,242,226) | 5.23:1 | pass (>= 4.5:1) |
| Status bar | dark | (166,167,166) | (33,34,33) | 6.61:1 | pass |

Toolbar glyphs are standard system SF Symbols; enabled New/Open glyphs are
clearly legible and disabled glyphs system-dimmed in both modes.

### Distraction verdict

Not distracting. The one popped element (light status bar) is a soft, low-
saturation green that recedes; the toolbar stays a quiet neutral capsule. The
only saturated color remains the syntax-highlighted code. The ribbon-removal
trigger is still not met.

### Post-pop SHIP/REWORK

REWORK for the popped-glass goal as a whole. The pop landed on only one of the
two chrome surfaces and only in one appearance mode:

- Status bar, light: SHIP. Clear, gentle green tint (spread 15.9) versus the
  prior near-invisible neutral (spread 0.0), clean and legible (5.23:1).
- Status bar, dark: REWORK. Tint spread 1.0 is imperceptible; the bar looks
  the same as before the change.
- Toolbar capsule, light and dark: REWORK. No color pop (spread 0.0). The
  translucent capsule material and soft edge are present, but the top accent
  gradient the toolbar should refract registers only as a borderline warm band
  (spread ~4) in light and is absent in dark.

Fact vs judgment: the measured spreads and contrast ratios above are observed;
the REWORK call is the judgment that a pop confined to the light status bar
does not yet satisfy "chrome glass pops in the toolbar capsule and status bar"
across both modes.

### Post-pop verification

| Check | Result |
| --- | --- |
| Light + dark APPEARANCE_MODE markers | both captured and quoted |
| Two non-black PNGs in docs/screenshots/ | yes (glass_toolbar_light/dark.png) |
| e2e_screenshot_colors.py on light PNG | chromatic_hue_families=3 (floor 3), exit 0 |
| Status-bar contrast light / dark | 5.23:1 / 6.61:1, both pass |

## Status

DONE_WITH_CONCERNS. All required captures, markers, measurements, and the
verdict are delivered. The one concern is analytical, not a blocker: the
backdrop-differential cannot chromatically prove chrome-glass liveness in this
window layout because no colored content composites behind the chrome. Liveness
is instead evidenced by the adaptive translucent material signature in light and
dark. If a stricter chromatic-differential proof is desired, it requires a
layout where editor content scrolls under the toolbar (a code change, out of
this capture-only scope), or a manual Reduce Transparency toggle audit.

The post-pop re-capture above supersedes the top-of-file SHIP/SHIP verdict for
the glass-pop question specifically: the pop is realized only on the light
status bar, so the popped-glass goal is REWORK pending a visible toolbar and
dark-mode pop.
