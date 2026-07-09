# Theme file format

Schema for syntax highlighting theme files (WP-F2 Patch A). This document
defines the on-disk format only; the loader and menu integration are WP-F2
Patch B.

## Format choice

Themes are one YAML file per theme (`.yaml`). YAML matches this repo's data
file preference (see docs/PYTHON_STYLE.md#data-files) and reads cleanly with
inline comments per key, which a color palette benefits from. A theme file
written as JSON with the same key structure is equally valid input; the
schema below is format-neutral and the loader accepts either extension.

## Versioned top-level structure

```yaml
version: 1
name: solarized
variants:
  light:
    ...
  dark:
    ...
```

- `version`: integer schema version. `1` is the only version defined here.
  The loader rejects an unknown version as malformed (see
  [Malformed-file handling](#malformed-file-handling)).
- `name`: unique identifier for the theme, used in menus and as the file's
  logical name. Lowercase, snake_case, ASCII only.
- `variants`: a mapping with one or both of the keys `light` and `dark`. A
  single file may carry both, or only one. The loader and the theme-picker
  UI treat a file's variants as one selectable theme entry (for example
  "solarized"), automatically following the app or system light/dark mode
  rather than exposing "solarized light" and "solarized dark" as separate
  menu entries.

## Semantic token color keys

Each variant is a flat mapping of semantic keys to color values. The keys are
taken directly from the highlighter's current token and style vocabulary so
every color the code uses today has a named home in the schema.

Base keys (apply to all highlighted text, from
`CodeEdit/Features/Editor/Views/PlainSyntaxHighlighter.swift:250` and
`:237`):

| Key | Meaning |
| --- | --- |
| `base_text` | Default foreground color applied to the whole document before token colors are layered on (`PlainSyntaxHighlighter.swift:200`, `baseTextColor`) |
| `background` | Editor background color (not read from `PlainSyntaxTheme` today, but required so a theme file is self-contained) |

Token keys, one per `HighlightToken` case
(`Packages/CodeEditHighlighting/Sources/CodeEditHighlighting/HighlightSpan.swift:3-13`)
as mapped in `PlainSyntaxHighlighter.swift:251-261`:

| Key | `HighlightToken` case |
| --- | --- |
| `comment` | `.comment` |
| `string` | `.string` |
| `keyword` | `.keyword` |
| `number` | `.number` |
| `function` | `.function` |
| `type` | `.type` |
| `operator` | `.operatorToken` |
| `markup` | `.markup` |
| `plain_text` | `.plainText` |

Style refinement keys, one per Kate `styleName` the highlighter checks today
(`PlainSyntaxHighlighter.swift:262-269`, matched case-insensitively at
`:297`). These override the token color above when the highlighter attaches
a matching `styleName` to a span:

| Key | Kate styleName |
| --- | --- |
| `style_imports` | `"imports"` |
| `style_variable` | `"variable"` |
| `style_data_type` | `"data type"` |
| `style_function` | `"function"` |
| `style_annotation` | `"annotation"` |
| `style_string_interpolation` | `"string interpolation"` |

The style keys are optional per variant; the loader falls back to the token
key when a style key is absent (see
[Explicit fallback rules](#explicit-fallback-rules)).

## Color value syntax

Colors are hex strings in one of two forms:

- `#RRGGBB` -- opaque color.
- `#RRGGBBAA` -- color with alpha channel.

Uppercase or lowercase hex digits are both accepted. No named colors
(`"red"`, `"systemBlue"`) and no other color space syntax are supported; a
value that does not match `#RRGGBB` or `#RRGGBBAA` is malformed.

## Explicit fallback rules

Fallback is layered so a document is always rendered with legible colors,
even from a partial or damaged theme file:

1. **Missing key within a variant.** If a token or style key is absent from
   a variant's mapping, the loader uses that variant's `base_text` color.
   `base_text` itself is required; if `base_text` is missing, the whole
   variant is treated as malformed (rule 3 applies).
2. **Missing variant.** If a theme file defines only `light` or only `dark`,
   the loader uses the defined variant for both app appearances rather than
   guessing colors for the missing one.
3. **Malformed file.** If the file fails to parse, has an unrecognized
   `version`, or has no usable variant (both variants missing, or the one
   present variant is missing `base_text`), the loader falls back to the
   bundled default theme (see [File locations](#file-locations)) and logs a
   warning naming the offending file and reason. The app keeps running; a
   malformed user theme never blocks startup or crashes the editor.

## Minimal example theme

A theme with only the required keys, one variant, using the token colors
directly with no style refinements:

```yaml
version: 1
name: minimal_dark
variants:
  dark:
    base_text: "#D4D4D4"
    background: "#1E1E1E"
    comment: "#6A9955"
    string: "#CE9178"
    keyword: "#569CD6"
    number: "#B5CEA8"
    function: "#DCDCAA"
    type: "#4EC9B0"
    operator: "#D4D4D4"
    markup: "#D16969"
    plain_text: "#D4D4D4"
```

## Complete two-variant example

A theme carrying both `light` and `dark` variants, including the optional
style refinement keys:

```yaml
version: 1
name: solarized
variants:
  light:
    base_text: "#657B83"
    background: "#FDF6E3"
    comment: "#93A1A1"
    string: "#2AA198"
    keyword: "#859900"
    number: "#D33682"
    function: "#268BD2"
    type: "#B58900"
    operator: "#657B83"
    markup: "#DC322F"
    plain_text: "#657B83"
    style_imports: "#B58900"
    style_variable: "#657B83"
    style_data_type: "#B58900"
    style_function: "#268BD2"
    style_annotation: "#D33682"
    style_string_interpolation: "#268BD2"
  dark:
    base_text: "#839496"
    background: "#002B36"
    comment: "#586E75"
    string: "#2AA198"
    keyword: "#859900"
    number: "#D33682"
    function: "#268BD2"
    type: "#B58900"
    operator: "#839496"
    markup: "#DC322F"
    plain_text: "#839496"
    style_imports: "#B58900"
    style_variable: "#839496"
    style_data_type: "#B58900"
    style_function: "#268BD2"
    style_annotation: "#D33682"
    style_string_interpolation: "#268BD2"
```

## File locations

- Bundled defaults ship inside the app bundle, one default light theme and
  one default dark theme, at `CodeEdit/Features/Theming/Resources/Themes/`
  (WP-F2 Patch B converts useful colors out of the legacy
  `DefaultThemes/*.cetheme` files before those files are deleted).
- User themes live under
  `~/Library/Application Support/SwiftlyCodeEdit/Themes/`, the per-app data
  directory defined by the WP-F0 path-policy helper
  (`CodeEdit/Features/Support/UserDataDirectories.swift`). A user theme with
  the same `name` as a bundled theme overrides it.

## Loader behavior contract summary

- Discover theme files from the bundled directory, then the user directory,
  layering by `name` (user wins on collision), matching the layering policy
  WP-F3 uses for syntax definitions.
- Parse each file against the rules above; a malformed file is skipped with
  a logged warning (rule 3), not surfaced to the user as an error dialog.
- Resolve the active theme's colors per the current app or system
  appearance (light/dark), following [Missing variant](#missing-variant)
  fallback when only one variant is present.
- Expose the resolved theme to `PlainSyntaxHighlighter` as a drop-in
  replacement for the current hardcoded `PlainSyntaxTheme.standard` /
  `.rotated` pair; `color(for:)` resolution order (style key, then token
  key, then `base_text`) stays the same as today's
  `PlainSyntaxHighlighter.swift:296-301`.
