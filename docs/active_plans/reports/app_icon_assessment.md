# App icon assessment

Evaluation of the SwiftlyCodeEdit app icon against the stated design intent:
a lightning bolt centered between `<` and `>` angle brackets, flat two-tone
(charcoal-navy tile, electric-yellow glyphs), on a macOS rounded-square tile.

Sources reviewed:
- `docs/screenshots/app_icon_preview.png` (512x512 render)
- `build/AppIcon.iconset/icon_16x16.png` through `icon_512x512@2x.png`

Measurements were taken from the 512px preview pixels with Pillow/numpy.
Observed facts are separated from judgment below.

## 1. Aesthetics

Observed:
- Layout is symmetric: left bracket, centered bolt, right bracket. The two
  brackets are mirror images and sit at equal insets (left inset 98px, right
  inset 98px on the 512px render).
- Bracket arms have a consistent horizontal cross-section of ~43px across the
  full height of each arm (measured at rows 150, 200, 300, 350). Because the
  arms are diagonal, the true perpendicular stroke is narrower, but the
  constant cross-section means both brackets use one uniform stroke weight.
- The bolt is a single filled polygon spanning 156px vertically at the center
  column, with the expected wide-narrow-wide lightning silhouette (horizontal
  widths of roughly 6, 21, 66, 24, 10px sampled top to bottom).
- Corners of the bracket strokes are rounded (round caps and round elbows),
  matching the rounded tile.

Judgment:
- The mark reads as one cohesive unit. The bolt and brackets share a visual
  weight and the same round-cap treatment, so nothing looks bolted-on.
- Negative space is clean and balanced left-to-right. The gap between each
  bracket and the bolt is even.
- Vertically the bolt extends slightly above and below the bracket span
  (bolt/glyph bbox rows 114-397), which gives the bolt a bit of energy and
  keeps it from being visually trapped inside the brackets. This is a plus.
- Minor nit: the bolt's lower tail is close to the right bracket's inner edge
  at mid-height, but they do not touch and the reading stays clear.

## 2. Concept fit

Observed:
- The `< >` bracket pair is the most common visual shorthand for "code."
- The lightning bolt is the most common visual shorthand for "fast"/"power."
- Both are rendered flat, high-contrast yellow on dark.

Judgment:
- Concept communication is strong and immediate. "Code" and "fast" both land
  at a glance for the target audience (developers). The two metaphors are
  independently legible and combine without ambiguity.
- No competing readings. The mark does not accidentally resemble an unrelated
  symbol.

## 3. Measurements

Measured from the 512x512 preview (tile occupies the full 512px frame; corners
are transparent outside the rounded outline):

| Property | Spec | Measured | Note |
| --- | --- | --- | --- |
| Tile color | RGB(20,24,31) | RGB(20,24,31) | Exact match |
| Glyph color | RGB(255,214,10) | RGB(254,214,10) | Match (254 is antialias sampling) |
| Content inset (horizontal) | 10% | ~19.1% | Glyph spans cols 98-413 |
| Content inset (vertical) | 10% | ~22.3% | Glyph spans rows 114-397 |
| Corner radius | 22.5% | ~18.9% circular-arc | See note below |
| Glyph area coverage | n/a | ~11.2% of tile | Yellow pixels / tile area |

Corner radius note:
- A circular-arc fit of the tile outline reaches the straight edges at ~97px,
  i.e. ~18.9% of tile width. macOS tiles use a continuous-curve superellipse
  (squircle), not a circular arc. A squircle is "fuller" than a circle of the
  same nominal radius, so a circular-arc measurement under-reads the nominal
  value. The measured 18.9% is consistent with a ~22.5% nominal squircle
  radius, so the corner shape appears on-spec.

Content inset finding:
- The stated intent is a 10% content inset, but the glyphs actually sit at
  ~19% horizontal and ~22% vertical inset. The mark fills only ~62% of the
  tile width instead of the ~80% a 10% inset would give. The artwork is
  noticeably smaller and more padded than the spec calls for. This is the one
  measured value that clearly misses intent.

## 4. Small-size readability

Observed by viewing the rasterized renders:
- 512px, 256px, 128px: all three elements (bracket, bolt, bracket) are crisp
  and distinctly separated.
- 32x32: the brackets and bolt remain individually recognizable; the mark
  still reads as "bolt between brackets."
- 16x16: the three shapes crowd together into a small yellow cluster. The
  overall "code + bolt" impression survives, but the bolt's zig-zag no longer
  clearly resolves as a lightning bolt; it reads more like a vertical stroke.

Judgment:
- The bolt stops reading reliably as a bolt at 16px. It holds at 32px and up.
- The larger-than-spec content inset hurts here: because the mark is padded to
  ~62% of the tile, every raster loses usable pixels it did not need to lose.
  Scaling the artwork up toward the intended 10% inset would put more pixels
  into the glyphs and improve the 16px and 32px reads specifically.

## 5. macOS fit

Observed:
- Tile is a rounded-square superellipse with transparent corners, matching the
  macOS 26 tile convention.
- Palette is a single dark tile plus a single saturated accent, flat with no
  gradient or inner shadow.

Judgment:
- The tile shape sits comfortably next to standard macOS 26 dock icons; the
  silhouette matches.
- The flat two-tone treatment is clean and legible, but it is stylistically
  plainer than many first-party macOS icons, which lean on soft gradients,
  depth, and material. Next to those, this icon looks flatter and more
  utilitarian. That is a legitimate aesthetic choice (it matches a developer
  tool) and not a defect, but it is worth a conscious decision rather than an
  accident. The strong yellow-on-dark contrast makes it stand out in the dock
  rather than blend in, which is generally good for findability.

## 6. Verdict

SHIP-WITH-TWEAKS.

The mark is cohesive, on-concept, and the palette and tile geometry match
spec. It is dock-ready as-is. The tweaks below are ordered by impact:

1. Scale the artwork up to the intended ~10% content inset (currently ~19%
   horizontal / ~22% vertical). This is the highest-value change: it directly
   improves 16px and 32px legibility and brings the icon back to the stated
   spec. This is a pure transform, low risk.
2. After scaling up, re-check the bolt's lower tail clearance against the right
   bracket's inner edge so the larger artwork keeps its clean negative space.
3. Optional, lower priority: consider whether a small amount of depth or a
   subtle gradient is wanted to sit more naturally among first-party macOS 26
   icons. This is a style call, not a correctness issue; the flat look is
   defensible for a developer tool.

Limitations of this assessment:
- Corner radius was measured with a circular-arc fit, not a superellipse fit,
  so the reported 18.9% is a lower bound on the nominal squircle radius; a
  true superellipse fit was not performed.
- Small-size readability is judged from the provided rasters at 100% pixel
  size, not from on-device dock rendering at Retina scaling.

## Follow-up assessment 2026-07-09

Re-assessment of the reworked icon after the two tweaks from the prior verdict:
(1) artwork scaled up to the 10% content-inset lines, and (2) bracket chevron
angle restored. Source: `docs/screenshots/app_icon_preview.png` (regenerated
512px render). Measurements were taken from that preview with Pillow/numpy; the
16px and 32px renders were produced here by Lanczos-downscaling the 512px
preview.

### Content inset (tweak 1)

Observed:
- Glyph bounding box now spans cols 51-460 and rows 51-460 on the 512px render.
- Inset is exactly 10.0% on all four sides (left, right, top, bottom).
- The mark now fills 80.1% of the tile width and 80.1% of the tile height, up
  from the ~62% measured before.
- Glyph yellow-pixel coverage rose to 19.1% of the tile frame, up from ~11.2%.

Judgment:
- Tweak 1 landed precisely. The content inset matches the stated 10% spec on
  both axes, and the bracket caps and bolt tips sit on the inset lines as
  intended.

### Chevron angle and readability (tweak 2)

Observed:
- Left bracket top-arm centerline slope over rows 80-240 gives dx/dy = 0.531,
  matching the intended ~0.53.
- Arm cross-section stays a constant ~42px along the arm, so both brackets keep
  one uniform stroke weight.
- At full size the brackets read cleanly as `<` and `>`.

Judgment:
- Tweak 2 landed. The chevrons are diagonal and unambiguous, not the
  near-vertical intermediate version; they read as angle brackets at a glance.

### Bolt/bracket clearance and balance

Observed:
- At the vertical mid-row the three glyph runs are left bracket cols 51-91,
  bolt cols 202-308, right bracket cols 420-460.
- The gap between the bolt and each bracket is 110px (left) and 111px (right),
  i.e. ~21.5% of tile width, and symmetric to within 1px.

Judgment:
- Despite the larger artwork, clearance is ample and left-right symmetric. The
  earlier concern about the bolt tail crowding the right bracket is resolved;
  there is a wide, even channel of negative space on both sides.

### Small-size readability

Observed by viewing the downscaled renders:
- 32px: the bolt resolves clearly as a lightning bolt with its zig-zag, and
  both brackets are distinct.
- 16px: the bolt now shows a discernible diagonal jog through its center rather
  than a plain vertical stroke; the two brackets remain as separate side
  shapes.

Judgment:
- The bolt survives at 16px in this render. It is not crisp, but the diagonal
  lightning jog is present and distinguishes the mark from a plain vertical
  bar, which is the failure mode called out in the prior assessment. The extra
  glyph pixels from the scale-up are what buy this. It holds comfortably at
  32px and above.

### Follow-up verdict

SHIP.

Both prior tweaks were applied correctly and verified: content inset is exactly
10% on all sides, the chevron angle is restored to dx/dy 0.531, clearance is
ample and symmetric, and the bolt now survives 16px. The remaining item from
the prior report (optional depth/gradient to sit among first-party macOS 26
icons) is a style call, not a correctness issue, and does not gate shipping.

Limitations of this follow-up:
- 16px and 32px reads are judged from Lanczos downscales of the 512px preview,
  not from the shipped iconset rasters or on-device Retina dock rendering.
- Corner radius was not re-measured; it was unchanged by these two transforms.
